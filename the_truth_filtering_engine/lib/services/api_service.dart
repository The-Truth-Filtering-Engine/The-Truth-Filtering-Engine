import 'package:dio/dio.dart';
import '../core/config/backend_config.dart';
import '../models/search_result.dart';
import '../models/ai_recommend_item.dart';
import '../models/blog_review_model.dart';
import '../features/1-1_map/models/map_point.dart';
import '../features/1-1_map/models/restaurant_model.dart';

class ApiService {
  final _dio = Dio(BaseOptions(
    baseUrl: BackendConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  // ?�?� 검??API ?�?�
  Future<SearchResult> search(String query) async {
    final res = await _dio.get('/api/search', queryParameters: {'query': query});
    return SearchResult.fromJson(res.data);
  }

  // ?�?� 주�? ?�식??조회 API ?�?�
  Future<List<RestaurantModel>> fetchNearbyRestaurants({
    required MapPoint center,
    required int radius,
    int display = 30,
  }) async {
    final res = await _dio.get('/places/nearby-restaurants', queryParameters: {
      'lat': center.latitude.toString(),
      'lng': center.longitude.toString(),
      'radius': radius.toString(),
      'display': display.toString(),
    });

    final restaurants = res.data['restaurants'];
    if (restaurants is! List) return [];

    return restaurants
        .whereType<Map<String, dynamic>>()
        .map(RestaurantModel.fromJson)
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }

  // ?�?� 캐시??리뷰 조회 ?�?�
  Future<List<BlogReviewModel>> fetchCachedReviews(String query) async {
    final res = await _dio.get('/api/search/cached', queryParameters: {'query': query});
    return _parseReviews(res.data);
  }

  // ?�?� ?�규 리뷰 분석 ?�청 ?�?�
  Future<List<BlogReviewModel>> fetchFreshReviews(String query) async {
    final res = await _dio.get('/api/search', queryParameters: {'query': query, 'mode': 'model'});
    return _parseReviews(res.data);
  }

  // ?�?� AI 추천 API ?�?�
  Future<AiRecommendationResponse> fetchAiRecommendations({
    required int page,
    required String regionScope,
    MapPoint? currentPosition,
  }) async {
    final res = await _dio.get('/api/ai-recommendations', queryParameters: {
      'threshold': '0.1',
      'page': page,
      'pageSize': 10,
      'regionScope': regionScope,
      if (currentPosition != null) 'lat': currentPosition.latitude,
      if (currentPosition != null) 'lng': currentPosition.longitude,
    });

    final data = res.data;
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(AiRecommendItem.fromJson)
            .where((item) => item.id != 0)
            .toList()
        : <AiRecommendItem>[];

    return AiRecommendationResponse(
      items: items,
      page: int.tryParse((data['page'] ?? page).toString()) ?? page,
      hasNext: data['hasNext'] == true,
      regionLabel: (data['regionLabel'] ?? '').toString(),
      currentRegionLabel: data['currentRegion'] is Map ? (data['currentRegion']['label'] ?? '').toString() : '',
      isRegionFiltered: data['isRegionFiltered'] == true,
    );
  }

  List<BlogReviewModel> _parseReviews(dynamic data) {
    final rawReviews = data['reviews'];
    if (rawReviews is! List) return [];
    return rawReviews.whereType<Map<String, dynamic>>().map(BlogReviewModel.fromJson).toList();
  }
}

class AiRecommendationResponse {
  final List<AiRecommendItem> items;
  final int page;
  final bool hasNext;
  final String regionLabel;
  final String currentRegionLabel;
  final bool isRegionFiltered;

  const AiRecommendationResponse({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.regionLabel,
    required this.currentRegionLabel,
    required this.isRegionFiltered,
  });
}


