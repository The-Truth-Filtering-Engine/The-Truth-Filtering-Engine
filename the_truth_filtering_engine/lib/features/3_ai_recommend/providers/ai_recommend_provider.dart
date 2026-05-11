import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/backend_config.dart';
import '../../1-1_map/providers/map_provider.dart';
import '../models/ai_recommend_item.dart';

enum AiRegionScope {
  si('si', '시'),
  gu('gu', '구'),
  dong('dong', '동');

  final String queryValue;
  final String fallbackLabel;

  const AiRegionScope(this.queryValue, this.fallbackLabel);
}

class AiRecommendState {
  final List<AiRecommendItem> items;
  final int page;
  final bool hasNext;
  final bool isLoading;
  final String? errorMessage;
  final AiRegionScope regionScope;
  final String regionLabel;
  final String currentRegionSi;
  final String currentRegionGu;
  final String currentRegionDong;
  final String currentRegionLabel;
  final bool isRegionFiltered;

  const AiRecommendState({
    this.items = const [],
    this.page = 1,
    this.hasNext = false,
    this.isLoading = false,
    this.errorMessage,
    this.regionScope = AiRegionScope.si,
    this.regionLabel = '',
    this.currentRegionSi = '',
    this.currentRegionGu = '',
    this.currentRegionDong = '',
    this.currentRegionLabel = '',
    this.isRegionFiltered = false,
  });

  AiRecommendState copyWith({
    List<AiRecommendItem>? items,
    int? page,
    bool? hasNext,
    bool? isLoading,
    String? errorMessage,
    AiRegionScope? regionScope,
    String? regionLabel,
    String? currentRegionSi,
    String? currentRegionGu,
    String? currentRegionDong,
    String? currentRegionLabel,
    bool? isRegionFiltered,
    bool clearError = false,
  }) {
    return AiRecommendState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      regionScope: regionScope ?? this.regionScope,
      regionLabel: regionLabel ?? this.regionLabel,
      currentRegionSi: currentRegionSi ?? this.currentRegionSi,
      currentRegionGu: currentRegionGu ?? this.currentRegionGu,
      currentRegionDong: currentRegionDong ?? this.currentRegionDong,
      currentRegionLabel: currentRegionLabel ?? this.currentRegionLabel,
      isRegionFiltered: isRegionFiltered ?? this.isRegionFiltered,
    );
  }
}

final aiRecommendProvider =
    StateNotifierProvider.autoDispose<AiRecommendNotifier, AiRecommendState>(
        (ref) {
  return AiRecommendNotifier(ref)..loadPage(1);
});

class AiRecommendNotifier extends StateNotifier<AiRecommendState> {
  final Ref _ref;
  int _requestId = 0;

  AiRecommendNotifier(this._ref)
      : super(const AiRecommendState(isLoading: true));

  static const _pageSize = 10;

  Future<void> refresh() => loadPage(1);

  Future<void> reloadForCurrentLocation() => loadPage(1);

  Future<void> changeRegionScope(AiRegionScope regionScope) {
    return loadPage(1, regionScope: regionScope);
  }

  Future<void> loadNextPage() {
    if (!state.hasNext || state.isLoading) return Future.value();
    return loadPage(state.page + 1);
  }

  Future<void> loadPreviousPage() {
    if (state.page <= 1 || state.isLoading) return Future.value();
    return loadPage(state.page - 1);
  }

  Future<void> loadPage(int page, {AiRegionScope? regionScope}) async {
    final nextRegionScope = regionScope ?? state.regionScope;
    final requestId = ++_requestId;
    state = state.copyWith(
      page: page,
      regionScope: nextRegionScope,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _fetchPage(page, nextRegionScope);
      if (requestId != _requestId) return;

      state = state.copyWith(
        items: result.items,
        page: result.page,
        hasNext: result.hasNext,
        isLoading: false,
        regionScope: nextRegionScope,
        regionLabel: result.regionLabel,
        currentRegionSi: result.currentRegionSi,
        currentRegionGu: result.currentRegionGu,
        currentRegionDong: result.currentRegionDong,
        currentRegionLabel: result.currentRegionLabel,
        isRegionFiltered: result.isRegionFiltered,
        clearError: true,
      );
    } catch (error) {
      if (requestId != _requestId) return;

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'AI 추천 API 오류: $error',
      );
    }
  }

  Future<_AiRecommendPage> _fetchPage(
    int page,
    AiRegionScope regionScope,
  ) async {
    final currentLocation = _ref.read(currentLocationProvider);
    final queryParameters = {
      'threshold': '0.1',
      'page': page.toString(),
      'pageSize': _pageSize.toString(),
      'regionScope': regionScope.queryValue,
    };
    if (currentLocation != null) {
      queryParameters['lat'] = currentLocation.latitude.toString();
      queryParameters['lng'] = currentLocation.longitude.toString();
    }

    final uri = BackendConfig.apiUri(
      '/ai-recommendations',
      queryParameters: queryParameters,
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('서버 응답 ${response.statusCode}');
    }

    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? [];
    final currentRegion = _asStringMap(body['currentRegion']);

    return _AiRecommendPage(
      items: items
          .whereType<Map>()
          .map((item) => AiRecommendItem.fromJson(item.cast<String, dynamic>()))
          .where((item) => item.id != 0)
          .toList(),
      page: _asInt(body['page'], fallback: page),
      hasNext: body['hasNext'] == true,
      regionLabel: _asString(body['regionLabel']),
      currentRegionSi: _asString(currentRegion['si']),
      currentRegionGu: _asString(currentRegion['gu']),
      currentRegionDong: _asString(currentRegion['dong']),
      currentRegionLabel: _asString(currentRegion['label']),
      isRegionFiltered: body['isRegionFiltered'] == true,
    );
  }
}

class _AiRecommendPage {
  final List<AiRecommendItem> items;
  final int page;
  final bool hasNext;
  final String regionLabel;
  final String currentRegionSi;
  final String currentRegionGu;
  final String currentRegionDong;
  final String currentRegionLabel;
  final bool isRegionFiltered;

  const _AiRecommendPage({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.regionLabel,
    required this.currentRegionSi,
    required this.currentRegionGu,
    required this.currentRegionDong,
    required this.currentRegionLabel,
    required this.isRegionFiltered,
  });
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(Object? value) => value?.toString().trim() ?? '';

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }
  return const {};
}
