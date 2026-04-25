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

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.truthScore,
    this.distance = 0,
    this.phone,
    this.placeUrl,
    required this.reviewSummary,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
  });

  MarkerType get markerType {
    if (truthScore >= 80) return MarkerType.high;
    if (truthScore >= 70) return MarkerType.mid;
    return MarkerType.low;
  }
}

enum MarkerType { high, mid, low }

class RestaurantDummyData {
  static const List<RestaurantModel> restaurants = [
    RestaurantModel(
      id: '1',
      name: '더미 가게 1',
      address: '서울시 강남구 더미거리',
      category: '한식',
      truthScore: 92,
      distance: 0,
      reviewSummary: '안전하고 깔끔한 식당입니다.',
      imageUrl: null,
      latitude: 37.5245,
      longitude: 127.0440,
    ),
    RestaurantModel(
      id: '2',
      name: '더미 가게 2',
      address: '서울시 강남구 가로수길',
      category: '한식',
      truthScore: 98,
      distance: 0,
      reviewSummary: '직원 응대가 좋고 맛이 훌륭합니다.',
      imageUrl: null,
      latitude: 37.5270,
      longitude: 127.0290,
    ),
    RestaurantModel(
      id: '3',
      name: '더미 가게 3',
      address: '서울시 용산구 이태원로',
      category: '양식',
      truthScore: 74,
      distance: 0,
      reviewSummary: '분위기 좋은 곳이지만 혼잡할 수 있습니다.',
      imageUrl: null,
      latitude: 37.5800,
      longitude: 126.9800,
    ),
  ];
}
