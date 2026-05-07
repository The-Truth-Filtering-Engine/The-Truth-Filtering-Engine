import '../features/1-1_map/models/restaurant_model.dart';

class AiRecommendItem {
  final int id;
  final String name;
  final String reviewTitle;
  final String reviewDescription;
  final String reviewUrl;
  final String bloggerName;
  final String postDate;
  final double adScore;
  final String placeId;
  final String placeName;
  final String address;
  final String category;
  final double? latitude;
  final double? longitude;
  final String placeUrl;
  final String phone;

  const AiRecommendItem({
    required this.id,
    required this.name,
    required this.reviewTitle,
    required this.reviewDescription,
    required this.reviewUrl,
    required this.bloggerName,
    required this.postDate,
    required this.adScore,
    required this.placeId,
    required this.placeName,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.placeUrl,
    required this.phone,
  });

  factory AiRecommendItem.fromJson(Map<String, dynamic> json) {
    return AiRecommendItem(
      id: _asInt(json['id']),
      name: _clean(json['name']),
      reviewTitle: _clean(json['reviewTitle']),
      reviewDescription: _clean(json['reviewDescription']),
      reviewUrl: _clean(json['reviewUrl']),
      bloggerName: _clean(json['bloggerName']),
      postDate: _formatDate(json['postDate']),
      adScore: _asDouble(json['adScore']),
      placeId: _clean(json['placeId']),
      placeName: _clean(json['placeName']),
      address: _clean(json['address']),
      category: _clean(json['category']).isEmpty ? '음식점' : _clean(json['category']),
      latitude: _asNullableDouble(json['lat'] ?? json['latitude']),
      longitude: _asNullableDouble(json['lng'] ?? json['longitude']),
      placeUrl: _clean(json['placeUrl']),
      phone: _clean(json['phone']),
    );
  }

  int get adPercent => (adScore * 100).round().clamp(0, 100);
  bool get hasLocation => latitude != null && longitude != null;

  RestaurantModel toRestaurantModel() {
    final percent = adPercent;
    return RestaurantModel(
      id: placeId.isNotEmpty ? placeId : 'review-$id',
      name: placeName.isNotEmpty ? placeName : name,
      address: address,
      category: category,
      truthScore: (100 - percent).clamp(0, 100),
      distance: 0,
      phone: phone,
      placeUrl: placeUrl,
      reviewSummary: reviewTitle.isNotEmpty ? reviewTitle : reviewDescription,
      imageUrl: null,
      latitude: latitude ?? 0,
      longitude: longitude ?? 0,
    );
  }

  // ── 데이터 정제 헬퍼 ──
  static String _clean(dynamic value) {
    return (value ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  static String _formatDate(dynamic value) {
    final raw = _clean(value);
    if (RegExp(r'^\d{8}$').hasMatch(raw)) {
      return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
    }
    return raw;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static double? _asNullableDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
