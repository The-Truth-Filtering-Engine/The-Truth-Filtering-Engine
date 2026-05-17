import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/backend_config.dart';
import '../../core/providers/current_user_provider.dart';
import '../../models/search_history_models.dart';
import '../../models/search_preview_models.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  ref.watch(appAuthProvider);
  final token = _currentAccessToken();
  return SearchRepository(accessToken: token);
});

String _currentAccessToken() {
  try {
    return Supabase.instance.client.auth.currentSession?.accessToken ?? '';
  } catch (_) {
    return '';
  }
}

class SearchRepository {
  SearchRepository({required String accessToken})
      : _dio = Dio(
          BaseOptions(
            baseUrl: BackendConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              if (accessToken.isNotEmpty)
                'Authorization': 'Bearer $accessToken',
            },
          ),
        );

  final Dio _dio;

  // BackendConfig.apiBaseUrl already includes `/api`.
  Future<List<Map<String, dynamic>>> fetchTrendingChips() async {
    final response = await _dio.get('/search/trending');
    final data = response.data;
    if (data is! Map) return const [];

    final chips = data['chips'];
    if (chips is! List) return const [];

    return chips
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<SearchPreviewResponse> fetchPreview({
    required String query,
    double? lat,
    double? lng,
  }) async {
    final params = <String, dynamic>{'query': query};
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;

    final response = await _dio.get(
      '/search/preview',
      queryParameters: params,
    );

    return SearchPreviewResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<Map<String, dynamic>>> fetchResults({
    required String query,
    double? lat,
    double? lng,
  }) async {
    final params = <String, dynamic>{'query': query};
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;

    final response = await _dio.get(
      '/search/results',
      queryParameters: params,
    );
    final data = response.data;
    if (data is! Map) return const [];

    final results = data['results'];
    if (results is! List) return const [];

    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<SearchRecentHistoryResponse> fetchRecentHistory() async {
    final response = await _dio.get('/search/recent');
    return SearchRecentHistoryResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> saveRecentHistory(
    SearchRecentHistoryRequest request,
  ) async {
    await _dio.post('/search/recent', data: request.toJson());
  }

  Future<void> deleteRecentHistoryItem(String historyId) async {
    await _dio.delete('/search/recent/$historyId');
  }

  Future<void> deleteAllRecentHistory() async {
    await _dio.delete('/search/recent');
  }
}
