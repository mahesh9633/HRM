import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/restaurant.dart';
import '../services/location_service.dart';
import '../services/restaurant_service.dart';
import 'location_picker_screen.dart';
import 'webview_screen.dart';

class RestaurantSelectionScreen extends StatefulWidget {
  const RestaurantSelectionScreen({super.key});

  @override
  State<RestaurantSelectionScreen> createState() =>
      _RestaurantSelectionScreenState();
}

class _RestaurantSelectionScreenState extends State<RestaurantSelectionScreen>
    with WidgetsBindingObserver {
  static const Color _brand = Color(0xFF80CC00);
  static const Color _brandDark = Color(0xFF4E9A00);
  static const Color _brandSoft = Color(0xFFEAF5DD);
  static const Color _textDark = Color(0xFF1C1C1E);

  static const double _headerHeight = 260;
  static const double _sheetTop = 200;
  static const double _logoSize = 64;

  static const Duration _autoRefreshInterval = Duration(seconds: 10);

  Timer? _autoRefreshTimer;
  bool _isSilentRefreshing = false;

  List<Restaurant>? _restaurants;
  bool _isLoading = true;
  String? _errorMessage;

  LocationAddress? _currentAddress;
  String? _selectedPincode;
  bool _isLocationDetecting = false;

  // Applied filter: 'all', '1' (Veg), '0' (Non-Veg)
  String _selectedVegFilter = 'all';

  // Filter popup state
  final LayerLink _filterLink = LayerLink();
  OverlayEntry? _filterOverlay;
  bool _isFilterOpen = false;
  String _pendingVegFilter = 'all'; // choice inside the popup (before Apply)

  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationAndLoadData();
    _startAutoRefresh();
  }

  // ---------- Silent auto update ----------

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _silentRefresh();
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused) {
      _stopAutoRefresh();
    }
  }

  String _signature(List<Restaurant> list) {
    return list
        .map((r) =>
    '${r.id}|${r.name}|${r.url}|${r.pincode}|${r.isVeg}|${r.latitude}|${r.longitude}')
        .join(';;');
  }

  String? _getVegParam() {
    if (_selectedVegFilter == '1') return '1';
    if (_selectedVegFilter == '0') return '0';
    return null;
  }

  Future<void> _silentRefresh() async {
    if (_isLoading || _isSilentRefreshing) return;
    _isSilentRefreshing = true;

    try {
      final list = await RestaurantService.fetchRestaurants(
        pincode: _selectedPincode,
        isVeg: _getVegParam(),
      );
      if (!mounted) return;

      final oldList = _restaurants;
      final changed =
          oldList == null || _signature(oldList) != _signature(list);

      if (changed) {
        setState(() {
          _restaurants = list;
          _errorMessage = null;
        });
      }
    } catch (_) {
      // Silent error ignore
    } finally {
      _isSilentRefreshing = false;
    }
  }

  Future<void> _initLocationAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isLocationDetecting = true;
    });

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        final addr = await LocationService.reverseGeocode(
          pos.latitude,
          pos.longitude,
        );
        if (addr != null) {
          _currentAddress = addr;
          if (addr.pincode.isNotEmpty) {
            _selectedPincode = addr.pincode;
          } else {
            _selectedPincode = null;
          }
          debugPrint('Detected location: ${addr.address}, pincode: ${_selectedPincode ?? "None"}');
        }
      }
    } catch (e) {
      debugPrint('Location detection error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLocationDetecting = false;
        });
      }
    }

    await _fetchRestaurantList();
  }

  Future<void> _fetchRestaurantList() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await RestaurantService.fetchRestaurants(
        pincode: _selectedPincode,
        isVeg: _getVegParam(),
      );
      if (!mounted) return;
      setState(() {
        _restaurants = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
        'Unable to load restaurants. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openLocationPicker() async {
    final selected = await Navigator.push<LocationAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _currentAddress,
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _currentAddress = selected;
        _selectedPincode =
            selected.pincode.isNotEmpty ? selected.pincode : null;
      });
      await _fetchRestaurantList();
    }
  }

  void _onFilterChanged(String filterValue) {
    if (_selectedVegFilter == filterValue) return;
    setState(() {
      _selectedVegFilter = filterValue;
    });
    _fetchRestaurantList();
  }

  // ---------- Filter popup ----------

  void _openFilterPopup() {
    if (_filterOverlay != null) return;
    _pendingVegFilter = _selectedVegFilter;

    _filterOverlay = OverlayEntry(builder: _buildFilterPopup);
    Overlay.of(context).insert(_filterOverlay!);
    setState(() => _isFilterOpen = true);
  }

  void _closeFilterPopup() {
    _filterOverlay?.remove();
    _filterOverlay = null;
    if (mounted) {
      setState(() => _isFilterOpen = false);
    }
  }

  void _applyFilter() {
    final value = _pendingVegFilter;
    _closeFilterPopup();
    _onFilterChanged(value);
  }

  Widget _buildFilterPopup(BuildContext overlayContext) {
    return Stack(
      children: [
        // Soft dim background. Tap anywhere to close.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeFilterPopup,
            child: Container(color: Colors.white.withAlpha(120)),
          ),
        ),
        CompositedTransformFollower(
          link: _filterLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Material(
            color: Colors.white,
            elevation: 10,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 220,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Restaurant Type',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildFilterOption(
                    label: 'All',
                    value: 'all',
                    leading: const Icon(Icons.restaurant_menu,
                        size: 16, color: _brandDark),
                  ),
                  _buildFilterOption(
                    label: 'Veg',
                    value: '1',
                    leading: Icon(Icons.circle,
                        size: 12, color: Colors.green.shade700),
                  ),
                  _buildFilterOption(
                    label: 'Non-Veg',
                    value: '0',
                    leading: Icon(Icons.change_history,
                        size: 14, color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterOption({
    required String label,
    required String value,
    required Widget leading,
  }) {
    final bool selected = _pendingVegFilter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        _pendingVegFilter = value;
        _filterOverlay?.markNeedsBuild();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _brand : Colors.grey.shade400,
                  width: 1.8,
                ),
              ),
              child: selected
                  ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _brand,
                  ),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 10),
            SizedBox(width: 18, child: Center(child: leading)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRestaurantSelected(Restaurant restaurant) {
    final rawUrl = restaurant.url.trim();

    if (rawUrl.isEmpty) {
      _showErrorSnackBar('Invalid restaurant URL.');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!uri.hasScheme && !rawUrl.contains('.'))) {
      _showErrorSnackBar('Invalid URL format for ${restaurant.name}.');
      return;
    }

    final formattedUrl =
    (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
        ? rawUrl
        : 'https://$rawUrl';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          initialUrl: formattedUrl,
          selectedRestaurant: restaurant,
          restaurants: _restaurants,
          pincode: _selectedPincode,
          isVeg: _getVegParam(),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _filterOverlay?.remove();
    _filterOverlay = null;
    _stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    super.dispose();
  }

  // ------------------------------- UI ---------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _headerHeight,
            child: _buildHeader(),
          ),
          Column(
            children: [
              const SizedBox(height: _sheetTop),
              Expanded(child: _buildSheet()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final double topPad = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: _headerHeight + topPad * 0,
      width: double.infinity,
      child: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6CBF0A), Color(0xFF9BD93C)],
                ),
              ),
            ),
          ),
          // Faint map lines
          Positioned.fill(
            child: CustomPaint(painter: _MapLinesPainter()),
          ),
          // Fade-out toward the bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1.0],
                  colors: [
                    Colors.white.withAlpha(0),
                    Colors.white.withAlpha(110),
                  ],
                ),
              ),
            ),
          ),
          // Title + subtitle
          Positioned(
            top: topPad + 16,
            left: 0,
            right: 0,
            child: const Column(
              children: [
                Text(
                  'Select Restaurant',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose your nearest location & menu',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Map pin
          Positioned(
            top: topPad + 90,
            left: 0,
            right: 0,
            child: const Center(child: _MapPin()),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet() {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SizedBox.expand(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),

            // Location bar + filter button in the same row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildLocationBar()),
                  const SizedBox(width: 10),
                  _buildFilterButton(),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBar() {
    final hasAddress = _currentAddress != null;
    final addressText =
    hasAddress ? _currentAddress!.address : 'All Locations';
    final pincodeText = _selectedPincode != null && _selectedPincode!.isNotEmpty
        ? 'Pincode: $_selectedPincode'
        : (hasAddress ? 'Pincode: Not Detected' : 'All Pincodes');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: _brandDark, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        addressText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ),
                    if (_isLocationDetecting) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: _brand,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  pincodeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _openLocationPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _brand, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_location_alt, size: 14, color: _brandDark),
                  SizedBox(width: 4),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: _brandDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    // Highlight the button when the popup is open or a filter is applied.
    final bool highlighted = _isFilterOpen || _selectedVegFilter != 'all';

    return CompositedTransformTarget(
      link: _filterLink,
      child: GestureDetector(
        onTap: _isFilterOpen ? _closeFilterPopup : _openFilterPopup,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _brandSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted ? _brand : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.filter_alt_outlined,
            size: 24,
            color: _brandDark,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _brand),
              SizedBox(height: 16),
              Text(
                'Searching restaurants...',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchRestaurantList,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_restaurants == null || _restaurants!.isEmpty) {
      final pincodeInfo = _selectedPincode != null
          ? 'in pincode $_selectedPincode'
          : 'for this selection';
      final filterName = _selectedVegFilter == '1'
          ? 'Veg'
          : (_selectedVegFilter == '0' ? 'Non-Veg' : '');

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_outlined,
                  size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No $filterName restaurants found $pincodeInfo.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedVegFilter != 'all')
                    ElevatedButton(
                      onPressed: () => _onFilterChanged('all'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Show All Veg & Non-Veg'),
                    ),
                  OutlinedButton(
                    onPressed: _openLocationPicker,
                    child: const Text('Change Location'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final restaurants = _restaurants!;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchRestaurantList,
            color: _brand,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              itemCount: restaurants.length,
              itemBuilder: (context, i) {
                return _buildRestaurantCard(restaurants[i]);
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _buildFooterBanner(),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant) {
    final logoUrl = restaurant.getFullLogoUrl();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onRestaurantSelected(restaurant),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  // Circular logo
                  Container(
                    width: _logoSize,
                    height: _logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: _brand, width: 2),
                    ),
                    child: ClipOval(
                      child: logoUrl.isNotEmpty
                          ? Image.network(
                              logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholderLogo(restaurant.name),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _brand,
                                    ),
                                  ),
                                );
                              },
                            )
                          : _buildPlaceholderLogo(restaurant.name),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name
                  Expanded(
                    child: Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      size: 28, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7E1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_outlined, size: 26, color: _brandDark),
          const SizedBox(width: 12),
          Container(width: 1, height: 26, color: Colors.green.shade200),
          const Expanded(
            child: Center(
              child: Text(
                'Fresh Food Healthy For You',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2E6B00),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderLogo(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'R';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: _brand,
        ),
      ),
    );
  }
}

class _MapLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(60)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final thin = Paint()
      ..color = Colors.white.withAlpha(40)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(-20, h * 0.80), Offset(w * 0.55, h * 0.45), paint);
    canvas.drawLine(
        Offset(w * 0.45, h * 0.45), Offset(w + 20, h * 0.75), paint);
    canvas.drawLine(
        Offset(w * 0.20, h * 1.0), Offset(w * 0.62, h * 0.50), paint);
    canvas.drawLine(
        Offset(w * 0.62, h * 0.50), Offset(w * 1.05, h * 0.38), paint);

    canvas.drawLine(
        Offset(w * 0.05, h * 0.55), Offset(w * 0.40, h * 0.95), thin);
    canvas.drawLine(
        Offset(w * 0.70, h * 0.95), Offset(w * 1.00, h * 0.55), thin);
    canvas.drawLine(Offset(0, h * 0.62), Offset(w * 0.35, h * 0.40), thin);
    canvas.drawLine(Offset(w * 0.75, h * 0.42), Offset(w, h * 0.60), thin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPin extends StatelessWidget {
  const _MapPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 52,
      child: CustomPaint(painter: _MapPinPainter()),
    );
  }
}

class _MapPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;
    final cx = w / 2;
    final cy = r;

    final path = Path()
      ..moveTo(cx, h)
      ..cubicTo(cx - r * 0.2, h - 8, 0, cy + r * 0.9, 0, cy)
      ..arcToPoint(Offset(w, cy),
          radius: Radius.circular(r), clockwise: true)
      ..cubicTo(w, cy + r * 0.9, cx + r * 0.2, h - 8, cx, h)
      ..close();

    canvas.drawShadow(path, const Color(0x55000000), 3, false);
    canvas.drawPath(path, Paint()..color = const Color(0xFF63B800));
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.36,
      Paint()..color = Colors.white.withAlpha(215),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}