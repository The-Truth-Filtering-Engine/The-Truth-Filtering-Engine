import 'package:flutter/material.dart';

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

  // ── Marker 타입 ──
  MarkerType get markerType {
    if (truthScore >= 80) return MarkerType.high;
    if (truthScore >= 70) return MarkerType.mid;
    return MarkerType.low;
  }

  // ── 카테고리 1차 분류 파싱 ──
  // "음식점 > 한식 > 해장국" → "한식"
  // "음식점 > 한식"          → "한식"
  // "한식"                   → "한식"
  String get primaryCategory {
    final parts = category.split(' > ');
    if (parts.length >= 2) return parts[1].trim();
    return category.trim();
  }

  // ── 1차 분류 → 로컬 에셋 경로 ──
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

  // 썸네일용 (정사각형)
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

class RestaurantDummyData {
  static const List<RestaurantModel> restaurants = [
    RestaurantModel(
      id: '1',
      name: '더미 가게 1',
      address: '서울시 강남구 더미거리',
      category: '음식점 > 한식', // ← 카카오 원본 형태로 수정
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
      category: '음식점 > 한식', // ← 카카오 원본 형태로 수정
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
      category: '음식점 > 양식', // ← 카카오 원본 형태로 수정
      truthScore: 74,
      distance: 0,
      reviewSummary: '분위기 좋은 곳이지만 혼잡할 수 있습니다.',
      imageUrl: null,
      latitude: 37.5800,
      longitude: 126.9800,
    ),
  ];
}
