import 'dart:math';
import '../config/api_config.dart';

class OperationDay {
  final String day; // "monday", "tuesday", ...
  final String openingTime; // "14:00:00"
  final String closingTime; // "22:00:00"
  final String status; // "1"

  const OperationDay({
    required this.day,
    required this.openingTime,
    required this.closingTime,
    required this.status,
  });

  factory OperationDay.fromJson(Map<String, dynamic> json) {
    return OperationDay(
      day: json['day']?.toString().toLowerCase().trim() ?? '',
      openingTime: json['opening_time']?.toString().trim() ??
          json['openingTime']?.toString().trim() ??
          '00:00:00',
      closingTime: json['closing_time']?.toString().trim() ??
          json['closingTime']?.toString().trim() ??
          '23:59:59',
      status: json['status']?.toString().trim() ?? '1',
    );
  }
}

class RestaurantBanner {
  final String image;
  final String status; // "1"
  final int sorting;
  final String? link;

  const RestaurantBanner({
    required this.image,
    this.status = '1',
    this.sorting = 0,
    this.link,
  });

  factory RestaurantBanner.fromJson(dynamic json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val.trim()) ?? 0;
      return 0;
    }

    if (json is Map<String, dynamic>) {
      return RestaurantBanner(
        image: json['image']?.toString().trim() ?? '',
        status: json['status']?.toString().trim() ?? '1',
        sorting: parseInt(
            json['sorting'] ?? json['sort_order'] ?? json['sort'] ?? json['sequence']),
        link: json['link']?.toString().trim(),
      );
    } else if (json is String && json.trim().isNotEmpty) {
      return RestaurantBanner(image: json.trim());
    }
    return const RestaurantBanner(image: '');
  }

  bool get isActive => status == '1' || status.isEmpty;

  String getFullImageUrl() {
    return ApiConfig.resolveImageUrl(image);
  }
}

class Restaurant {
  final String id;
  final String name;
  final String url;
  final String location; // "14.1956,78.8083"
  final String address; // e.g. "Madanapalli Road", "Rayachoti"
  final double? lat;
  final double? long;
  final String logo; // "catalog/restaurant/smr.png"
  final int sequence;
  final String pincode;
  final String isVeg; // "1" or "0"
  final double rating;
  final String status; // "1"
  final List<RestaurantBanner> bannerItems;
  final List<String> banners; // list of image relative paths
  final List<OperationDay> operationDays;

  const Restaurant({
    required this.id,
    required this.name,
    required this.url,
    required this.location,
    this.address = '',
    this.lat,
    this.long,
    required this.logo,
    required this.sequence,
    required this.pincode,
    required this.isVeg,
    required this.rating,
    required this.status,
    this.bannerItems = const [],
    this.banners = const [],
    this.operationDays = const [],
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val.trim()) ?? 0;
      return 0;
    }

