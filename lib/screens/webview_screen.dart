import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/nexdine_printer.dart';
import '../services/session_manager.dart';
import '../services/usb_printer_manager.dart';
import 'no_internet_screen.dart';

class WebViewScreen extends StatefulWidget {
  final WebViewController? preloadedController;
  const WebViewScreen({super.key, this.preloadedController});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {

  WebViewController? _controller;

  final WebViewCookieManager _cookieManager =
  WebViewCookieManager();

  final UsbPrinterManager _usbPrinter =
  UsbPrinterManager();

  final NexDinePrintSdk _networkPrinter =
  NexDinePrintSdk();

  NexDinePrinter? _selectedPrinter;

  static const String _url =
      'https://krishna-mayuri.myteknoland.com/auth/login';

  static const int _maxRetries = 3;

  static const Duration _retryDelay =
  Duration(seconds: 2);

  bool _isLoading        = true;
  bool _hasInternet      = true;
  bool _isLoggedIn       = false;
  bool _isSlowConnection = false;
  bool _isCheckingNet    = false;

  double _loadingProgress = 0;

  late StreamSubscription _internetSubscription;

  Timer? _slowTimer;
  Timer? _healthTimer;
  Timer? _autoReloadTimer;

  @override
  void initState() {
    super.initState();

    debugPrint('WEBVIEW INIT');

    if (widget.preloadedController != null) {
      _controller = widget.preloadedController;
      _setupPreloadedController();
    } else {
      _initWebView();
    }

    _checkInitialInternet();

    _startInternetListener();

    _startHealthMonitor();

    _startAutoReload();

    _usbPrinter.connectToFirst();

    _initNetworkPrinter();
  }

  Future<void> _initNetworkPrinter() async {

    try {

      final printers =
      await _networkPrinter.discoverPrinters(
        subnetPrefix: '192.168.1',
      );

      if (printers.isNotEmpty) {

        _selectedPrinter = printers.first;

        debugPrint(
          'Network Printer Found: ${_selectedPrinter!.ip}',
        );
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

    if (_isCheckingNet) return;

    _isCheckingNet = true;

    bool hasInternet = false;

    for (int i = 0; i < _maxRetries; i++) {

      hasInternet =
      await InternetConnectionChecker().hasConnection;

      if (hasInternet) break;

      debugPrint(
        'Internet retry ${i + 1} failed',
      );

      if (i < _maxRetries - 1) {
        await Future.delayed(_retryDelay);
      }
    }

    if (mounted) {
      setState(() {
        _hasInternet   = hasInternet;
        _isCheckingNet = false;
      });
    }
  }

  void _startInternetListener() {

    _internetSubscription =
        InternetConnectionChecker()
            .onStatusChange
            .listen((status) async {

          final hasInternet =
              status == InternetConnectionStatus.connected;

          if (!hasInternet) {

            await _checkInitialInternet();

          } else {
            if (mounted) {
              setState(() {
                _hasInternet = true;
              });
              final currentUrl = await _controller?.currentUrl();
              if (currentUrl != null && currentUrl != _url) {
                await _controller?.loadRequest(
                  Uri.parse(currentUrl),
                );
              }
            }
          }
        });
  }

  // =====================================================
  // WEBVIEW
  // =====================================================

  void _initWebView() {

    _controller = WebViewController()

      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )

      ..setBackgroundColor(
        const Color(0xFFFFF8F0),
      )

      ..enableZoom(false)

      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleKioskEvent(message.message);
        },
      )

      ..setNavigationDelegate(

        NavigationDelegate(

          // ==========================================
          // LOADING
          // ==========================================

          onProgress: (int progress) {

            if (!mounted) return;

            setState(() {
              _loadingProgress = progress / 100;
            });
          },

          onPageStarted: (String url) {

            if (!mounted) return;

            setState(() {
              _isLoading        = true;
              _isSlowConnection = false;
            });

            _slowTimer?.cancel();

            _slowTimer = Timer(
              const Duration(seconds: 8),
                  () {

                if (_isLoading && mounted) {

                  setState(() {
                    _isSlowConnection = true;
                  });
                }
              },
            );
          },

          onPageFinished: (String url) async {

            _slowTimer?.cancel();

            if (!mounted) return;

            final loggedIn = !url.contains('/auth/login');

            setState(() {
              _isLoading        = false;
              _isSlowConnection = false;
              _isLoggedIn       = loggedIn;
            });

            debugPrint('Page loaded: $url');

            if (loggedIn) {
              debugPrint('LOGIN DETECTED');
              await SessionManager.saveSession(url);
              debugPrint('SESSION SAVED');
            }

            await _runPageScripts();
          },

          // ==========================================
          // ERRORS
          // ==========================================

          onHttpError: (HttpResponseError error) {

            debugPrint(
              'HTTP Error: ${error.response?.statusCode}',
            );
          },

          onWebResourceError: (
              WebResourceError error,
              ) {

            if (error.isForMainFrame == true) {

              debugPrint(
                'Main frame error: ${error.description}',
              );

              _checkInitialInternet();
            }
          },

          onNavigationRequest: (
              NavigationRequest request,
              ) {

            return NavigationDecision.navigate;
          },
        ),
      )

      ..loadRequest(Uri.parse(_url));
  }

