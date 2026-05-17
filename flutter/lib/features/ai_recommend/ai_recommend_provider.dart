import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';
import '../map/models/map_point.dart';
import '../map/map_provider.dart';
import 'ai_recommend_item.dart';

enum AiRegionScope {
  si('si', '시'),
  gu('gu', '구'),
  dong('dong', '동');

  final String queryValue;
  final String fallbackLabel;

  const AiRegionScope(this.queryValue, this.fallbackLabel);
}

enum AiPriceRange {
  any('any', '가격대 전체'),
  value('value', '가성비'),
  under10000('under_10000', '1만원 이하'),
  between10000And20000('10000_20000', '1~2만원'),
  between20000And40000('20000_40000', '2~4만원'),
  specialDay('special_day', '특별한 날');

  final String queryValue;
  final String label;

  const AiPriceRange(this.queryValue, this.label);
}

enum AiPartySize {
  any('any', '인원 구성 전체'),
  solo('solo', '혼자'),
  two('two', '2명'),
  smallGroup('small_group', '3~4명'),
  group('group', '단체'),
  parents('parents', '부모님'),
  family('family', '아이/가족');

  final String queryValue;
  final String label;

  const AiPartySize(this.queryValue, this.label);
}

enum AiTransportMode {
  any('any', '이동 수단 전체'),
  walk('walk', '도보'),
  transit('transit', '대중교통'),
  parking('parking', '주차 가능'),
  publicParking('public_parking', '공영주차장 주변');

  final String queryValue;
  final String label;

  const AiTransportMode(this.queryValue, this.label);
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
  final AiPriceRange priceRange;
  final AiPartySize partySize;
  final AiTransportMode transportMode;
  final MapPoint? planningLocation;
  final String planningLocationQuery;
  final String planningLocationLabel;

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
    this.priceRange = AiPriceRange.any,
    this.partySize = AiPartySize.any,
    this.transportMode = AiTransportMode.any,
    this.planningLocation,
    this.planningLocationQuery = '',
    this.planningLocationLabel = '',
  });

  bool get hasPlanningLocation =>
      planningLocation != null || planningLocationQuery.trim().isNotEmpty;

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
    AiPriceRange? priceRange,
    AiPartySize? partySize,
    AiTransportMode? transportMode,
    MapPoint? planningLocation,
    String? planningLocationQuery,
    String? planningLocationLabel,
    bool clearPlanningCoordinates = false,
    bool clearPlanningLocation = false,
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
      priceRange: priceRange ?? this.priceRange,
      partySize: partySize ?? this.partySize,
      transportMode: transportMode ?? this.transportMode,
      planningLocation: clearPlanningLocation || clearPlanningCoordinates
          ? null
          : planningLocation ?? this.planningLocation,
      planningLocationQuery: clearPlanningLocation
          ? ''
          : planningLocationQuery ?? this.planningLocationQuery,
      planningLocationLabel: clearPlanningLocation
          ? ''
          : planningLocationLabel ?? this.planningLocationLabel,
    );
  }
}

final aiRecommendProvider =
    StateNotifierProvider.autoDispose<AiRecommendNotifier, AiRecommendState>(
        (ref) {
  return AiRecommendNotifier(ref)..loadPage(1);
});

final aiRecommendMapPickModeProvider = StateProvider<bool>((ref) => false);

class AiRecommendNotifier extends StateNotifier<AiRecommendState> {
  final Ref _ref;
  int _requestId = 0;

  AiRecommendNotifier(this._ref)
      : super(const AiRecommendState(isLoading: true));

  static const _pageSize = 10;

  Future<void> refresh() => loadPage(1);

  Future<void> reloadForCurrentLocation() {
    if (state.hasPlanningLocation) return Future.value();
    return loadPage(1);
  }

  Future<void> changeRegionScope(AiRegionScope regionScope) {
    return loadPage(1, regionScope: regionScope);
  }

  Future<void> changePriceRange(AiPriceRange priceRange) {
    return loadPage(1, priceRange: priceRange);
  }

  Future<void> changePartySize(AiPartySize partySize) {
    return loadPage(1, partySize: partySize);
  }