    double parseDouble(dynamic val, {double fallback = 0.0}) {
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val.trim()) ?? fallback;
      return fallback;
    }

    // Location parsing "lat,long"
    final rawLoc = json['location']?.toString().trim() ?? '';
    double? parsedLat;
    double? parsedLong;
    if (rawLoc.isNotEmpty && rawLoc.contains(',')) {
      final parts = rawLoc.split(',');
      if (parts.length >= 2) {
        parsedLat = double.tryParse(parts[0].trim());
        parsedLong = double.tryParse(parts[1].trim());
      }
    }

    // Banners parsing from List of Maps e.g. [{"image": "path", "status": "1", "sorting": "1"}] or List of Strings
    final List<RestaurantBanner> parsedBannerItems = [];
    final List<String> parsedBanners = [];
    final rawBanners = json['banners'];
    if (rawBanners is List) {
      for (final item in rawBanners) {
        final banner = RestaurantBanner.fromJson(item);
        if (banner.image.isNotEmpty) {
          parsedBannerItems.add(banner);
          if (banner.isActive) {
            parsedBanners.add(banner.image);
          }
        }
      }
    }

    // Operation Days parsing
    final List<OperationDay> parsedDays = [];
    final rawDays = json['operation_days'] ?? json['operationDays'];
    if (rawDays is List) {
      for (final item in rawDays) {
        if (item is Map<String, dynamic>) {
          parsedDays.add(OperationDay.fromJson(item));
        }
      }
    }

    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString().trim() ??
          json['link']?.toString().trim() ??
          '',
      location: rawLoc,
      address: json['address']?.toString().trim() ?? '',
      lat: parsedLat,
      long: parsedLong,
      logo: json['logo']?.toString().trim() ?? '',
      sequence: parseInt(json['sequence']),
      pincode: json['pincode']?.toString().trim() ?? '',
      isVeg: json['is_veg']?.toString().trim() ??
          json['isVeg']?.toString().trim() ??
          '0',
      rating: parseDouble(json['rating'], fallback: 4.0),
      status: json['status']?.toString().trim() ?? '1',
      bannerItems: parsedBannerItems,
      banners: parsedBanners,
      operationDays: parsedDays,
    );
  }

  double? get latitude {
    if (lat != null) return lat;
    if (location.isEmpty || !location.contains(',')) return null;
    return double.tryParse(location.split(',')[0].trim());
  }

  double? get longitude {
    if (long != null) return long;
    if (location.isEmpty || !location.contains(',')) return null;
    return double.tryParse(location.split(',')[1].trim());
  }

  bool get hasValidCoordinates => latitude != null && longitude != null;

  bool get isVegetarian => isVeg == '1';

  String getFullLogoUrl() {
    return ApiConfig.resolveImageUrl(logo);
  }

  /// Active banners sorted by `sorting` field in ascending order
  List<RestaurantBanner> get activeSortedBannerItems {
    final active = bannerItems.where((b) => b.isActive && b.image.isNotEmpty).toList();
    active.sort((a, b) => a.sorting.compareTo(b.sorting));
    return active;
  }

  List<String> getFullBannerUrls() {
    final sortedItems = activeSortedBannerItems;
    if (sortedItems.isNotEmpty) {
      return sortedItems.map((b) => b.getFullImageUrl()).toList();
    }
    if (banners.isEmpty) return [];
    return banners.map((b) => ApiConfig.resolveImageUrl(b)).toList();
  }

  /// Haversine distance calculation in kilometers
  double distanceFrom(double userLat, double userLng) {
    final rLat = latitude;
    final rLng = longitude;
    if (rLat == null || rLng == null) return 0.0;

    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 -
        cos((rLat - userLat) * p) / 2 +
        cos(userLat * p) * cos(rLat * p) * (1 - cos((rLng - userLng) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R * asin...
  }

  String? formattedDistance(double? userLat, double? userLng) {
    if (userLat == null || userLng == null || !hasValidCoordinates) {
      return null;
    }
    final distKm = distanceFrom(userLat, userLng);
    if (distKm < 0.1) return '< 100 m';
    if (distKm < 1.0) return '${(distKm * 1000).round()} m';
    return '${distKm.toStringAsFixed(1)} km';
  }

  /// Returns estimated delivery time text e.g. "20-25 MINS",
  /// or null if user location is unavailable
  String? estimatedTimeText(double? userLat, double? userLng) {
    if (userLat == null || userLng == null || !hasValidCoordinates) {
      return null;
    }
    final distKm = distanceFrom(userLat, userLng);
    final totalMins =
        ApiConfig.prepMinutes + (distKm / ApiConfig.avgSpeedKmph) * 60;
    int roundedTotal = (totalMins / 5.0).ceil() * 5;
    if (roundedTotal < 15) roundedTotal = 15;
    return '$roundedTotal-${roundedTotal + 5} MINS';
  }

  /// Parses "HH:mm:ss" or "HH:mm" into total minutes from midnight
  int _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.isEmpty) return 0;
      final h = int.parse(parts[0]);
      final m = parts.length > 1 ? int.parse(parts[1]) : 0;
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  /// Checks if the restaurant is currently open based on operation_days and device local time
  bool isOpenNow() {
    if (operationDays.isEmpty) return false;

    final now = DateTime.now();
    const dayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final todayName = dayNames[now.weekday - 1];

    final todayOps = operationDays
        .where((op) => op.day == todayName && op.status == '1')
        .toList();

    if (todayOps.isEmpty) return false;

    final nowMinutes = now.hour * 60 + now.minute;

    for (final op in todayOps) {
      final openMin = _parseTimeToMinutes(op.openingTime);
      final closeMin = _parseTimeToMinutes(op.closingTime);

      if (closeMin > openMin) {
        if (nowMinutes >= openMin && nowMinutes < closeMin) {
          return true;
        }
      } else {
        // Overnight operating hours e.g. 18:00 to 02:00
        if (nowMinutes >= openMin || nowMinutes < closeMin) {
          return true;
        }
      }
    }

    return false;
  }

  /// Computes the exact [DateTime] when the restaurant will next open
  DateTime? nextOpeningTime() {
    if (operationDays.isEmpty) return null;

    final now = DateTime.now();
    const dayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];

    final nowMinutes = now.hour * 60 + now.minute;

    // 1. Check today for a future opening time
    final todayName = dayNames[now.weekday - 1];
    final todayOps = operationDays
        .where((op) => op.day == todayName && op.status == '1')
        .toList();

    for (final op in todayOps) {
      final openMin = _parseTimeToMinutes(op.openingTime);
      if (openMin > nowMinutes) {
        final openHour = openMin ~/ 60;
        final openMinute = openMin % 60;
        return DateTime(
            now.year, now.month, now.day, openHour, openMinute, 0);
      }
    }

    // 2. Check next 7 days
    for (int dayOffset = 1; dayOffset <= 7; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final targetDayName = dayNames[targetDate.weekday - 1];

      final targetOps = operationDays
          .where((op) => op.day == targetDayName && op.status == '1')
          .toList();

      if (targetOps.isNotEmpty) {
        // Pick the earliest opening time for that day
        OperationDay bestOp = targetOps.first;
        int minOpen = _parseTimeToMinutes(bestOp.openingTime);

        for (final op in targetOps) {
          final m = _parseTimeToMinutes(op.openingTime);
          if (m < minOpen) {
            minOpen = m;
            bestOp = op;
          }
        }

        final openHour = minOpen ~/ 60;
        final openMinute = minOpen % 60;
        return DateTime(targetDate.year, targetDate.month, targetDate.day,
            openHour, openMinute, 0);
      }
    }

    return null;
  }

  String _formatTime12h(DateTime dt) {
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;
    return '$hour:$minute $period';
  }

  String _dayShortName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  /// Returns descriptive text for the closed state
  String openingText() {
    if (isOpenNow()) return 'Open';

    final nextOpen = nextOpeningTime();
    if (nextOpen == null) return 'Currently closed';

    final now = DateTime.now();
    final diff = nextOpen.difference(now);

    if (diff.isNegative) return 'Currently closed';

    if (diff.inSeconds < 60) {
      final secs = diff.inSeconds <= 0 ? 1 : diff.inSeconds;
      return 'Opens in $secs ${secs == 1 ? "sec" : "secs"}';
    }

    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return 'Opens today in $mins ${mins == 1 ? "min" : "mins"}';
    }

    if (nextOpen.year == now.year &&
        nextOpen.month == now.month &&
        nextOpen.day == now.day) {
      return 'Opens today at ${_formatTime12h(nextOpen)}';
    }

    final tomorrow = now.add(const Duration(days: 1));
    if (nextOpen.year == tomorrow.year &&
        nextOpen.month == tomorrow.month &&
        nextOpen.day == tomorrow.day) {
      return 'Opens tomorrow at ${_formatTime12h(nextOpen)}';
    }

    return 'Opens ${_dayShortName(nextOpen.weekday)} at ${_formatTime12h(nextOpen)}';
  }
}
