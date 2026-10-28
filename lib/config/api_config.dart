class ApiConfig {
  /// Base API Endpoint for Restaurants
  static const String baseUrl =
      'https://myteknoland.com/JEWELLERY/index.php?route=restaurant/restaurant';

  /// Top Rated API Endpoint
  static const String topRatedUrl =
      'https://myteknoland.com/JEWELLERY/index.php?route=restaurant/restaurant.topRated';

  /// Base Image Directory URL (Standard OpenCart image directory)
  static const String imageBaseUrl =
      'https://myteknoland.com/JEWELLERY/image/';

  /// Google Maps Platform API Key
  static const String googleMapsApiKey =
      // 'AIzaSyB9FFgXl3cV3XkbiqJBACmsUHM9HMB1qeE';
      'AIzaSyCqIdr9VWtre1CUTEZxAVenvWnqOD3Hm5A';

  /// Estimated Delivery Time Constants
  static const double prepMinutes = 10;
  static const double avgSpeedKmph = 20;

  /// Resolves relative image paths against [imageBaseUrl]
  static String resolveImageUrl(String path) {
    if (path.trim().isEmpty) return '';

    final clean = path.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    String rel = clean;
    if (rel.startsWith('/')) {
      rel = rel.substring(1);
    }

    if (rel.startsWith('image/')) {
      rel = rel.substring(6);
    }

    return '$imageBaseUrl$rel';
  }
}
