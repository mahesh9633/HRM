import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  final LocationAddress? initialLocation;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const Color _brand = AppTheme.primary;

  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  // Default initial center (Rayachoti/AP)
  LatLng _currentCenter = const LatLng(14.0583, 78.7512);
  LocationAddress? _selectedAddress;
  bool _isGeocoding = false;
  bool _isLocatingCurrent = false;

  Timer? _debounceTimer;
  List<LocationAddress> _searchResults = [];
  bool _isSearching = false;

  int _geocodeRequestToken = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedAddress = widget.initialLocation;
      _currentCenter = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
    } else {
      _fetchCurrentLocation();
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLocatingCurrent = true;
    });

    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (pos != null) {
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentCenter = point;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(point, 16.0),
      );

      await _reverseGeocodeLocation(point);
    } else {
      _showLocationErrorSnackBar();
    }

    if (mounted) {
      setState(() {
        _isLocatingCurrent = false;
      });
    }
  }

  void _showLocationErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Unable to get GPS location. Please check location permissions and GPS settings.',
        ),
        backgroundColor: AppTheme.closedRed,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'SETTINGS',
          textColor: Colors.white,
          onPressed: () {
            Geolocator.openLocationSettings();
          },
        ),
      ),
    );
  }

  Future<void> _reverseGeocodeLocation(LatLng point) async {
    final currentToken = ++_geocodeRequestToken;
    setState(() {
      _currentCenter = point;
      _isGeocoding = true;
    });

    final address = await LocationService.reverseGeocode(
      point.latitude,
      point.longitude,
    );

    if (!mounted || currentToken != _geocodeRequestToken) return;

    setState(() {
      _selectedAddress = address;
      _isGeocoding = false;
    });
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _currentCenter = point;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(point),
    );

    _reverseGeocodeLocation(point);
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _isSearching = true;
      });

      final results = await LocationService.searchPlaces(query);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSearchResult(LocationAddress address) async {
    final point = LatLng(address.latitude, address.longitude);
    _searchController.text = address.address;

    setState(() {
      _searchResults = [];
      _selectedAddress = address;
      _currentCenter = point;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(point, 16.0),
    );

    if (address.pincode.isEmpty) {
      _reverseGeocodeLocation(point);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------- UI ---------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'Choose Location',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _brand,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Google Map Widget (Native google_maps_flutter matching TaxiRider)
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentCenter,
                      zoom: 16.0,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _onMapTapped,
                    onCameraMove: (position) {
                      _currentCenter = position.target;
                    },
                    onCameraIdle: () {
                      _reverseGeocodeLocation(_currentCenter);
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _currentCenter,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange,
                        ),
                      ),
                    },
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    mapToolbarEnabled: false,
                  ),
                ),

                // Center Pin Overlay Icon
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: AppTheme.closedRed,
                    ),
                  ),
                ),

                // Search Bar Overlay
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildSearchOverlay(),
                ),

                // "Use Current Location" Floating Button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _buildCurrentLocationButton(),
                ),
              ],
            ),
          ),

          // Selected Address Card & Confirm Button
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Column(
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search city, area, or address...',
              prefixIcon: const Icon(Icons.search, color: _brand),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Search Results Dropdown List
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _brand,
                  ),
                ),
                SizedBox(width: 10),
                Text('Searching locations...'),
              ],
            ),
          )
        else if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_city, color: _brand),
                  title: Text(
                    item.address,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _selectSearchResult(item),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentLocationButton() {
    return FloatingActionButton.extended(
      heroTag: 'fab_use_gps',
      onPressed: _isLocatingCurrent ? null : _fetchCurrentLocation,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 4,
      icon: _isLocatingCurrent
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _brand,
              ),
            )
          : const Icon(Icons.my_location, color: _brand),
      label: const Text(
        'Use Current Location',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: _brand, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Selected Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (_isGeocoding)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _brand,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                _selectedAddress?.displayName ??
                    _selectedAddress?.address ??
                    'Tap map or search to select location',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 10),

              // Pincode badge
              if (_selectedAddress?.pincode.isNotEmpty ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pincode: ${_selectedAddress!.pincode}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.openGreen,
                    ),
                  ),
                )
              else
                Text(
                  'Pincode: Not resolved for coordinates',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    fontStyle: FontStyle.italic,
                  ),
                ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedAddress == null
                      ? null
                      : () {
                          Navigator.pop(context, _selectedAddress);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
