import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/restaurant.dart';

class RestaurantService {
  static Future<List<Restaurant>> fetchRestaurants({
    String? pincode,
    String? isVeg,
  }) async {
    try {
      String urlStr = ApiConfig.baseUrl;

      final queryParams = <String>[];
      if (pincode != null && pincode.trim().isNotEmpty) {
        queryParams.add('pincode=${Uri.encodeComponent(pincode.trim())}');
      }
      if (isVeg != null && isVeg.trim().isNotEmpty) {
        queryParams.add('is_veg=${Uri.encodeComponent(isVeg.trim())}');
      }

      if (queryParams.isNotEmpty) {
        final separator = urlStr.contains('?') ? '&' : '?';
        urlStr += separator + queryParams.join('&');
      }

      final uri = Uri.parse(urlStr);
      debugPrint('Fetching restaurants API URL: $uri');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final dynamic jsonResponse = jsonDecode(response.body);

      if (jsonResponse is! Map<String, dynamic>) {
        return [];
      }

      final status = jsonResponse['status']?.toString();
      if (status != 'success') {
        throw Exception('API status indicates failure: $status');
      }

      final data = jsonResponse['data'];
      if (data == null || data is! List) {
        return [];
      }

      final List<Restaurant> restaurants = data
          .map((item) {
            if (item is Map<String, dynamic>) {
              try {
                return Restaurant.fromJson(item);
              } catch (e) {
                debugPrint('Error parsing restaurant item: $e');
                return null;
              }
            }
            return null;
          })
          .whereType<Restaurant>()
          .where((r) => r.status == '1')
          .toList();

      // Sort by sequence ascending
      restaurants.sort((a, b) => a.sequence.compareTo(b.sequence));

      debugPrint('Restaurants fetched successfully: ${restaurants.length}');
      return restaurants;
    } catch (e) {
      debugPrint('Error fetching restaurants from API: $e');
      rethrow;
    }
  }

  static Future<List<Restaurant>> fetchTopRated({
    String? isVeg,
  }) async {
    try {
      String urlStr = ApiConfig.topRatedUrl;

      if (isVeg != null && isVeg.trim().isNotEmpty) {
        final separator = urlStr.contains('?') ? '&' : '?';
        urlStr += '${separator}is_veg=${Uri.encodeComponent(isVeg.trim())}';
      }

      final uri = Uri.parse(urlStr);
      debugPrint('Fetching top rated restaurants API URL: $uri');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final dynamic jsonResponse = jsonDecode(response.body);

      if (jsonResponse is! Map<String, dynamic>) {
        return [];
      }

      final status = jsonResponse['status']?.toString();
      if (status != 'success') {
        throw Exception('API status indicates failure: $status');
      }

      final data = jsonResponse['data'];
      if (data == null || data is! List) {
        return [];
      }

      final List<Restaurant> restaurants = data
          .map((item) {
            if (item is Map<String, dynamic>) {
              try {
                return Restaurant.fromJson(item);
              } catch (e) {
                debugPrint('Error parsing top rated restaurant item: $e');
                return null;
              }
            }
            return null;
          })
          .whereType<Restaurant>()
          .where((r) => r.status == '1')
          .toList();

      debugPrint('Top rated restaurants fetched: ${restaurants.length}');
      return restaurants;
    } catch (e) {
      debugPrint('Error fetching top rated restaurants: $e');
      return [];
    }
  }
}
