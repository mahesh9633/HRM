import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

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
  static const Color _brand = Color(0xFF80CC00);

  // Extra map height that goes under the rounded top corners of the bottom card.
  static const double _mapUnderCard = 24;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _currentCenter = const LatLng(14.1956, 78.8083); // Default Kadapa/AP
  LocationAddress? _selectedAddress;
  bool _isGeocoding = false;
  bool _isLocatingCurrent = false;

  Timer? _debounceTimer;
  List<LocationAddress> _searchResults = [];
  bool _isSearching = false;

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
    setState(() {
      _isLocatingCurrent = true;
    });

    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (pos != null) {
      final center = LatLng(pos.latitude, pos.longitude);
      _mapController.move(center, 15.0);
      await _reverseGeocodeLocation(center);
    } else {
      await _reverseGeocodeLocation(_currentCenter);
    }

    if (mounted) {
      setState(() {
        _isLocatingCurrent = false;
      });
    }
  }

  Future<void> _reverseGeocodeLocation(LatLng point) async {
    setState(() {
      _currentCenter = point;
      _isGeocoding = true;
    });

    final address = await LocationService.reverseGeocode(
      point.latitude,
      point.longitude,
    );

    if (!mounted) return;
    setState(() {
      _selectedAddress = address;
      _isGeocoding = false;
    });
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

  void _selectSearchResult(LocationAddress address) {
    final point = LatLng(address.latitude, address.longitude);
    _searchController.text = address.address;
    setState(() {
      _searchResults = [];
      _selectedAddress = address;
      _currentCenter = point;
    });
    _mapController.move(point, 15.0);

    if (address.pincode.isEmpty) {
      _reverseGeocodeLocation(point);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ------------------------------- UI ---------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // The keyboard should not squeeze the map and the bottom card.
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
      // CHANGED: map area and bottom card are now in a Column.
      // The "Use Current Location" button sits inside the map area, so it
      // is always just above the bottom card, on any screen size.
      body: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Map (a little taller so it goes under the card's corners)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: -_mapUnderCard,
                  child: _buildMap(),
                ),

                // Search bar + results
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildSearchOverlay(),
                ),

                // "Use Current Location" button (always above the card)
                Positioned(
                  right: 16,
                  bottom: _mapUnderCard + 12,
                  child: _buildCurrentLocationButton(),
                ),
              ],
            ),
          ),

          // Selected address card & confirm button
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentCenter,
        initialZoom: 14.0,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            _currentCenter = position.center;
          }
        },
        onMapEvent: (event) {
          if (event is MapEventMoveEnd) {
            _reverseGeocodeLocation(_currentCenter);
          }
        },
        onTap: (tapPosition, point) {
          _mapController.move(point, _mapController.camera.zoom);
          _reverseGeocodeLocation(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.myteknoland.hrm',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _currentCenter,
              width: 48,
              height: 48,
              child: const Icon(
                Icons.location_on,
                size: 48,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ],
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
      // SafeArea keeps the button clear of the phone's bottom gesture bar.
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
                    'Move map or search to select location',
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
                    color: const Color(0xFFEAF5DD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pincode: ${_selectedAddress!.pincode}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E6B00),
                    ),
                  ),
                )
              else
                Text(
                  'Pincode: Not resolved (will search all nearby)',
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