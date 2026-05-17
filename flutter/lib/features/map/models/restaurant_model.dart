class RestaurantModel {
  final String id;
  final String? storeId;
  final String name;
  final String address;
  final String category;
  final String? categoryName;
  final String? categoryGroupCode;
  final String? categoryGroupName;
  final int truthScore;
  final int distance;
  final String reviewSummary;
  final String? phone;
  final String? placeUrl;
  final String? reviewId;
  final String? reviewUrl;
  final String? reviewTitle;
  final String? reviewDescription;
  final String? addressName;
  final String? roadAddressName;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final bool isBookmarked;
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? bookmarkedAt;
  final DateTime? visitedAt;
  final List<String> bookmarkTopicIds;
  final String? bookmarkColorKey;

  const RestaurantModel({
    required this.id,
    this.storeId,
    required this.name,
    required this.address,
    required this.category,
    this.categoryName,
    this.categoryGroupCode,
    this.categoryGroupName,
    required this.truthScore,
    this.distance = 0,
    required this.reviewSummary,
    this.phone,
    this.placeUrl,
    this.reviewId,
    this.reviewUrl,
    this.reviewTitle,
    this.reviewDescription,
    this.addressName,
    this.roadAddressName,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.isBookmarked = false,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.bookmarkedAt,
    this.visitedAt,
    this.bookmarkTopicIds = const [],
    this.bookmarkColorKey,
  });

  String get effectiveStoreId {
    final normalizedStoreId = storeId?.trim();
    if (normalizedStoreId != null && normalizedStoreId.isNotEmpty) {
      return normalizedStoreId;
    }
    return id;
  }

  String get effectiveReviewId {
    final normalizedReviewId = reviewId?.trim();
    if (normalizedReviewId != null && normalizedReviewId.isNotEmpty) {
      return normalizedReviewId;
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': effectiveStoreId,
      'name': name,
      'address': address,
      'category': category,
      'categoryName': categoryName,
      'categoryGroupCode': categoryGroupCode,
      'categoryGroupName': categoryGroupName,
      'truthScore': truthScore,
      'distance': distance,
      'reviewSummary': reviewSummary,
      'phone': phone,
      'placeUrl': placeUrl,
      'reviewId': reviewId,
      'reviewUrl': reviewUrl,
      'reviewTitle': reviewTitle,
      'reviewDescription': reviewDescription,
      'addressName': addressName,
      'roadAddressName': roadAddressName,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'isBookmarked': isBookmarked,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'bookmarkedAt': bookmarkedAt?.toIso8601String(),
      'visitedAt': visitedAt?.toIso8601String(),
      'bookmarkTopicIds': bookmarkTopicIds,
      'bookmarkColorKey': bookmarkColorKey,
    };
  }

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    return RestaurantModel(
      id: (json['id'] ?? json['placeId'] ?? '').toString(),
      storeId:
          (json['storeId'] ?? json['store_id'] ?? json['placeId'])?.toString(),
      name: (json['name'] ?? json['placeName'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      category: (json['category'] ?? '음식점').toString(),
      categoryName: (json['categoryName'] ?? json['category_name'])?.toString(),
      categoryGroupCode:
          (json['categoryGroupCode'] ?? json['category_group_code'])
              ?.toString(),
      categoryGroupName:
          (json['categoryGroupName'] ?? json['category_group_name'])
              ?.toString(),
      truthScore:
          _asInt(json['truthScore'] ?? json['truth_score'], fallback: 0),
      distance: _asInt(json['distance'], fallback: 0),
      reviewSummary:
          (json['reviewSummary'] ?? json['review_summary'] ?? '').toString(),
      phone: json['phone']?.toString(),
      placeUrl:
          (json['placeUrl'] ?? json['link'] ?? json['place_url'])?.toString(),
      reviewId: (json['reviewId'] ?? json['review_id'])?.toString(),
      reviewUrl: (json['reviewUrl'] ?? json['review_url'])?.toString(),
      reviewTitle: (json['reviewTitle'] ?? json['review_title'])?.toString(),
      reviewDescription:
          (json['reviewDescription'] ?? json['review_description'])?.toString(),
      addressName: (json['addressName'] ?? json['address_name'])?.toString(),
      roadAddressName:
          (json['roadAddressName'] ?? json['road_address_name'])?.toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? json['thumbnailUrl'])
          ?.toString(),
      latitude: _asDouble(json['latitude'] ?? json['lat'], fallback: 0),
      longitude: _asDouble(json['longitude'] ?? json['lng'], fallback: 0),
      isBookmarked:
          json['isBookmarked'] == true || json['is_bookmarked'] == true,
      userId: (json['userId'] ?? json['user_id'])?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      bookmarkedAt: _parseDate(json['bookmarkedAt'] ?? json['bookmarked_at']),
      visitedAt: _parseDate(json['visitedAt'] ?? json['visited_at']),
      bookmarkTopicIds: _asStringList(
        json['bookmarkTopicIds'] ??
            json['bookmark_topic_ids'] ??
            json['bookmarkTopics'] ??
            json['bookmark_topics'],
      ),
      bookmarkColorKey:
          (json['bookmarkColorKey'] ?? json['bookmark_color_key'])?.toString(),
    );
  }

  RestaurantModel copyWith({
    String? storeId,
    String? categoryName,
    String? categoryGroupCode,
    String? categoryGroupName,
    String? addressName,
    String? roadAddressName,
    bool? isBookmarked,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? bookmarkedAt,
    DateTime? visitedAt,
    int? truthScore,
    String? reviewSummary,
    String? reviewId,
    String? reviewUrl,
    String? reviewTitle,
    String? reviewDescription,
    List<String>? bookmarkTopicIds,
    String? bookmarkColorKey,
  }) {
    return RestaurantModel(
      id: id,
      storeId: storeId ?? this.storeId,
      name: name,
      address: address,
      category: category,
      categoryName: categoryName ?? this.categoryName,
      categoryGroupCode: categoryGroupCode ?? this.categoryGroupCode,
      categoryGroupName: categoryGroupName ?? this.categoryGroupName,
      truthScore: truthScore ?? this.truthScore,
      distance: distance,
      reviewSummary: reviewSummary ?? this.reviewSummary,
      phone: phone,
      placeUrl: placeUrl,
      reviewId: reviewId ?? this.reviewId,
      reviewUrl: reviewUrl ?? this.reviewUrl,
      reviewTitle: reviewTitle ?? this.reviewTitle,
      reviewDescription: reviewDescription ?? this.reviewDescription,
      addressName: addressName ?? this.addressName,
      roadAddressName: roadAddressName ?? this.roadAddressName,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookmarkedAt: bookmarkedAt ?? this.bookmarkedAt,
      visitedAt: visitedAt ?? this.visitedAt,
      bookmarkTopicIds: bookmarkTopicIds ?? this.bookmarkTopicIds,
      bookmarkColorKey: bookmarkColorKey ?? this.bookmarkColorKey,
    );
  }

  RestaurantModel applyBookmarkMetadataFrom(RestaurantModel bookmark) {
    return copyWith(
      isBookmarked: true,
      bookmarkedAt: bookmark.bookmarkedAt ?? bookmarkedAt,
      bookmarkTopicIds: bookmark.bookmarkTopicIds,
      bookmarkColorKey: bookmark.bookmarkColorKey,
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

  static List<String> _asStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  MarkerType get markerType {
    if (truthScore >= 80) return MarkerType.high;
    if (truthScore >= 70) return MarkerType.mid;
    return MarkerType.low;
  }

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