  Future<void> changeTransportMode(AiTransportMode transportMode) {
    return loadPage(1, transportMode: transportMode);
  }

  Future<void> changePlanningLocationQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return useCurrentLocation();
    return loadPage(
      1,
      planningLocationQuery: trimmed,
      planningLocationLabel: trimmed,
      clearPlanningCoordinates: true,
    );
  }

  Future<void> changePlanningLocationFromMap(MapPoint location) {
    return loadPage(
      1,
      planningLocation: location,
      planningLocationQuery: '',
      planningLocationLabel: '지도에서 선택한 위치',
    );
  }

  Future<void> useCurrentLocation() {
    return loadPage(1, clearPlanningLocation: true);
  }

  Future<void> loadNextPage() {
    if (!state.hasNext || state.isLoading) return Future.value();
    return loadPage(state.page + 1);
  }

  Future<void> loadPreviousPage() {
    if (state.page <= 1 || state.isLoading) return Future.value();
    return loadPage(state.page - 1);
  }

  Future<void> loadPage(
    int page, {
    AiRegionScope? regionScope,
    AiPriceRange? priceRange,
    AiPartySize? partySize,
    AiTransportMode? transportMode,
    MapPoint? planningLocation,
    String? planningLocationQuery,
    String? planningLocationLabel,
    bool clearPlanningCoordinates = false,
    bool clearPlanningLocation = false,
  }) async {
    final nextRegionScope = regionScope ?? state.regionScope;
    final nextPriceRange = priceRange ?? state.priceRange;
    final nextPartySize = partySize ?? state.partySize;
    final nextTransportMode = transportMode ?? state.transportMode;
    final nextPlanningLocation =
        clearPlanningLocation || clearPlanningCoordinates
            ? null
            : planningLocation ?? state.planningLocation;
    final nextPlanningLocationQuery = clearPlanningLocation
        ? ''
        : planningLocationQuery ?? state.planningLocationQuery;
    final nextPlanningLocationLabel = clearPlanningLocation
        ? ''
        : planningLocationLabel ?? state.planningLocationLabel;
    final requestId = ++_requestId;
    state = state.copyWith(
      page: page,
      regionScope: nextRegionScope,
      priceRange: nextPriceRange,
      partySize: nextPartySize,
      transportMode: nextTransportMode,
      planningLocation: nextPlanningLocation,
      planningLocationQuery: nextPlanningLocationQuery,
      planningLocationLabel: nextPlanningLocationLabel,
      clearPlanningCoordinates: clearPlanningCoordinates,
      clearPlanningLocation: clearPlanningLocation,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _fetchPage(
        page,
        nextRegionScope,
        priceRange: nextPriceRange,
        partySize: nextPartySize,
        transportMode: nextTransportMode,
        planningLocation: nextPlanningLocation,
        planningLocationQuery: nextPlanningLocationQuery,
      );
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
        priceRange: nextPriceRange,
        partySize: nextPartySize,
        transportMode: nextTransportMode,
        planningLocation: nextPlanningLocation,
        planningLocationQuery: nextPlanningLocationQuery,
        planningLocationLabel: nextPlanningLocationLabel,
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
    AiRegionScope regionScope, {
    required AiPriceRange priceRange,
    required AiPartySize partySize,
    required AiTransportMode transportMode,
    required MapPoint? planningLocation,
    required String planningLocationQuery,
  }) async {
    final currentLocation = _ref.read(currentLocationProvider);
    final requestLocation = planningLocation ?? currentLocation;
    final queryParameters = {
      'threshold': '0.1',
      'page': page.toString(),
      'pageSize': _pageSize.toString(),
      'regionScope': regionScope.queryValue,
      'priceRange': priceRange.queryValue,
      'partySize': partySize.queryValue,
      'transportMode': transportMode.queryValue,
    };
    if (requestLocation != null) {
      queryParameters['lat'] = requestLocation.latitude.toString();
      queryParameters['lng'] = requestLocation.longitude.toString();
    } else if (planningLocationQuery.trim().isNotEmpty) {
      queryParameters['locationQuery'] = planningLocationQuery.trim();
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
