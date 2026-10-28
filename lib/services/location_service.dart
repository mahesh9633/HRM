import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

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
  /// Request permissions & obtain user's current position if available.
  /// Uses a 15-second timeout and high accuracy.
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled on the device.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions were denied by user.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return null;
      }

      // Try quick last known position as immediate candidate if available
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          debugPrint('Last known position found: ${lastPos.latitude}, ${lastPos.longitude}');
        }
      } catch (_) {}

      // Obtain fresh current position
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      debugPrint('GPS OK: ${fresh.latitude}, ${fresh.longitude}');
      return fresh;
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
      return null;
    }
  }

  /// Reverse geocode lat/lng to readable address name and postal pincode using Native Geocoding with Google API fallback.
  static Future<LocationAddress?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    // 1. Try Native Platform Geocoding first (No API key restriction issues)
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 8));

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final String pincode = (place.postalCode ?? '').replaceAll(RegExp(r'\s+'), '');

        final String sublocality = place.subLocality ?? place.subThoroughfare ?? place.name ?? '';
        final String locality = place.locality ?? place.subAdministrativeArea ?? '';
        final String adminArea = place.administrativeArea ?? '';

        final nameParts = <String>[];
        if (sublocality.isNotEmpty && sublocality != place.name) {
          nameParts.add(sublocality);
        }
        if (locality.isNotEmpty && !nameParts.contains(locality)) {
          nameParts.add(locality);
        }
        if (adminArea.isNotEmpty && !nameParts.contains(adminArea)) {
          nameParts.add(adminArea);
        }

        final String addressStr = nameParts.isNotEmpty
            ? nameParts.join(', ')
            : (place.name?.isNotEmpty == true ? place.name! : 'Selected Location');

        final displayParts = <String>[];
        if (place.street != null && place.street!.trim().isNotEmpty) {
          displayParts.add(place.street!.trim());
        }
        if (sublocality.isNotEmpty && !displayParts.contains(sublocality)) {
          displayParts.add(sublocality);
        }
        if (locality.isNotEmpty && !displayParts.contains(locality)) {
          displayParts.add(locality);
        }
        if (adminArea.isNotEmpty && !displayParts.contains(adminArea)) {
          displayParts.add(adminArea);
        }
        if (pincode.isNotEmpty) {
          displayParts.add(pincode);
        }

        final String displayName = displayParts.isNotEmpty
            ? displayParts.join(', ')
            : addressStr;

        debugPrint('NATIVE GEOCODE OK: address=$addressStr, pincode=$pincode');
        return LocationAddress(
          address: addressStr.isNotEmpty ? addressStr : 'Selected Location',
          pincode: pincode,
          latitude: lat,
          longitude: lng,
          displayName: displayName,
        );
      }
    } catch (e) {
      debugPrint('Native geocoding notice: $e. Falling back to HTTP Geocoding API if key allows.');
    }

    // 2. Fallback to Google Geocoding REST API
    try {
      final googleUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${ApiConfig.googleMapsApiKey}',
      );

      final response = await http
          .get(googleUrl)
          .timeout(const Duration(seconds: 8));

      debugPrint('GEOCODE REST http status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('GEOCODE REST api status: ${data['status']} | error: ${data['error_message']}');
        if (data is Map<String, dynamic> &&
            data['status'] == 'OK' &&
            data['results'] is List &&
            (data['results'] as List).isNotEmpty) {
          final results = data['results'] as List;
          final firstResult = results.first as Map<String, dynamic>;
          String pincode = '';
          String sublocality = '';
          String locality = '';
          String adminArea = '';

          final components = firstResult['address_components'] as List? ?? [];
          for (final c in components) {
            if (c is Map<String, dynamic>) {
              final types = (c['types'] as List? ?? []).cast<String>();
              final longName = c['long_name']?.toString().trim() ?? '';

              if (types.contains('postal_code') && pincode.isEmpty) {
                pincode = longName.replaceAll(RegExp(r'\s+'), '');
              } else if (types.contains('sublocality') ||
                  types.contains('sublocality_level_1') ||
                  types.contains('neighborhood')) {
                if (sublocality.isEmpty) sublocality = longName;
              } else if (types.contains('locality')) {
                if (locality.isEmpty) locality = longName;
              } else if (types.contains('administrative_area_level_2')) {
                if (adminArea.isEmpty) adminArea = longName;
              }
            }
          }

          final nameParts = <String>[];
          if (sublocality.isNotEmpty) nameParts.add(sublocality);
          if (locality.isNotEmpty && !nameParts.contains(locality)) {
            nameParts.add(locality);
          }
          if (adminArea.isNotEmpty && !nameParts.contains(adminArea)) {
            nameParts.add(adminArea);
          }

          final formattedAddr = firstResult['formatted_address']?.toString() ?? '';
          String addressStr = nameParts.isNotEmpty
              ? nameParts.join(', ')
              : (formattedAddr.isNotEmpty ? formattedAddr.split(',').first : 'Selected Location');

          return LocationAddress(
            address: addressStr,
            pincode: pincode,
            latitude: lat,
            longitude: lng,
            displayName: formattedAddr.isNotEmpty ? formattedAddr : addressStr,
          );
        }
      }
    } catch (e) {
      debugPrint('Google reverse geocoding REST exception: $e');
    }

    // Default Fallback: Return coordinates and title with unresolved pincode
    return LocationAddress(
      address: 'Selected Location',
      pincode: '',
      latitude: lat,
      longitude: lng,
      displayName: 'Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
    );
  }

  /// Search places by name/query using native geocoding with REST API fallback.
  static Future<List<LocationAddress>> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    // 1. Try Native platform locationFromAddress
    try {
      final locations = await locationFromAddress(cleanQuery)
          .timeout(const Duration(seconds: 8));

      if (locations.isNotEmpty) {
        final results = <LocationAddress>[];
        for (final loc in locations.take(5)) {
          final addr = await reverseGeocode(loc.latitude, loc.longitude);
          if (addr != null) {
            results.add(addr);
          } else {
            results.add(LocationAddress(
              address: cleanQuery,
              pincode: '',
              latitude: loc.latitude,
              longitude: loc.longitude,
              displayName: cleanQuery,
            ));
          }
        }
        if (results.isNotEmpty) return results;
      }
    } catch (e) {
      debugPrint('Native locationFromAddress search error: $e');
    }

    // 2. Fallback to Google Geocoding REST API
    try {
      final googleUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(cleanQuery)}&key=${ApiConfig.googleMapsApiKey}',
      );

      final response = await http
          .get(googleUrl)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> &&
            data['status'] == 'OK' &&
            data['results'] is List) {
          final List list = data['results'];
          final results = <LocationAddress>[];

          for (final item in list) {
            if (item is Map<String, dynamic>) {
              final geometry = item['geometry'] as Map<String, dynamic>? ?? {};
              final location = geometry['location'] as Map<String, dynamic>? ?? {};
              final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
              final lng = (location['lng'] as num?)?.toDouble() ?? 0.0;

              String pincode = '';
              final components = item['address_components'] as List? ?? [];
              for (final c in components) {
                if (c is Map<String, dynamic>) {
                  final types = (c['types'] as List? ?? []).cast<String>();
                  if (types.contains('postal_code')) {
                    pincode = c['long_name']?.toString().replaceAll(RegExp(r'\s+'), '') ?? '';
                  }
                }
              }

              final displayName = item['formatted_address']?.toString() ?? '';
              final name = displayName.split(',').first.trim();

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
      }
    } catch (e) {
      debugPrint('Google Places search error: $e');
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
