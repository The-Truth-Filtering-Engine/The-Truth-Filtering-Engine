class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String category;
  final int truthScore;
  final int distance;
  final String reviewSummary;
  final String? phone;
  final String? placeUrl;
  final String? imageUrl;
  final double latitude;
  final double longitude;

  // ── 즐겨찾기 및 유저 관련 필드 ──
  final bool isBookmarked;
  final String? userId;
  final DateTime? createdAt;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.truthScore,
    this.distance = 0,
    required this.reviewSummary,
    this.phone,
    this.placeUrl,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.isBookmarked = false,
    this.userId,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'category': category,
      'truthScore': truthScore,
      'distance': distance,
      'reviewSummary': reviewSummary,
      'phone': phone,
      'placeUrl': placeUrl,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'isBookmarked': isBookmarked,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    return RestaurantModel(
      id: (json['id'] ?? json['placeId'] ?? '').toString(),
      name: (json['name'] ?? json['placeName'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      category: (json['category'] ?? '음식점').toString(),
      truthScore: _asInt(json['truthScore'] ?? json['truth_score'], fallback: 0),
      distance: _asInt(json['distance'], fallback: 0),
      reviewSummary: (json['reviewSummary'] ?? json['review_summary'] ?? '').toString(),
      phone: json['phone']?.toString(),
      placeUrl: (json['placeUrl'] ?? json['link'] ?? json['place_url'])?.toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
      latitude: _asDouble(json['latitude'] ?? json['lat'], fallback: 0),
      longitude: _asDouble(json['longitude'] ?? json['lng'], fallback: 0),
      isBookmarked: json['isBookmarked'] == true || json['is_bookmarked'] == true,
      userId: (json['userId'] ?? json['user_id'])?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  RestaurantModel copyWith({
    bool? isBookmarked,
    String? userId,
    DateTime? createdAt,
    int? truthScore,
    String? reviewSummary,
  }) {
    return RestaurantModel(
      id: id,
      name: name,
      address: address,
      category: category,
      truthScore: truthScore ?? this.truthScore,
      distance: distance,
      reviewSummary: reviewSummary ?? this.reviewSummary,
      phone: phone,
      placeUrl: placeUrl,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _asDouble(Object? value, {required double fallback}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  // ── UI Helper: Marker 타입 ──
  MarkerType get markerType {
    if (truthScore >= 80) return MarkerType.high;
    if (truthScore >= 70) return MarkerType.mid;
    return MarkerType.low;
  }

  // ── UI Helper: 카테고리 로직 ──
  String get primaryCategory {
    final parts = category.split(' > ');
    if (parts.length >= 2) return parts[1].trim();
    return category.trim();
  }

  String get categoryImagePath {
    const base = 'assets/images/categories';
    const map = <String, String>{
      '한식': '$base/korean.png',
      '일식': '$base/japanese.png',
      '중식': '$base/chinese.png',
      '양식': '$base/western.png',
      '패스트푸드': '$base/fastfood.png',
      '분식': '$base/bunsik.png',
      '카페': '$base/cafe.png',
      '술집': '$base/bar.png',
      '아시안': '$base/asian.png',
      '아시안/퓨전': '$base/asian.png',
      '뷔페': '$base/buffet.png',
      '치킨': '$base/chicken.png',
      '피자': '$base/pizza.png',
      '고기/구이': '$base/meat.png',
    };
    return map[primaryCategory] ?? '$base/default.png';
  }

  String get categoryThumbnailPath {
    const base = 'assets/images/thumbnails';
    const map = <String, String>{
      '한식': '$base/korean.png',
      '일식': '$base/japanese.png',
      '중식': '$base/chinese.png',
      '양식': '$base/western.png',
      '패스트푸드': '$base/fastfood.png',
      '분식': '$base/bunsik.png',
      '카페': '$base/cafe.png',
      '술집': '$base/bar.png',
      '아시안': '$base/asian.png',
      '아시안/퓨전': '$base/asian.png',
      '뷔페': '$base/buffet.png',
      '치킨': '$base/chicken.png',
      '피자': '$base/pizza.png',
      '고기/구이': '$base/meat.png',
    };
    return map[primaryCategory] ?? '$base/default.png';
  }
}

enum MarkerType { high, mid, low }
