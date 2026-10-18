import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/restaurant.dart';
import '../services/nexdine_printer.dart';
import '../services/restaurant_service.dart';
import '../services/session_manager.dart';
import '../services/usb_printer_manager.dart';
import 'no_internet_screen.dart';

class WebViewScreen extends StatefulWidget {
  final String? initialUrl;
  final Restaurant? selectedRestaurant;

  // NEW: the same list and filters used on the selection screen, so the
  // top bar shows only those restaurants (not every restaurant).
  final List<Restaurant>? restaurants;
  final String? pincode;
  final String? isVeg;

  const WebViewScreen({
    super.key,
    this.initialUrl,
    this.selectedRestaurant,
    this.restaurants,
    this.pincode,
    this.isVeg,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final Map<String, InAppWebViewController> _controllers = {};
  final Map<String, bool> _branchLoggedIn = {};
  final Map<String, List<Cookie>> _branchCookies = {};
  final Map<String, String> _branchCurrentUrls = {};

  // NEW: branches whose WebView has been created (opened at least once).
  // Branches not in this set are not loaded, so they never show a login
  // page before the user has logged in.
  final Set<String> _visitedBranches = {};

  List<Cookie> _sharedCookies = [];
  String? _sharedStorageJson;

  final UsbPrinterManager _usbPrinter = UsbPrinterManager();
  final NexDinePrintSdk _networkPrinter = NexDinePrintSdk();

  NexDinePrinter? _selectedPrinter;

  String get _url =>
      widget.initialUrl != null && widget.initialUrl!.isNotEmpty
          ? widget.initialUrl!
          : 'https://hrm.myteknoland.com/login';

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  bool _isLoading = true;
  bool _hasInternet = true;
  bool _isLoggedIn = false;
  bool _isSlowConnection = false;
  bool _isCheckingNet = false;

  double _loadingProgress = 0;

  StreamSubscription<InternetConnectionStatus>? _internetSubscription;

  Timer? _slowTimer;
  Timer? _healthTimer;
  Timer? _autoReloadTimer;

  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;
  String? _selectedRestaurantId;
  String? _currentUrl;

  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();

    debugPrint('WEBVIEW INIT');

    _selectedRestaurant = widget.selectedRestaurant;
    _selectedRestaurantId = widget.selectedRestaurant?.id;

    // NEW: start with the same restaurants shown on the selection screen.
    if (widget.restaurants != null && widget.restaurants!.isNotEmpty) {
      _restaurants = List<Restaurant>.of(widget.restaurants!);
      _updateSelectedRestaurant();
    }

    // NEW: the restaurant chosen on the selection screen is opened first.
    if (_selectedRestaurantId != null && _selectedRestaurantId!.isNotEmpty) {
      _visitedBranches.add(_selectedRestaurantId!);
    }

    _initCookieManager();
    _loadSavedSession();
    _checkInitialInternet();
    _startInternetListener();
    _startHealthMonitor();
    _startAutoReload();
    _connectUsbPrinter();
    _initNetworkPrinter();
    _fetchRestaurants();
  }

  Future<void> _loadSavedSession() async {
    try {
      final isLoggedIn = await SessionManager.isLoggedIn();
      if (isLoggedIn) {
        final storageJson = await SessionManager.getSharedStorage();
        final cookiesJson = await SessionManager.getSharedCookies();

        if (storageJson != null && storageJson.isNotEmpty) {
          _sharedStorageJson = storageJson;
        }
        if (cookiesJson != null && cookiesJson.isNotEmpty) {
          try {
            final List<dynamic> list = jsonDecode(cookiesJson);
            _sharedCookies = list
                .map((item) =>
                SessionManager.mapToCookie(item as Map<String, dynamic>))
                .toList();
          } catch (e) {
            debugPrint('Error parsing saved cookies: $e');
          }
        }

        if (mounted) {
          setState(() {
            _isLoggedIn = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading saved session: $e');
    }
  }

  // =====================================================
  // RESTAURANTS SERVICE & DYNAMIC BRANCH SWITCHING
  // =====================================================

  Future<void> _fetchRestaurants() async {
    try {
      // CHANGED: use the same pincode and Veg/Non-Veg filter as the
      // selection screen, so both screens show the same restaurants.
      final list = await RestaurantService.fetchRestaurants(
        pincode: widget.pincode,
        isVeg: widget.isVeg,
      );
      if (!mounted) return;
      if (list.isEmpty) return; // keep the current list
      setState(() {
        _restaurants = list;
        _updateSelectedRestaurant();
      });
    } catch (e) {
      debugPrint('Error fetching restaurants in WebViewScreen: $e');
    }
  }

  bool _isSameRestaurant(Restaurant r1, Restaurant r2) {
    if (r1.id.isNotEmpty && r2.id.isNotEmpty) {
      return r1.id == r2.id;
    }
    if (r1.name.isNotEmpty && r2.name.isNotEmpty) {
      return r1.name.toLowerCase().trim() == r2.name.toLowerCase().trim();
    }
    return r1.url.toLowerCase().trim() == r2.url.toLowerCase().trim();
  }

  void _updateSelectedRestaurant() {
    if (_restaurants.isEmpty) return;

    if (_selectedRestaurant != null) {
      for (final restaurant in _restaurants) {
        if (_isSameRestaurant(restaurant, _selectedRestaurant!)) {
          _selectedRestaurant = restaurant;
          _selectedRestaurantId = restaurant.id;
          return;
        }
      }
    }

    if (_selectedRestaurantId != null && _selectedRestaurantId!.isNotEmpty) {
      for (final restaurant in _restaurants) {
        if (restaurant.id == _selectedRestaurantId) {
          _selectedRestaurant = restaurant;
          return;
        }
      }
    }

    final urlToCheck = _currentUrl ?? _url;
    for (final restaurant in _restaurants) {
      if (_isMatchingUrl(urlToCheck, restaurant.url)) {
        _selectedRestaurant = restaurant;
        _selectedRestaurantId = restaurant.id;
        return;
      }
    }

    if (_selectedRestaurant == null) {
      _selectedRestaurant = _restaurants.first;
      _selectedRestaurantId = _restaurants.first.id;
    }
  }

  bool _isMatchingUrl(String currentUrl, String restaurantUrl) {
    if (currentUrl.isEmpty || restaurantUrl.isEmpty) return false;

    String clean(String u) {
      var s = u.toLowerCase().trim();
      s = s.replaceAll(RegExp(r'^https?://'), '');
      s = s.replaceAll(RegExp(r'^www\.'), '');
      if (s.endsWith('/')) s = s.substring(0, s.length - 1);
      return s;
    }

    final cleanCurrent = clean(currentUrl);
    final cleanRestaurant = clean(restaurantUrl);

    final currentHost = cleanCurrent.split('/').first;
    final restaurantHost = cleanRestaurant.split('/').first;

    return currentHost == restaurantHost ||
        cleanCurrent.startsWith(cleanRestaurant) ||
        cleanRestaurant.startsWith(cleanCurrent);
  }

  String _getFormattedUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return _url;
    return (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
        ? trimmed
        : 'https://$trimmed';
  }

  Future<bool> _checkIsAuthenticated(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
          (function() {
            try {
              var href = window.location.href.toLowerCase();
              if (href.indexOf('/login') !== -1) {
                return false;
              }
              var keys = Object.keys(localStorage);
              if (keys.length === 0) return false;
              for (var i = 0; i < keys.length; i++) {
                var k = keys[i].toLowerCase();
                var v = localStorage.getItem(keys[i]);
                if (v && v !== 'null' && v !== 'undefined' && v !== '{}' && v.length > 0) {
                  if (k.indexOf('token') !== -1 ||
                      k.indexOf('user') !== -1 ||
                      k.indexOf('auth') !== -1 ||
                      k.indexOf('customer') !== -1 ||
                      k.indexOf('session') !== -1 ||
                      k.indexOf('profile') !== -1 ||
                      k.indexOf('phone') !== -1 ||
                      k.indexOf('mobile') !== -1) {
                    return true;
                  }
                }
              }
              return false;
            } catch(e) {
              return false;
            }
          })();
        ''',
      );
      if (result == true || result == 'true') {
        return true;
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    }
    return false;
  }

  Future<String?> _extractStorage(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
          (function() {
            try {
              var local = {};
              for (var i = 0; i < localStorage.length; i++) {
                var k = localStorage.key(i);
                if (k) local[k] = localStorage.getItem(k);
              }
              var session = {};
              for (var j = 0; j < sessionStorage.length; j++) {
                var sk = sessionStorage.key(j);
                if (sk) session[sk] = sessionStorage.getItem(sk);
              }
              return JSON.stringify({ local: local, session: session });
            } catch(e) {
              return null;
            }
          })();
        ''',
      );
      if (result != null &&
          result is String &&
          result.isNotEmpty &&
          result != 'null') {
        return result;
      }
    } catch (e) {
      debugPrint('Error extracting web storage: $e');
    }
    return null;
  }

  Future<void> _injectStorage(
      InAppWebViewController controller, String storageJson) async {
    if (storageJson.isEmpty || storageJson == 'null') return;
    try {
      final safeJson = jsonEncode(storageJson);
      await controller.evaluateJavascript(
        source: '''
          (function() {
            try {
              var raw = $safeJson;
              var payload = typeof raw === 'string' ? JSON.parse(raw) : raw;
              if (payload && payload.local) {
                for (var k in payload.local) {
                  if (Object.prototype.hasOwnProperty.call(payload.local, k)) {
                    localStorage.setItem(k, payload.local[k]);
                  }
                }
              }
              if (payload && payload.session) {
                for (var sk in payload.session) {
                  if (Object.prototype.hasOwnProperty.call(payload.session, sk)) {
                    sessionStorage.setItem(sk, payload.session[sk]);
                  }
                }
              }
            } catch(e) {
              console.error('Storage inject error:', e);
            }
          })();
        ''',
      );
    } catch (e) {
      debugPrint('Error injecting web storage: $e');
    }
  }

  // =====================================================
  // NEW: RESTORE SESSION AT DOCUMENT START
  // =====================================================

  /// JavaScript that writes the saved login data into localStorage /
  /// sessionStorage BEFORE the website's own scripts run.
  String _storageRestoreScript(String storageJson) {
    final safe = jsonEncode(storageJson);
    return '''
(function () {
  try {
    var p = JSON.parse($safe);
    if (p && p.local) {
      for (var k in p.local) {
        if (localStorage.getItem(k) === null) {
          localStorage.setItem(k, p.local[k]);
        }
      }
    }
    if (p && p.session) {
      for (var s in p.session) {
        if (sessionStorage.getItem(s) === null) {
          sessionStorage.setItem(s, p.session[s]);
        }
      }
    }
  } catch (e) {}
})();
''';
  }

  /// Replaces the restore script on an already created WebView.
  Future<void> _applyRestoreScript(InAppWebViewController c) async {
    try {
      await c.removeAllUserScripts();
      if (_isLoggedIn && _sharedStorageJson != null) {
        await c.addUserScript(
          userScript: UserScript(
            source: _storageRestoreScript(_sharedStorageJson!),
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying restore script: $e');
    }
  }

  Future<void> _syncSharedAuthToBranch(
      String branchId,
      InAppWebViewController? controller,
      ) async {
    _branchLoggedIn[branchId] = true;

    Restaurant? restaurant;
    for (final r in _restaurants) {
      if (r.id == branchId) {
        restaurant = r;
        break;
      }
    }
    final branchUrl =
    restaurant != null ? _getFormattedUrl(restaurant.url) : _url;

    if (_sharedCookies.isNotEmpty) {
      final targetUri = WebUri(branchUrl);
      final cookieManager = CookieManager.instance();
      for (final cookie in _sharedCookies) {
        try {
          await cookieManager.setCookie(
            url: targetUri,
            name: cookie.name,
            value: cookie.value,
            // CHANGED: domain removed so the cookie is stored for the
            // target branch host (not the first branch's domain).
            path: cookie.path ?? '/',
            isSecure: cookie.isSecure,
            isHttpOnly: cookie.isHttpOnly,
            expiresDate: cookie.expiresDate,
          );
        } catch (e) {
          debugPrint('Error setting cookie for $branchId: $e');
        }
      }
    }

    if (controller != null && _sharedStorageJson != null) {
      await _injectStorage(controller, _sharedStorageJson!);
    }
  }

  Future<void> _onSwitchRestaurant(Restaurant restaurant) async {
    if (_selectedRestaurant != null &&
        _isSameRestaurant(_selectedRestaurant!, restaurant)) {
      return;
    }

    // 1. Take a FRESH snapshot from the current branch
    //    (checks the real login state, not only the flag)
    if (_selectedRestaurant != null) {
      final currentId = _selectedRestaurant!.id;
      final currentController = _controllers[currentId];
      if (currentController != null &&
          await _checkIsAuthenticated(currentController)) {
        final currentUrl = _branchCurrentUrls[currentId] ??
            _getFormattedUrl(_selectedRestaurant!.url);
        try {
          final cookies = await CookieManager.instance().getCookies(
            url: WebUri(currentUrl),
          );
          if (cookies.isNotEmpty) _sharedCookies = cookies;
        } catch (e) {
          debugPrint('Cookie snapshot error: $e');
        }

        final storage = await _extractStorage(currentController);
        if (storage != null && storage.isNotEmpty) {
          _sharedStorageJson = storage;
        }
        _isLoggedIn = true;
      }
    }

    final targetId = restaurant.id;
    final targetController = _controllers[targetId];
    final formattedUrl = _getFormattedUrl(restaurant.url);

    // 2. Copy cookies to the target branch BEFORE it loads
    if (_isLoggedIn) {
      await _syncSharedAuthToBranch(targetId, targetController);
    }

    // 3. Update selection (this also creates the WebView if it is new)
    if (!mounted) return;
    setState(() {
      _selectedRestaurant = restaurant;
      _selectedRestaurantId = restaurant.id;
      _visitedBranches.add(restaurant.id);
    });

    // 4. If this branch was already created earlier, refresh its
    //    restore script and reload it with the latest session.
    if (targetController != null && _isLoggedIn) {
      await _applyRestoreScript(targetController);
      await targetController.loadUrl(
        urlRequest: URLRequest(url: WebUri(formattedUrl)),
      );
    }
  }

  int get _selectedIndex {
    if (_restaurants.isEmpty || _selectedRestaurant == null) return 0;
    final index = _restaurants.indexWhere(
          (r) => _isSameRestaurant(r, _selectedRestaurant!),
    );
    return index >= 0 ? index : 0;
  }

  Widget _buildRestaurantSelector() {
    if (_restaurants.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: const Color(0xFF6CBF0A),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _restaurants.map((restaurant) {
            final isSelected = _selectedRestaurant != null
                ? _isSameRestaurant(restaurant, _selectedRestaurant!)
                : false;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onSwitchRestaurant(restaurant),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withAlpha(56),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    restaurant.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF2E6B00)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
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
      final printers = await _networkPrinter.discoverPrinters(
        subnetPrefix: '192.168.1',
      );

      if (printers.isNotEmpty) {
        _selectedPrinter = printers.first;

        debugPrint(
          'Network printer found: ${_selectedPrinter?.ip}',
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
        hasInternet = await InternetConnectionChecker().hasConnection;

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
        InternetConnectionChecker().onStatusChange.listen(
              (status) async {
            final hasInternet = status == InternetConnectionStatus.connected;

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
              final activeBranchId = _selectedRestaurant?.id ?? 'default';
              final activeController = _controllers[activeBranchId];

              final currentUrl = (await activeController?.getUrl())?.toString();

              if (currentUrl != null && currentUrl.isNotEmpty) {
                await activeController?.loadUrl(
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

  Future<PermissionRequestResponse> _onPermissionRequest(
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
      action: PermissionRequestResponseAction.GRANT,
    );
  }

  Future<GeolocationPermissionShowPromptResponse> _onGeolocationPrompt(
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
      String branchId,
      ) {
    controller.addJavaScriptHandler(
      handlerName: 'FlutterBridge',
      callback: (args) {
        if (args.isEmpty) {
          return;
        }

        _handleKioskEvent(
          args.first.toString(),
          branchId,
        );
      },
    );
  }

  // =====================================================
  // SAFE HORIZONTAL TABLE SCROLLING
  // =====================================================

  Future<void> _runPageScripts(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(
        source: '''
(function () {
  try {
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
        -webkit-overflow-scrolling: touch !important;
        touch-action: pan-x pan-y !important;
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
        -webkit-overflow-scrolling: touch !important;
        touch-action: pan-x pan-y !important;
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
        -webkit-overflow-scrolling: touch !important;
        touch-action: pan-x pan-y !important;
      }
    `;

    document.head.appendChild(style);

    function makeTablesScrollable() {
      var tables =
        document.querySelectorAll('table');

      tables.forEach(function (table) {
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
        final activeBranchId = _selectedRestaurant?.id ?? 'default';
        final controller = _controllers[activeBranchId];
        try {
          await controller?.evaluateJavascript(
            source: '''
              if (document.body) {
                document.body.style.opacity = '1';
              }
            ''',
          );
        } catch (e) {
          debugPrint(
            'WebView health check failed on $activeBranchId: $e',
          );

          try {
            await controller?.reload();
          } catch (reloadError) {
            debugPrint(
              'WebView reload failed: $reloadError',
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

        final activeBranchId = _selectedRestaurant?.id ?? 'default';
        final controller = _controllers[activeBranchId];

        try {
          await controller?.reload();
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
      String branchId,
      ) async {
    debugPrint(
      'Kiosk event ($branchId): $message',
    );

    try {
      final decodedData = jsonDecode(message);

      if (decodedData is! Map<String, dynamic>) {
        debugPrint(
          'Invalid kiosk event format',
        );

        return;
      }

      final action = decodedData['action']?.toString();

      switch (action) {
        case 'print_network':
          final content = decodedData['content']?.toString() ?? '';

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
          final content = decodedData['content']?.toString() ?? '';

          await _handlePdfPrint(content);

          break;

        case 'logout':
          await _logout();
          break;

        case 'reload':
          final controller = _controllers[branchId];
          await controller?.reload();
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
      final cookieManager = CookieManager.instance();

      for (final entry in _controllers.entries) {
        final branchId = entry.key;
        final controller = entry.value;
        final activeUrl = _branchCurrentUrls[branchId] ?? _url;

        try {
          await cookieManager.deleteCookies(url: WebUri(activeUrl));
        } catch (_) {}

        try {
          await controller.evaluateJavascript(
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
        } catch (_) {}

        // NEW: remove the restore script so the old session is not
        // written back after logout.
        try {
          await controller.removeAllUserScripts();
        } catch (_) {}
      }

      _branchLoggedIn.clear();
      _branchCookies.clear();
      _sharedCookies.clear();
      _sharedStorageJson = null;

      await SessionManager.clearSession();

      if (mounted) {
        setState(() {
          _isLoggedIn = false;
        });
      }

      final activeBranchId = _selectedRestaurant?.id ?? 'default';
      final activeUrl = _branchCurrentUrls[activeBranchId] ?? _url;
      final activeController = _controllers[activeBranchId];

      await activeController?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(activeUrl),
        ),
      );

      debugPrint('Logout successful across all branches');
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
        onLayout: (PdfPageFormat format) async {
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
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Krishna Mayuri',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
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
    final activeBranchId = _selectedRestaurant?.id ?? 'default';
    final controller = _controllers[activeBranchId];

    if (controller == null) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final canGoBack = await controller.canGoBack();

      if (canGoBack) {
        await controller.goBack();
      } else {
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

  Widget _buildSlowConnectionBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.orange.shade700,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
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
    );
  }

  Widget _buildSingleInAppWebView({
    required String branchId,
    required String initialUrl,
  }) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(initialUrl),
      ),
      // NEW: restore the saved login BEFORE the website's JavaScript runs.
      initialUserScripts: UnmodifiableListView<UserScript>([
        if (_isLoggedIn && _sharedStorageJson != null)
          UserScript(
            source: _storageRestoreScript(_sharedStorageJson!),
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useHybridComposition: true,
        userAgent: _userAgent,
        textZoom: 100,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        supportZoom: false,
        builtInZoomControls: false,
        displayZoomControls: false,
        transparentBackground: false,
        useShouldOverrideUrlLoading: false,
        cacheEnabled: true,
        verticalScrollBarEnabled: true,
        horizontalScrollBarEnabled: true,
        overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS,
        disallowOverScroll: false,
        thirdPartyCookiesEnabled: true,
      ),
      onWebViewCreated: (controller) async {
        _controllers[branchId] = controller;
        _registerJsHandlers(controller, branchId);
        if (_isLoggedIn) {
          await _syncSharedAuthToBranch(branchId, controller);
        }
      },
      androidOnPermissionRequest: _onPermissionRequest,
      androidOnGeolocationPermissionsShowPrompt: _onGeolocationPrompt,
      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        if (_selectedRestaurant?.id == branchId || _restaurants.isEmpty) {
          setState(() {
            _loadingProgress = progress / 100;
          });
        }
      },
      onLoadStart: (controller, url) async {
        if (!mounted) return;
        if (_selectedRestaurant?.id == branchId || _restaurants.isEmpty) {
          setState(() {
            _isLoading = true;
            _isSlowConnection = false;
          });

          _slowTimer?.cancel();
          _slowTimer = Timer(const Duration(seconds: 8), () {
            if (_isLoading && mounted) {
              setState(() {
                _isSlowConnection = true;
              });
            }
          });
        }

        if (_isLoggedIn && _sharedStorageJson != null) {
          await _injectStorage(controller, _sharedStorageJson!);
        }
      },
      onLoadStop: (controller, url) async {
        _slowTimer?.cancel();
        if (!mounted) return;

        final urlString = url?.toString() ?? '';
        _branchCurrentUrls[branchId] = urlString;

        final isAuth = await _checkIsAuthenticated(controller);

        if (isAuth) {
          _isLoggedIn = true;
          _branchLoggedIn[branchId] = true;

          try {
            final cookies = await CookieManager.instance().getCookies(
              url: WebUri(urlString),
            );
            if (cookies.isNotEmpty) {
              _sharedCookies = cookies;
            }
          } catch (e) {
            debugPrint('Error getting cookies for branch $branchId: $e');
          }

          final storage = await _extractStorage(controller);
          if (storage != null && storage.isNotEmpty) {
            _sharedStorageJson = storage;
          }

          for (final r in _restaurants) {
            _branchLoggedIn[r.id] = true;
          }

          final cookiesJson = jsonEncode(
            _sharedCookies.map((c) => SessionManager.cookieToMap(c)).toList(),
          );
          await SessionManager.saveSession(
            urlString,
            storageJson: _sharedStorageJson,
            cookiesJson: cookiesJson,
          );
        } else if (_isLoggedIn) {
          await _syncSharedAuthToBranch(branchId, controller);
          final restoredAuth = await _checkIsAuthenticated(controller);
          if (!restoredAuth) {
            await controller.evaluateJavascript(
              source: '''
                if (!window.__auth_reloaded) {
                  window.__auth_reloaded = true;
                  window.location.reload();
                }
              ''',
            );
          }
        }

        if (_selectedRestaurant?.id == branchId || _restaurants.isEmpty) {
          setState(() {
            _isLoading = false;
            _isSlowConnection = false;
            _currentUrl = urlString;
            _updateSelectedRestaurant();
          });
        }

        await _runPageScripts(controller);
      },
      onUpdateVisitedHistory: (controller, url, isReload) async {
        if (url == null || !mounted) return;
        final urlString = url.toString();

        // NEW: give the website a moment to save the token after login.
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        final isAuth = await _checkIsAuthenticated(controller);
        if (isAuth) {
          _isLoggedIn = true;
          _branchLoggedIn[branchId] = true;

          try {
            final cookies = await CookieManager.instance().getCookies(
              url: WebUri(urlString),
            );
            if (cookies.isNotEmpty) {
              _sharedCookies = cookies;
            }
          } catch (_) {}

          final storage = await _extractStorage(controller);
          if (storage != null && storage.isNotEmpty) {
            _sharedStorageJson = storage;
          }

          for (final r in _restaurants) {
            _branchLoggedIn[r.id] = true;
          }

          final cookiesJson = jsonEncode(
            _sharedCookies.map((c) => SessionManager.cookieToMap(c)).toList(),
          );
          await SessionManager.saveSession(
            urlString,
            storageJson: _sharedStorageJson,
            cookiesJson: cookiesJson,
          );

          if (mounted) {
            setState(() {
              _isLoggedIn = true;
            });
          }
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? false) {
          debugPrint('Main frame error on $branchId: ${error.description}');
          _checkInitialInternet();
        }
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        debugPrint('HTTP error on $branchId: ${errorResponse.statusCode}');
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('WEBVIEW CONSOLE ($branchId): ${consoleMessage.message}');
      },
    );
  }

  Widget _buildContent() {
    if (_restaurants.isEmpty) {
      return Stack(
        children: [
          _buildSingleInAppWebView(
            branchId: 'default',
            initialUrl: _url,
          ),
          if (_isSlowConnection) _buildSlowConnectionBanner(),
        ],
      );
    }

    // NEW: make sure the currently selected branch is always created.
    _visitedBranches.add(_selectedRestaurant?.id ?? _restaurants.first.id);

    return IndexedStack(
      index: _selectedIndex,
      children: _restaurants.map((branch) {
        // NEW: branches that were never opened stay empty (not loaded).
        if (!_visitedBranches.contains(branch.id)) {
          return SizedBox.shrink(key: ValueKey('empty_${branch.id}'));
        }

        final rawUrl = branch.url.trim();
        final formattedUrl = _getFormattedUrl(rawUrl);

        return Stack(
          key: ValueKey('branch_webview_${branch.id}'),
          children: [
            _buildSingleInAppWebView(
              branchId: branch.id,
              initialUrl: formattedUrl,
            ),
            if (_isSlowConnection &&
                _selectedRestaurant != null &&
                _isSameRestaurant(branch, _selectedRestaurant!))
              _buildSlowConnectionBanner(),
          ],
        );
      }).toList(),
    );
  }

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
            final activeBranchId = _selectedRestaurant?.id ?? 'default';
            final activeController = _controllers[activeBranchId];

            final currentUrl = (await activeController?.getUrl())?.toString();

            final retryUrl =
            currentUrl != null && currentUrl.isNotEmpty ? currentUrl : _url;

            await activeController?.loadUrl(
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
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _loadingProgress,
            backgroundColor: Colors.transparent,
            color: const Color(0xFF80CC00),
          ),
        )
            : null,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              if (_restaurants.isNotEmpty)
                _buildRestaurantSelector(),
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}