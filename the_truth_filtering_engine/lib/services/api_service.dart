import 'package:dio/dio.dart';

import '../core/config/backend_config.dart';
import '../core/providers/analysis_mode_provider.dart';
import '../data/models/ai_recommend_item.dart';
import '../data/models/blog_review_model.dart';
import '../features/1-1_map/models/map_point.dart';
import '../features/1-1_map/models/restaurant_model.dart';
import '../models/search_result.dart';

class ApiService {
  final _dio = Dio(
    BaseOptions(
      baseUrl: BackendConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  Future<SearchResult> search(String query) async {
    final res = await _dio.get('/search', queryParameters: {'query': query});
    return SearchResult.fromJson(res.data);
  }

  Future<List<RestaurantModel>> fetchNearbyRestaurants({
    required MapPoint center,
    int radius = 1200,
  }) async {
    final res = await _dio.get(
      '/places/nearby-restaurants',
      queryParameters: {
        'lat': center.latitude.toString(),
        'lng': center.longitude.toString(),
        'radius': radius.toString(),
        'display': '10',
      },
    );

    final data = res.data;
    final items =
        data is Map ? data['restaurants'] as List? ?? const [] : const [];

    return items
        .whereType<Map>()
        .map((item) {
          final json = item.cast<String, dynamic>();
          return RestaurantModel(
            id: json['id']?.toString() ?? '',
            storeId: json['id']?.toString(),
            name: json['name']?.toString() ?? '',
            category: json['category']?.toString() ?? '음식점',
            categoryName: json['category']?.toString(),
            address: json['address']?.toString() ?? '',
            truthScore: _mockTrustScore(json['id']?.toString() ?? ''),
            distance: _asInt(json['distance'], fallback: 0),
            phone: json['phone']?.toString(),
            placeUrl: json['link']?.toString(),
            addressName: json['address']?.toString(),
            roadAddressName: json['address']?.toString(),
            reviewSummary: json['name']?.toString() ?? '검색 결과',
            imageUrl: null,
            latitude: _asDouble(json['lat'], fallback: center.latitude),
            longitude: _asDouble(json['lng'], fallback: center.longitude),
          );
        })
        .where((restaurant) => restaurant.id.isNotEmpty)
        .toList();
  }

  Future<List<BlogReviewModel>> fetchCachedReviews(String query) async {
    final res = await _dio.get(
      '/search/cached',
      queryParameters: {
        'query': query,
        'limit': '100',
      },
    );
    return _parseReviews(res.data);
  }

  Future<List<BlogReviewModel>> fetchFreshReviews(String query) async {
    final res = await _dio.get(
      '/search',
      queryParameters: {
        'query': query,
        'refresh': 'true',
        'limit': '100',
      },
    );
    return _parseReviews(res.data);
  }

  Future<AiRecommendationsResponse> fetchAiRecommendations({
    required int page,
    required String regionScope,
    MapPoint? currentPosition,
  }) async {
    final res = await _dio.get(
      '/ai-recommendations',
      queryParameters: {
        'threshold': '0.1',
        'page': page.toString(),
        'pageSize': '10',
        'regionScope': regionScope,
        if (currentPosition != null) 'lat': currentPosition.latitude.toString(),
        if (currentPosition != null)
          'lng': currentPosition.longitude.toString(),
      },
    );

    final data = res.data is Map ? res.data as Map : const {};
    final items = data['items'] as List? ?? const [];

    return AiRecommendationsResponse(
      items: items
          .whereType<Map>()
          .map((item) => AiRecommendItem.fromJson(item.cast<String, dynamic>()))
          .where((item) => item.id != 0)
          .toList(),
      page: _asInt(data['page'], fallback: page),
      hasNext: data['hasNext'] == true,
      regionLabel: data['regionLabel']?.toString() ?? '',
      currentRegionLabel: data['currentRegionLabel']?.toString() ?? '',
    );
  }

  List<BlogReviewModel> _parseReviews(Object? data) {
    final reviews =
        data is Map ? data['reviews'] as List? ?? const [] : const [];
    return reviews
        .whereType<Map>()
        .map(
          (item) => BlogReview.fromApiWithMode(
            item.cast<String, dynamic>(),
            AnalysisMode.llm,
          ),
        )
        .toList();
  }
}

class AiRecommendationsResponse {
  final List<AiRecommendItem> items;
  final int page;
  final bool hasNext;
  final String regionLabel;
  final String currentRegionLabel;

  const AiRecommendationsResponse({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.regionLabel,
    required this.currentRegionLabel,
  });
}

int _mockTrustScore(String id) {
  final hash = id.hashCode.abs() % 40;
  return 60 + hash;
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(Object? value, {required double fallback}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
