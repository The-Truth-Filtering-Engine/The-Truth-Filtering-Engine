class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String category;
  final int truthScore;
  final String reviewSummary;
  final String? imageUrl;
  final double latitude;
  final double longitude;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.truthScore,
    required this.reviewSummary,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
  });

  /// 점수에 따른 마커 타입 분류
  MarkerType get markerType {
    if (truthScore >= 80) return MarkerType.high;
    if (truthScore >= 70) return MarkerType.mid;
    return MarkerType.low;
  }
}

enum MarkerType { high, mid, low }

/// 더미 데이터
class RestaurantDummyData {
  static const List<RestaurantModel> restaurants = [
    RestaurantModel(
      id: '1',
      name: '청담 스시 겐',
      address: '강남구 청담동',
      category: '일식',
      truthScore: 92,
      reviewSummary: '광고 없는 진짜 숙성회',
      imageUrl: null,
      latitude: 37.5245,
      longitude: 127.0440,
    ),
    RestaurantModel(
      id: '2',
      name: '압구정 라멘 타나카',
      address: '강남구 압구정동',
      category: '일식',
      truthScore: 98,
      reviewSummary: '현지인도 줄 서는 진짜 라멘',
      imageUrl: null,
      latitude: 37.5270,
      longitude: 127.0290,
    ),
    RestaurantModel(
      id: '3',
      name: '삼청동 파스타',
      address: '종로구 삼청동',
      category: '양식',
      truthScore: 74,
      reviewSummary: '뷰 좋고 맛도 평균 이상',
      imageUrl: null,
      latitude: 37.5800,
      longitude: 126.9800,
    ),
  ];
}
