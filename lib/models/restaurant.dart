class Restaurant {
  final String id;
  final String name;
  final String url;
  final String location;
  final String logo;
  final int sequence;
  final String status;
  final String pincode;
  final String isVeg; // "1" for Veg, "0" for Non-Veg

  const Restaurant({
    required this.id,
    required this.name,
    required this.url,
    required this.location,
    required this.logo,
    required this.sequence,
    required this.status,
    required this.pincode,
    required this.isVeg,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    int parseSequence(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      sequence: parseSequence(json['sequence']),
      status: json['status']?.toString() ?? '0',
      pincode: json['pincode']?.toString() ?? '',
      isVeg: json['is_veg']?.toString() ?? '0',
    );
  }

  bool get isVegetarian => isVeg == '1';

  /// Parses latitude from [location] ("lat,lng"). Returns null if invalid.
  double? get latitude {
    if (location.isEmpty) return null;
    final parts = location.split(',');
    if (parts.length < 2) return null;
    return double.tryParse(parts[0].trim());
  }

  /// Parses longitude from [location] ("lat,lng"). Returns null if invalid.
  double? get longitude {
    if (location.isEmpty) return null;
    final parts = location.split(',');
    if (parts.length < 2) return null;
    return double.tryParse(parts[1].trim());
  }

  bool get hasValidCoordinates => latitude != null && longitude != null;

  /// Resolves logo URL against OpenCart / API base image path.
  String getFullLogoUrl({String baseOrigin = 'https://myteknoland.com/JEWELLERY'}) {
    if (logo.isEmpty) return '';

    if (logo.startsWith('http://') || logo.startsWith('https://')) {
      return logo;
    }

    final cleanLogo = logo.startsWith('/') ? logo.substring(1) : logo;

    if (cleanLogo.startsWith('image/')) {
      return '$baseOrigin/$cleanLogo';
    } else {
      return '$baseOrigin/image/$cleanLogo';
    }
  }
}
