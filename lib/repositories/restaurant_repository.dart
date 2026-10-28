import '../models/restaurant.dart';
import '../services/restaurant_service.dart';

class RestaurantRepository {
  /// Fetches restaurants from the main backend API.
  /// Supports optional [pincode] and [isVeg] parameters.
  static Future<List<Restaurant>> getRestaurants({
    String? pincode,
    String? isVeg,
  }) async {
    return await RestaurantService.fetchRestaurants(
      pincode: pincode,
      isVeg: isVeg,
    );
  }

  /// Fetches top rated restaurants from the dedicated Top Rated API.
  /// Supports optional [isVeg] parameter.
  static Future<List<Restaurant>> getTopRated({
    String? isVeg,
  }) async {
    return await RestaurantService.fetchTopRated(
      isVeg: isVeg,
    );
  }
}
