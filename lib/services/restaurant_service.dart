import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';

class RestaurantService {
  static const String apiUrl =
      'https://myteknoland.com/JEWELLERY/index.php?route=restaurant/restaurant';

  static Future<List<Restaurant>> fetchRestaurants({
    String? pincode,
    String? isVeg,
  }) async {
    try {
      String urlStr = apiUrl;

      if (pincode != null && pincode.trim().isNotEmpty) {
        final cleanPincode = Uri.encodeComponent(pincode.trim());
        urlStr += '&pincode=$cleanPincode';
      }

      if (isVeg != null && isVeg.trim().isNotEmpty) {
        final cleanVeg = Uri.encodeComponent(isVeg.trim());
        urlStr += '&is_veg=$cleanVeg';
      }

      final uri = Uri.parse(urlStr);
      debugPrint('Detected pincode parameter: $pincode');
      debugPrint('Outgoing API URL: $uri');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      dynamic jsonResponse;
      try {
        jsonResponse = jsonDecode(response.body);
      } catch (e) {
        debugPrint('JSON parse error on response: ${response.body}');
        rethrow;
      }

      if (jsonResponse is! Map<String, dynamic>) {
        debugPrint('Number of restaurants returned: 0');
        return [];
      }

      final status = jsonResponse['status']?.toString();
      if (status != 'success') {
        throw Exception('API status indicates failure: $status');
      }

      final data = jsonResponse['data'];
      if (data == null || data is! List) {
        debugPrint('Number of restaurants returned: 0');
        return [];
      }

      final List<Restaurant> restaurants = data
          .map((item) {
            if (item is Map<String, dynamic>) {
              return Restaurant.fromJson(item);
            }
            return null;
          })
          .whereType<Restaurant>()
          .where((r) => r.status == '1')
          .toList();

      // Sort by sequence in ascending order
      restaurants.sort((a, b) => a.sequence.compareTo(b.sequence));

      debugPrint('Number of restaurants returned: ${restaurants.length}');
      return restaurants;
    } catch (e) {
      debugPrint('Error fetching restaurants: $e');
      rethrow;
    }
  }
}
