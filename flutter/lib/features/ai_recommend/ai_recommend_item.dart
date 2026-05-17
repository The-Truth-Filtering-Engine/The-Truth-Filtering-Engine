import '../map/models/restaurant_model.dart';

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
  final String categoryGroupCode;
  final String categoryGroupName;
  final String addressName;
  final String roadAddressName;
  final double? latitude;
  final double? longitude;
  final String placeUrl;
  final String phone;
  final AiRecommendEntities entities;

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
    required this.categoryGroupCode,
    required this.categoryGroupName,
    required this.addressName,
    required this.roadAddressName,
    required this.latitude,
    required this.longitude,
    required this.placeUrl,
    required this.phone,
    required this.entities,
  });

  factory AiRecommendItem.fromJson(Map<String, dynamic> json) {
    return AiRecommendItem(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      reviewTitle: json['reviewTitle']?.toString() ?? '',
      reviewDescription: json['reviewDescription']?.toString() ?? '',
      reviewUrl: json['reviewUrl']?.toString() ?? '',
      bloggerName: json['bloggerName']?.toString() ?? '',
      postDate: json['postDate']?.toString() ?? '',
      adScore: _asDouble(json['adScore']),
      placeId: json['placeId']?.toString() ?? '',
      placeName: json['placeName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      categoryGroupCode: json['categoryGroupCode']?.toString() ?? '',
      categoryGroupName: json['categoryGroupName']?.toString() ?? '',
      addressName: json['addressName']?.toString() ?? '',
      roadAddressName: json['roadAddressName']?.toString() ?? '',
      latitude: _asNullableDouble(json['lat']),
      longitude: _asNullableDouble(json['lng']),
      placeUrl: json['placeUrl']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      entities: AiRecommendEntities.fromJson(json['entities']),
    );
  }

  int get adPercent => (adScore * 100).round().clamp(0, 100);

  bool get hasLocation => latitude != null && longitude != null;

  RestaurantModel toRestaurantModel() {
    final percent = adPercent;
    return RestaurantModel(
      id: placeId.isNotEmpty ? placeId : 'review-$id',
      storeId: placeId,
      name: placeName.isNotEmpty ? placeName : name,
      address: address,
      category: category.isNotEmpty ? category : '음식점',
      categoryName: category,
      categoryGroupCode: categoryGroupCode,
      categoryGroupName: categoryGroupName,
      truthScore: (100 - percent).clamp(0, 100),
      distance: 0,
      phone: phone,
      placeUrl: placeUrl,
      addressName: addressName,
      roadAddressName: roadAddressName,
      reviewSummary: reviewTitle.isNotEmpty ? reviewTitle : reviewDescription,
      imageUrl: null,
      latitude: latitude ?? 0,
      longitude: longitude ?? 0,
    );
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

class AiRecommendEntities {
  final List<String> persons;
  final List<String> stores;
  final List<String> locations;
  final List<String> menus;
  final List<String> brands;
  final List<AiRecommendRawEntity> raw;

  const AiRecommendEntities({
    required this.persons,
    required this.stores,
    required this.locations,
    required this.menus,
    required this.brands,
    required this.raw,
  });

  const AiRecommendEntities.empty()
      : persons = const [],
        stores = const [],
        locations = const [],
        menus = const [],
        brands = const [],
        raw = const [];

  factory AiRecommendEntities.fromJson(Object? json) {
    if (json is! Map) return const AiRecommendEntities.empty();

    final data = Map<String, dynamic>.from(json);
    return AiRecommendEntities(
      persons: _asStringList(data['persons']),
      stores: _asStringList(data['stores']),
      locations: _asStringList(data['locations']),
      menus: _asStringList(data['menus']),
      brands: _asStringList(data['brands']),
      raw: _asRawEntities(data['raw']),
    );
  }

  List<String> get recommendationTags {
    return _dedupeStrings([
      ...menus,
      ...stores,
      ...brands,
      ...locations,
    ]).take(6).toList();
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const [];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<AiRecommendRawEntity> _asRawEntities(Object? value) {
    if (value is! List) return const [];

    return value
        .map(AiRecommendRawEntity.fromJson)
        .where((item) => item.text.isNotEmpty && item.type.isNotEmpty)
        .toList();
  }
}

class AiRecommendRawEntity {
  final String text;
  final String type;

  const AiRecommendRawEntity({
    required this.text,
    required this.type,
  });

  factory AiRecommendRawEntity.fromJson(Object? json) {
    if (json is! Map) {
      return const AiRecommendRawEntity(text: '', type: '');
    }

    final data = Map<String, dynamic>.from(json);
    return AiRecommendRawEntity(
      text: data['text']?.toString().trim() ?? '',
      type: data['type']?.toString().trim() ?? '',
    );
  }
}

List<String> _dedupeStrings(List<String> values) {
  final seen = <String>{};
  final result = <String>[];

  for (final value in values) {
    final text = value.trim();
    if (text.isEmpty || seen.contains(text)) continue;

    seen.add(text);
    result.add(text);
  }

  return result;
}
