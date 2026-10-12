import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/nexdine_printer.dart';
import '../services/session_manager.dart';
import '../services/usb_printer_manager.dart';
import 'no_internet_screen.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;

  final UsbPrinterManager _usbPrinter = UsbPrinterManager();
  final NexDinePrintSdk _networkPrinter = NexDinePrintSdk();

  NexDinePrinter? _selectedPrinter;

  static const String _url =
      'https://maya-bazar.nexdine.myteknoland.in/online-menu/mainmenu-mayabazar';

  // Local testing URL:
  // static const String _url =
  //     'http://192.168.100.250:8080/login';

  static const int _maxRetries = 3;

  static const Duration _retryDelay =
  Duration(seconds: 2);

  bool _isLoading = true;
  bool _hasInternet = true;
  bool _isLoggedIn = false;
  bool _isSlowConnection = false;
  bool _isCheckingNet = false;

  double _loadingProgress = 0;

  StreamSubscription<InternetConnectionStatus>?
  _internetSubscription;

  Timer? _slowTimer;
  Timer? _healthTimer;
  Timer? _autoReloadTimer;

  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();

    debugPrint('WEBVIEW INIT');

    _initCookieManager();
    _checkInitialInternet();
    _startInternetListener();
    _startHealthMonitor();
    _startAutoReload();
    _connectUsbPrinter();
    _initNetworkPrinter();
  }

  // =====================================================
  // COOKIE INITIALIZATION
  // =====================================================

  Future<void> _initCookieManager() async {
    try {
      final cookieManager = CookieManager.instance();

      await cookieManager.setCookie(
        url: WebUri(_url),
        name: '_app_init',
        value: '1',
        isSecure: true,
      );

      debugPrint('Cookie manager initialized');
    } catch (e) {
      debugPrint(
        'Cookie initialization error: $e',
      );
    }
  }

  // =====================================================
  // USB PRINTER
  // =====================================================

  Future<void> _connectUsbPrinter() async {
    try {
      await _usbPrinter.connectToFirst();

      debugPrint(
        'USB printer connection completed',
      );
    } catch (e) {
      debugPrint(
        'USB printer connection failed: $e',
      );
    }
  }

  // =====================================================
  // NETWORK PRINTER
  // =====================================================

  Future<void> _initNetworkPrinter() async {
    try {
      final printers =
      await _networkPrinter.discoverPrinters(
        subnetPrefix: '192.168.1',
      );

      if (printers.isNotEmpty) {
        _selectedPrinter = printers.first;

        debugPrint(
          'Network printer found: '
              '${_selectedPrinter?.ip}',
        );
      } else {
        debugPrint('No network printer found');
      }
    } catch (e) {
      debugPrint(
        'Printer discovery failed: $e',
      );
    }
  }

  // =====================================================
  // INTERNET CHECK
  // =====================================================

  Future<void> _checkInitialInternet() async {
    if (_isCheckingNet) {
      return;
    }

    _isCheckingNet = true;

    bool hasInternet = false;

    try {
      for (int i = 0; i < _maxRetries; i++) {
        hasInternet =
        await InternetConnectionChecker()
            .hasConnection;

        if (hasInternet) {
          break;
        }

        debugPrint(
          'Internet retry ${i + 1} failed',
        );

        if (i < _maxRetries - 1) {
          await Future.delayed(_retryDelay);
        }
      }
    } catch (e) {
      debugPrint(
        'Internet check error: $e',
      );

      hasInternet = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _hasInternet = hasInternet;
      _isCheckingNet = false;
    });
  }

  void _startInternetListener() {
    _internetSubscription =
        InternetConnectionChecker()
            .onStatusChange
            .listen(
              (status) async {
            final hasInternet =
                status ==
                    InternetConnectionStatus.connected;

            if (!hasInternet) {
              await _checkInitialInternet();
              return;
            }

            if (!mounted) {
              return;
            }

            setState(() {
              _hasInternet = true;
            });

            try {
              final currentUrl =
              (await _controller?.getUrl())
                  ?.toString();

              if (currentUrl != null &&
                  currentUrl.isNotEmpty) {
                await _controller?.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri(currentUrl),
                  ),
                );
              }
            } catch (e) {
              debugPrint(
                'Internet recovery reload failed: $e',
              );
            }
          },
        );
  }

  // =====================================================
  // WEB PERMISSIONS
  // =====================================================

  Future<PermissionRequestResponse>
  _onPermissionRequest(
      InAppWebViewController controller,
      String origin,
      List<String> resources,
      ) async {
    debugPrint(
      'Web permission requested from: $origin',
    );

    debugPrint(
      'Requested resources: $resources',
    );

    return PermissionRequestResponse(
      resources: resources,
      action:
      PermissionRequestResponseAction.GRANT,
    );
  }

  Future<
      GeolocationPermissionShowPromptResponse>
  _onGeolocationPrompt(
      InAppWebViewController controller,
      String origin,
      ) async {
    return GeolocationPermissionShowPromptResponse(
      origin: origin,
      allow: true,
      retain: true,
    );
  }

  // =====================================================
  // JAVASCRIPT HANDLERS
  // =====================================================

  void _registerJsHandlers(
      InAppWebViewController controller,
      ) {
    controller.addJavaScriptHandler(
      handlerName: 'FlutterBridge',
      callback: (args) {
        if (args.isEmpty) {
          return;
        }

        _handleKioskEvent(
          args.first.toString(),
        );
      },
    );
  }

  // =====================================================
  // SAFE HORIZONTAL TABLE SCROLLING
  // =====================================================

  Future<void> _runPageScripts() async {
    try {
      await _controller?.evaluateJavascript(
        source: '''
(function () {
  try {
    // ===============================================
    // KEEP A NORMAL MOBILE VIEWPORT
    // ===============================================

    var viewport = document.querySelector(
      'meta[name="viewport"]'
    );

    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.name = 'viewport';
      document.head.appendChild(viewport);
    }

    viewport.setAttribute(
      'content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'
    );

    // ===============================================
    // REMOVE ALL OLD FLUTTER-INJECTED CSS
    // ===============================================

    var oldResponsiveStyle =
      document.getElementById(
        'flutter-webview-responsive-style'
      );

    if (oldResponsiveStyle) {
      oldResponsiveStyle.remove();
    }

    var oldKioskStyle =
      document.getElementById(
        'kiosk-fix-style'
      );

    if (oldKioskStyle) {
      oldKioskStyle.remove();
    }

    var oldCameraStyle =
      document.getElementById(
        'flutter-camera-fix-style'
      );

    if (oldCameraStyle) {
      oldCameraStyle.remove();
    }

    // ===============================================
    // TABLE-ONLY CSS
    //
    // IMPORTANT:
    // Do not modify:
    // html
    // body
    // video
    // canvas
    // modal
    // dialog
    // camera containers
    // ===============================================

    var style = document.createElement('style');

    style.id =
      'flutter-webview-responsive-style';

    style.innerHTML = `
      .flutter-table-scroll {
        display: block !important;

        width: 100% !important;
        max-width: 100% !important;

        overflow-x: auto !important;
        overflow-y: hidden !important;

        -webkit-overflow-scrolling:
          touch !important;

        touch-action:
          pan-x pan-y !important;
      }

      .flutter-table-scroll > table {
        width: max-content !important;
        min-width: 100% !important;
        max-width: none !important;
      }

      .flutter-table-scroll th,
      .flutter-table-scroll td {
        white-space: nowrap !important;
      }

      .table-responsive {
        display: block !important;

        width: 100% !important;
        max-width: 100% !important;

        overflow-x: auto !important;
        overflow-y: hidden !important;

        -webkit-overflow-scrolling:
          touch !important;

        touch-action:
          pan-x pan-y !important;
      }

      .table-responsive table {
        width: max-content !important;
        min-width: 100% !important;
        max-width: none !important;
      }

      .table-responsive th,
      .table-responsive td {
        white-space: nowrap !important;
      }

      .dataTables_wrapper,
      .datatable-container,
      .ag-body-viewport,
      .ag-center-cols-viewport,
      .MuiDataGrid-root,
      [role="grid"] {
        max-width: 100% !important;

        overflow-x: auto !important;

        -webkit-overflow-scrolling:
          touch !important;

        touch-action:
          pan-x pan-y !important;
      }
    `;

    document.head.appendChild(style);

    // ===============================================
    // WRAP ONLY STANDARD HTML TABLES
    // ===============================================

    function makeTablesScrollable() {
      var tables =
        document.querySelectorAll('table');

      tables.forEach(function (table) {
        // Do not repeatedly wrap a table.
        if (
          table.closest(
            '.flutter-table-scroll'
          ) ||
          table.closest(
            '.table-responsive'
          )
        ) {
          return;
        }

        // Ignore tables inside camera dialogs/modals.
        // Some libraries may use tables internally
        // for camera controls or overlays.
        if (
          table.closest(
            '[role="dialog"]'
          ) ||
          table.closest('.modal') ||
          table.closest(
            '[class*="camera"]'
          ) ||
          table.closest(
            '[class*="Camera"]'
          ) ||
          table.closest(
            '[class*="webcam"]'
          ) ||
          table.closest(
            '[class*="Webcam"]'
          )
        ) {
          return;
        }

        var wrapper =
          document.createElement('div');

        wrapper.className =
          'flutter-table-scroll';

        if (table.parentNode) {
          table.parentNode.insertBefore(
            wrapper,
            table
          );

          wrapper.appendChild(table);
        }
      });
    }

    makeTablesScrollable();

    // ===============================================
    // SUPPORT DYNAMIC/SPA TABLES
    // ===============================================

    if (
      window.flutterWebViewMutationObserver
    ) {
      window
        .flutterWebViewMutationObserver
        .disconnect();
    }

    var updateTimer = null;

    window.flutterWebViewMutationObserver =
      new MutationObserver(
        function (mutations) {
          var tableAdded = false;

          mutations.forEach(
            function (mutation) {
              mutation.addedNodes.forEach(
                function (node) {
                  if (
                    node.nodeType !== 1
                  ) {
                    return;
                  }

                  if (
                    node.tagName ===
                      'TABLE' ||
                    (
                      node.querySelector &&
                      node.querySelector(
                        'table'
                      )
                    )
                  ) {
                    tableAdded = true;
                  }
                }
              );
            }
          );

          if (!tableAdded) {
            return;
          }

          if (updateTimer) {
            clearTimeout(updateTimer);
          }

          updateTimer = setTimeout(
            function () {
              makeTablesScrollable();
            },
            150
          );
        }
      );

    if (document.body) {
      window
        .flutterWebViewMutationObserver
        .observe(
          document.body,
          {
            childList: true,
            subtree: true
          }
        );
    }

    console.log(
      'Safe table scrolling applied. Camera styles untouched.'
    );
  } catch (error) {
    console.error(
      'Flutter WebView script error:',
      error
    );
  }
})();
''',
      );
    } catch (e) {
      debugPrint(
        'Page script execution failed: $e',
      );
    }
  }

  // =====================================================
  // HEALTH MONITOR
  // =====================================================

  void _startHealthMonitor() {
    _healthTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) async {
        try {
          await _controller?.evaluateJavascript(
            source: '''
              if (document.body) {
                document.body.style.opacity = '1';
              }
            ''',
          );
        } catch (e) {
          debugPrint(
            'WebView health check failed: $e',
          );

          try {
            await _controller?.reload();
          } catch (reloadError) {
            debugPrint(
              'WebView reload failed: '
                  '$reloadError',
            );
          }
        }
      },
    );
  }

  // =====================================================
  // AUTO RELOAD
  // =====================================================

  void _startAutoReload() {
    _autoReloadTimer = Timer.periodic(
      const Duration(minutes: 30),
          (_) async {
        debugPrint(
          'Auto refreshing WebView',
        );

        try {
          await _controller?.reload();
        } catch (e) {
          debugPrint(
            'Auto reload failed: $e',
          );
        }
      },
    );
  }

  // =====================================================
  // KIOSK EVENTS
  // =====================================================

  Future<void> _handleKioskEvent(
      String message,
      ) async {
    debugPrint(
      'Kiosk event: $message',
    );

    try {
      final decodedData =
      jsonDecode(message);

      if (decodedData
      is! Map<String, dynamic>) {
        debugPrint(
          'Invalid kiosk event format',
        );

        return;
      }

      final action =
      decodedData['action']?.toString();

      switch (action) {
        case 'print_network':
          final content =
              decodedData['content']
                  ?.toString() ??
                  '';

          if (_selectedPrinter == null) {
            debugPrint(
              'No network printer selected',
            );

            return;
          }

          await _networkPrinter.printReceipt(
            _selectedPrinter!,
            content,
          );

          break;

        case 'print_pdf':
          final content =
              decodedData['content']
                  ?.toString() ??
                  '';

          await _handlePdfPrint(content);

          break;

        case 'logout':
          await _logout();
          break;

        case 'reload':
          await _controller?.reload();
          break;

        default:
          debugPrint(
            'Unknown action: $action',
          );
      }
    } catch (e) {
      debugPrint(
        'Kiosk event parse error: $e',
      );
    }
  }

  // =====================================================
  // LOGOUT
  // =====================================================

  Future<void> _logout() async {
    try {
      final cookieManager =
      CookieManager.instance();

      await cookieManager
          .deleteAllCookies();

      await _controller
          ?.evaluateJavascript(
        source: '''
          try {
            localStorage.clear();
            sessionStorage.clear();
          } catch (error) {
            console.error(
              'Storage clear error:',
              error
            );
          }
        ''',
      );

      if (mounted) {
        setState(() {
          _isLoggedIn = false;
        });
      }

      await _controller?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(_url),
        ),
      );

      debugPrint('Logout successful');
    } catch (e) {
      debugPrint(
        'Logout error: $e',
      );
    }
  }

  // =====================================================
  // PDF PRINT
  // =====================================================

  Future<void> _handlePdfPrint(
      String content,
      ) async {
    try {
      await Printing.layoutPdf(
        onLayout:
            (PdfPageFormat format) async {
          final document = pw.Document();

          final plainText = content
              .replaceAll(
            RegExp(r'<[^>]*>'),
            '',
          )
              .replaceAll('&amp;', '&')
              .replaceAll('&nbsp;', ' ')
              .trim();

          document.addPage(
            pw.Page(
              pageFormat: format,
              build: (
                  pw.Context context,
                  ) {
                return pw.Column(
                  crossAxisAlignment:
                  pw.CrossAxisAlignment
                      .start,
                  children: [
                    pw.Text(
                      'Krishna Mayuri',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight:
                        pw.FontWeight
                            .bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(plainText),
                  ],
                );
              },
            ),
          );

          return document.save();
        },
      );
    } catch (e) {
      debugPrint(
        'PDF print error: $e',
      );
    }
  }

  // =====================================================
// BACK BUTTON
// =====================================================

  Future<void> _handleBackButton() async {
    final controller = _controller;

    if (controller == null) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final canGoBack = await controller.canGoBack();

      if (canGoBack) {
        // Opens the previous WebView page.
        await controller.goBack();
      } else {
        // No WebView history is available.
        // Close the Flutter screen only when possible.
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Back navigation error: $e');

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _slowTimer?.cancel();
    _healthTimer?.cancel();
    _autoReloadTimer?.cancel();

    _internetSubscription?.cancel();

    try {
      _usbPrinter.disconnect();
    } catch (e) {
      debugPrint(
        'USB printer disconnect error: $e',
      );
    }

    super.dispose();
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    if (!_hasInternet) {
      return NoInternetScreen(
        onRetry: () async {
          await _checkInitialInternet();

          if (!_hasInternet) {
            return;
          }

          try {
            final currentUrl =
            (await _controller?.getUrl())
                ?.toString();

            final retryUrl =
            currentUrl != null &&
                currentUrl.isNotEmpty
                ? currentUrl
                : _url;

            await _controller?.loadUrl(
              urlRequest: URLRequest(
                url: WebUri(retryUrl),
              ),
            );
          } catch (e) {
            debugPrint(
              'Retry page load failed: $e',
            );
          }
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        await _handleBackButton();
      },
      child: Scaffold(
        appBar: _isLoading
            ? PreferredSize(
          preferredSize:
          const Size.fromHeight(3),
          child:
          LinearProgressIndicator(
            value: _loadingProgress,
            backgroundColor:
            Colors.transparent,
            color:
            const Color(0xFFFF6B35),
          ),
        )
            : null,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest:
                URLRequest(
                  url: WebUri(_url),
                ),

                // =====================================
                // WEBVIEW SETTINGS
                // =====================================

                initialSettings:
                InAppWebViewSettings(
                  javaScriptEnabled: true,

                  useHybridComposition: true,

                  userAgent: _userAgent,

                  textZoom: 100,

                  mediaPlaybackRequiresUserGesture:
                  false,

                  allowsInlineMediaPlayback: true,

                  // Keep zoom disabled so the camera
                  // modal remains at normal mobile scale.
                  supportZoom: false,

                  builtInZoomControls: false,

                  displayZoomControls: false,

                  transparentBackground: false,

                  useShouldOverrideUrlLoading:
                  false,

                  cacheEnabled: true,

                  verticalScrollBarEnabled: true,

                  horizontalScrollBarEnabled:
                  true,

                  overScrollMode:
                  OverScrollMode
                      .IF_CONTENT_SCROLLS,

                  disallowOverScroll: false,

                  thirdPartyCookiesEnabled:
                  true,
                ),

                // =====================================
                // CREATED
                // =====================================

                onWebViewCreated:
                    (controller) {
                  _controller = controller;

                  _registerJsHandlers(
                    controller,
                  );
                },

                // =====================================
                // PERMISSIONS
                // =====================================

                androidOnPermissionRequest:
                _onPermissionRequest,

                androidOnGeolocationPermissionsShowPrompt:
                _onGeolocationPrompt,

                // =====================================
                // LOADING PROGRESS
                // =====================================

                onProgressChanged: (
                    controller,
                    progress,
                    ) {
                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    _loadingProgress =
                        progress / 100;
                  });
                },

                // =====================================
                // LOAD START
                // =====================================

                onLoadStart: (
                    controller,
                    url,
                    ) {
                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    _isLoading = true;
                    _isSlowConnection =
                    false;
                  });

                  _slowTimer?.cancel();

                  _slowTimer = Timer(
                    const Duration(
                      seconds: 8,
                    ),
                        () {
                      if (_isLoading &&
                          mounted) {
                        setState(() {
                          _isSlowConnection =
                          true;
                        });
                      }
                    },
                  );
                },

                // =====================================
                // LOAD COMPLETED
                // =====================================

                onLoadStop: (
                    controller,
                    url,
                    ) async {
                  _slowTimer?.cancel();

                  if (!mounted) {
                    return;
                  }

                  final urlString =
                      url?.toString() ?? '';

                  final loggedIn =
                  !urlString.contains(
                    '/login',
                  );

                  setState(() {
                    _isLoading = false;
                    _isSlowConnection =
                    false;
                    _isLoggedIn = loggedIn;
                  });

                  debugPrint(
                    'Page loaded: '
                        '$urlString',
                  );

                  if (loggedIn) {
                    debugPrint(
                      'LOGIN DETECTED',
                    );

                    try {
                      await SessionManager
                          .saveSession(
                        urlString,
                      );

                      debugPrint(
                        'SESSION SAVED',
                      );
                    } catch (e) {
                      debugPrint(
                        'Session save failed: '
                            '$e',
                      );
                    }
                  }

                  // Only tables are modified.
                  // Camera and modal stay untouched.
                  await _runPageScripts();
                },

                // =====================================
                // PAGE ERROR
                // =====================================

                onReceivedError: (
                    controller,
                    request,
                    error,
                    ) {
                  if (request
                      .isForMainFrame ??
                      false) {
                    debugPrint(
                      'Main frame error: '
                          '${error.description}',
                    );

                    _checkInitialInternet();
                  }
                },

                // =====================================
                // HTTP ERROR
                // =====================================

                onReceivedHttpError: (
                    controller,
                    request,
                    errorResponse,
                    ) {
                  debugPrint(
                    'HTTP error: '
                        '${errorResponse.statusCode}',
                  );
                },

                // =====================================
                // CONSOLE
                // =====================================

                onConsoleMessage: (
                    controller,
                    consoleMessage,
                    ) {
                  debugPrint(
                    'WEBVIEW CONSOLE: '
                        '${consoleMessage.message}',
                  );
                },
              ),

              // =====================================
              // SLOW CONNECTION BANNER
              // =====================================

              if (_isSlowConnection)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    color:
                    Colors.orange.shade700,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.wifi_find,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Slow connection — '
                                    'page still loading...',
                                style: TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}