  void _setupPreloadedController() {
    _controller!
      ..setBackgroundColor(const Color(0xFFFFF8F0))
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleKioskEvent(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress / 100);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _isSlowConnection = false;
            });
            _slowTimer?.cancel();
            _slowTimer = Timer(const Duration(seconds: 8), () {
              if (_isLoading && mounted) {
                setState(() => _isSlowConnection = true);
              }
            });
          },
          onPageFinished: (url) async {
            _slowTimer?.cancel();

            if (!mounted) return;

            final loggedIn = !url.contains('/auth/login');

            setState(() {
              _isLoading = false;
              _isSlowConnection = false;
              _isLoggedIn = loggedIn;
            });

            if (loggedIn) {
              debugPrint('LOGIN DETECTED');
              await SessionManager.saveSession(url);
              debugPrint('SESSION SAVED');
            }

            await _runPageScripts();
          },
          onHttpError: (error) {
            debugPrint('HTTP Error: ${error.response?.statusCode}');
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              _checkInitialInternet();
            }
          },
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      );

    // setState(() => _isLoading = false);
  }

  // ✅ Extract JS scripts into reusable method
  Future<void> _runPageScripts() async {
    await _controller?.runJavaScript('''
    var images = document.querySelectorAll('img');
    images.forEach(function(img) {
      img.style.maxWidth = '100%';
      img.style.width = '100%';
      img.style.height = 'auto';
      img.style.objectFit = 'contain';
    });

    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
    document.body.style.overflow = 'auto';
    document.documentElement.style.overflow = 'auto';
    document.body.style.webkitOverflowScrolling = 'touch';
  ''');
  }

  // =====================================================
  // HEALTH MONITOR
  // =====================================================

  void _startHealthMonitor() {

    _healthTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) async {

        try {

          await _controller?.runJavaScript(
            "document.body.style.opacity='1';",
          );

        } catch (e) {

          debugPrint(
            'WebView freeze detected. Reloading...',
          );

          await _controller?.reload();
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

        debugPrint('Auto refreshing WebView');

        await _controller?.reload();
      },
    );
  }

  // =====================================================
  // KIOSK EVENTS
  // =====================================================

  Future<void> _handleKioskEvent(String message) async {

    debugPrint('Kiosk event: $message');

    try {

      final data =
      jsonDecode(message) as Map<String, dynamic>;

      final action =
      data['action'] as String?;

      switch (action) {

        case 'print_network':

          final content =
              data['content'] as String? ?? '';

          if (_selectedPrinter != null) {

            await _networkPrinter.printReceipt(
              _selectedPrinter!,
              content,
            );
          }

          break;

        case 'print_pdf':

          final content =
              data['content'] as String? ?? '';

          _handlePdfPrint(content);

          break;

        case 'logout':

          _logout();

          break;

        case 'reload':

          _controller?.reload();

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

      await _cookieManager.clearCookies();

      await _controller?.clearLocalStorage();

      setState(() {
        _isLoggedIn = false;
      });

      await _controller?.loadRequest(
        Uri.parse(_url),
      );

      debugPrint('Logout successful');

    } catch (e) {

      debugPrint('Logout error: $e');
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

        onLayout: (
            PdfPageFormat format,
            ) async {

          final doc = pw.Document();

          final plainText = content

              .replaceAll(
            RegExp(r'<[^>]*>'),
            '',
          )

              .replaceAll('&amp;', '&')

              .replaceAll('&nbsp;', ' ')

              .trim();

          doc.addPage(

            pw.Page(

              pageFormat: format,

              build: (pw.Context ctx) {

                return pw.Column(

                  crossAxisAlignment:
                  pw.CrossAxisAlignment.start,

                  children: [

                    pw.Text(

                      'Krishna Mayuri',

                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight:
                        pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 12),

                    pw.Text(plainText),
                  ],
                );
              },
            ),
          );

          return doc.save();
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

  Future<bool> _onWillPop() async {

    if (await _controller?.canGoBack() ?? false) {

      await _controller?.goBack();

      return false;
    }

    return true;
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {

    _slowTimer?.cancel();

    _healthTimer?.cancel();

    _autoReloadTimer?.cancel();

    _internetSubscription.cancel();

    _usbPrinter.disconnect();

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

          if (_hasInternet) {

            final currentUrl =
            await _controller?.currentUrl();

            if (currentUrl != null) {

              await _controller?.loadRequest(
                Uri.parse(currentUrl),
              );
            }
          }
        },
      );
    }

    return WillPopScope(

      onWillPop: _onWillPop,

      child: Scaffold(


        appBar: _isLoading

            ? PreferredSize(

          preferredSize:
          const Size.fromHeight(3),

          child: LinearProgressIndicator(

            value: _loadingProgress,

            backgroundColor:
            Colors.transparent,

            color:
            const Color(0xFFFF6B35),
          ),
        )

            : null,

        // ==========================================
        // BODY
        // ==========================================

        body: SafeArea(
          child: Stack(

          children: [

            if (_controller != null)

              WebViewWidget(
                controller: _controller!,
              ),

            // ======================================
            // SLOW INTERNET BANNER
            // ======================================

            if (_isSlowConnection)

              Positioned(

                top: 0,
                left: 0,
                right: 0,

                child: Material(

                  color: Colors.orange.shade700,

                  child: SafeArea(

                    bottom: false,

                    child: Padding(

                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),

                      child: Row(

                        children: const [

                          Icon(
                            Icons.wifi_find,
                            color: Colors.white,
                            size: 18,
                          ),

                          SizedBox(width: 8),

                          Expanded(

                            child: Text(

                              'Slow connection — page still loading...',

                              style: TextStyle(
                                color: Colors.white,
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
    ));
  }
}