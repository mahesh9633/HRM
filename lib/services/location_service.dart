import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationAddress {
  final String address;
  final String pincode;
  final double latitude;
  final double longitude;
  final String displayName;

  LocationAddress({
    required this.address,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  @override
  String toString() => '$address ($pincode)';
}

class LocationService {
  static const Map<String, String> _headers = {
    'User-Agent': 'HRMApp/1.0 (Android App)',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Request permissions & obtain user's current position if available.
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Listen for position updates without requesting permissions repeatedly.
  static Stream<Position>? getPositionStream() {
    try {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 50,
        ),
      );
    } catch (e) {
      debugPrint('Error creating position stream: $e');
      return null;
    }
  }

  /// Reverse geocode lat/lng to readable address name and postal pincode.
  static Future<LocationAddress?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1',
      );
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final addr = data['address'] as Map<String, dynamic>? ?? {};
          var pincode = (addr['postcode'] ??
                  addr['postal_code'] ??
                  addr['postalcode'] ??
                  addr['zip'])
              ?.toString()
              .replaceAll(RegExp(r'\s+'), '') ??
              '';
          final displayNameStr = data['display_name']?.toString() ?? '';

          if (pincode.isEmpty && displayNameStr.isNotEmpty) {
            final match = RegExp(r'\b[1-9]\d{5}\b').firstMatch(displayNameStr);
            if (match != null) {
              pincode = match.group(0)!;
            }
          }

          final parts = <String>[];
          final area = addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['hamlet'] ??
              addr['village'] ??
              addr['town'] ??
              addr['city'] ??
              addr['county'] ??
              addr['state_district'];

          if (area != null && area.toString().isNotEmpty) {
            parts.add(area.toString());
          }
          if (addr['road'] != null && addr['road'].toString() != area.toString()) {
            parts.add(addr['road'].toString());
          }
          if (addr['state_district'] != null &&
              addr['state_district'].toString() != area.toString() &&
              !parts.contains(addr['state_district'].toString())) {
            parts.add(addr['state_district'].toString());
          }

          String addressStr = parts.isNotEmpty ? parts.join(', ') : '';

          // If address is numeric or empty, extract location name from display_name
          if (addressStr.isEmpty || RegExp(r'^\d+$').hasMatch(addressStr.trim())) {
            if (displayNameStr.isNotEmpty) {
              final rawParts = displayNameStr.split(',');
              final nonNumeric = rawParts
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p) && p.toLowerCase() != 'india')
                  .take(2);
              if (nonNumeric.isNotEmpty) {
                addressStr = nonNumeric.join(', ');
              }
            }
          }

          if (addressStr.isEmpty) {
            addressStr = 'Detected Location';
          }

          return LocationAddress(
            address: addressStr,
            pincode: pincode,
            latitude: lat,
            longitude: lng,
            displayName: displayNameStr.isNotEmpty ? displayNameStr : addressStr,
          );
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
    return LocationAddress(
      address: 'Selected Location',
      pincode: '',
      latitude: lat,
      longitude: lng,
      displayName: 'Location ($lat, $lng)',
    );
  }

  /// Search places by name/query.
  static Future<List<LocationAddress>> searchPlaces(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&addressdetails=1&limit=6',
      );
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        final results = <LocationAddress>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
            final lng = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            var pincode = (addr['postcode'] ??
                    addr['postal_code'] ??
                    addr['postalcode'] ??
                    addr['zip'])
                ?.toString()
                .replaceAll(RegExp(r'\s+'), '') ??
                '';
            final displayName = item['display_name']?.toString() ?? '';
            if (pincode.isEmpty && displayName.isNotEmpty) {
              final match = RegExp(r'\b[1-9]\d{5}\b').firstMatch(displayName);
              if (match != null) {
                pincode = match.group(0)!;
              }
            }
            final name = item['name']?.toString() ?? displayName.split(',').first;

            results.add(LocationAddress(
              address: name,
              pincode: pincode,
              latitude: lat,
              longitude: lng,
              displayName: displayName,
            ));
          }
        }
        return results;
      }
    } catch (e) {
      debugPrint('Search places error: $e');
    }
    return [];
  }

  /// Calculates distance in meters between two lat/lng coordinates.
  static double calculateDistanceInMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    try {
      return Geolocator.distanceBetween(
        startLat,
        startLng,
        endLat,
        endLng,
      );
    } catch (_) {
      return _haversineDistance(startLat, startLng, endLat, endLng);
    }
  }

  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }

  /// Format distance string e.g. "2.5 km away" or "450 m away"
  static String formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km away';
    } else {
      return '${meters.round()} m away';
    }
  }
}
