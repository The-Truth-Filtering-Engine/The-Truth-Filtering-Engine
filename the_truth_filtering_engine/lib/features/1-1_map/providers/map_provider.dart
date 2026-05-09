import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/config/supabase_config.dart';
import '../models/map_point.dart';
import '../models/restaurant_model.dart';

// 레스토랑 목록 provider (더미 데이터)
final restaurantListProvider = Provider<List<RestaurantModel>>((ref) {
  return RestaurantDummyData.restaurants;
});

// 선택된 레스토랑 provider (바텀시트 표시용)
final selectedRestaurantProvider =
    StateProvider<RestaurantModel?>((ref) => null);

// 외부 화면에서 지도 탭으로 이동시키며 특정 식당에 포커스할 때 사용
final mapFocusRestaurantProvider =
    StateProvider<RestaurantModel?>((ref) => null);

// 북마크 목록
final bookmarkRestaurantsProvider =
    StateNotifierProvider<BookmarkRestaurantsNotifier, List<RestaurantModel>>(
  (ref) => BookmarkRestaurantsNotifier(),
);

// 북마크 추가/삭제
class BookmarkRestaurantsNotifier extends StateNotifier<List<RestaurantModel>> {
  static const _storageKey = 'bookmarked_restaurants';

  BookmarkRestaurantsNotifier() : super(const []) {
    _load();
  }

  Future<void> toggle(RestaurantModel restaurant) async {
    final storeId = restaurant.effectiveStoreId;
    if (storeId.isEmpty) return;

    final previous = state;
    final index = state.indexWhere(
      (item) => item.effectiveStoreId == storeId,
    );

    if (index >= 0) {
      state = [
        ...state.sublist(0, index),
        ...state.sublist(index + 1),
      ];
      await _persistAfterChange(previous, storeId: storeId, remove: true);
      return;
    }

    state = [
      ...state.where((item) => item.effectiveStoreId != storeId),
      restaurant,
    ];
    await _persistAfterChange(previous, restaurant: restaurant);
  }

  Future<void> remove(RestaurantModel restaurant) async {
    final storeId = restaurant.effectiveStoreId;
    if (storeId.isEmpty) return;

    final previous = state;
    state = state
        .where((item) => item.effectiveStoreId != storeId)
        .toList(growable: false);
    await _persistAfterChange(previous, storeId: storeId, remove: true);
  }

  Future<void> _load() async {
    final token = _currentAccessToken;
    if (token != null) {
      try {
        var remoteBookmarks = await _fetchRemoteBookmarks(token);
        final localBookmarks = await _readLocalBookmarks();

        if (localBookmarks.isNotEmpty) {
          for (final restaurant in localBookmarks) {
            final storeId = restaurant.effectiveStoreId;
            final alreadyRemote = remoteBookmarks.any(
              (item) => item.effectiveStoreId == storeId,
            );
            if (storeId.isEmpty || alreadyRemote) continue;
            remoteBookmarks = await _addRemoteBookmark(token, restaurant);
          }
          await _clearLocalBookmarks();
        }

        state = remoteBookmarks;
        return;
      } catch (_) {
        // 서버 동기화가 실패하면 기존 로컬 북마크로 앱 사용을 유지한다.
      }
    }

    state = await _readLocalBookmarks();
  }

  Future<void> _persistAfterChange(
    List<RestaurantModel> previous, {
    RestaurantModel? restaurant,
    String? storeId,
    bool remove = false,
  }) async {
    final token = _currentAccessToken;
    if (token == null) {
      await _saveLocalBookmarks();
      return;
    }

    try {
      final next = remove
          ? await _deleteRemoteBookmark(token, storeId ?? '')
          : await _addRemoteBookmark(token, restaurant!);
      state = next;
    } catch (_) {
      state = previous;
    }
  }

  String? get _currentAccessToken {
    if (!SupabaseConfig.isConfigured) return null;

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<List<RestaurantModel>> _readLocalBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return _dedupeRestaurants(
        decoded
            .whereType<Map>()
            .map((item) => RestaurantModel.fromJson(
                  item.cast<String, dynamic>(),
                ))
            .where((restaurant) => restaurant.id.isNotEmpty)
            .toList(),
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocalBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        state.map((restaurant) => restaurant.toJson()).toList(),
      );
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<void> _clearLocalBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  Future<List<RestaurantModel>> _fetchRemoteBookmarks(String token) async {
    final response = await http.get(
      BackendConfig.apiUri('/user/me/bookmarks'),
      headers: _authHeaders(token),
    );

    if (!_isSuccessful(response.statusCode)) {
      throw StateError('bookmark fetch failed: ${response.statusCode}');
    }

    return _parseRemoteBookmarks(response.body);
  }

  Future<List<RestaurantModel>> _addRemoteBookmark(
    String token,
    RestaurantModel restaurant,
  ) async {
    final response = await http.post(
      BackendConfig.apiUri('/user/me/bookmarks'),
      headers: {
        ..._authHeaders(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'storeId': restaurant.effectiveStoreId,
        'store': _bookmarkStoreJson(restaurant),
      }),
    );

    if (!_isSuccessful(response.statusCode)) {
      throw StateError('bookmark add failed: ${response.statusCode}');
    }

    return _parseRemoteBookmarks(response.body);
  }

  Future<List<RestaurantModel>> _deleteRemoteBookmark(
    String token,
    String storeId,
  ) async {
    final response = await http.delete(
      BackendConfig.apiUri(
          '/user/me/bookmarks/${Uri.encodeComponent(storeId)}'),
      headers: _authHeaders(token),
    );

    if (!_isSuccessful(response.statusCode)) {
      throw StateError('bookmark delete failed: ${response.statusCode}');
    }

    return _parseRemoteBookmarks(response.body);
  }

  Map<String, String> _authHeaders(String token) {
    return {'Authorization': 'Bearer $token'};
  }

  bool _isSuccessful(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  List<RestaurantModel> _parseRemoteBookmarks(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];

    final bookmarkMap = decoded['bookmark'];
    if (bookmarkMap is! Map) return const [];

    final restaurants = <RestaurantModel>[];
    for (final entry in bookmarkMap.entries) {
      final storeId = entry.key?.toString().trim() ?? '';
      final rawStore = entry.value;
      if (storeId.isEmpty || rawStore is! Map) continue;

      final storeJson = _stringKeyedMap(rawStore);
      storeJson['id'] = storeId;
      storeJson['storeId'] = storeId;
      storeJson['latitude'] = storeJson['latitude'] ?? storeJson['lat'];
      storeJson['longitude'] = storeJson['longitude'] ?? storeJson['lng'];

      final restaurant = RestaurantModel.fromJson(storeJson);
      if (restaurant.effectiveStoreId.isEmpty || restaurant.name.isEmpty) {
        continue;
      }
      restaurants.add(restaurant);
    }

    return _dedupeRestaurants(restaurants);
  }

  Map<String, dynamic> _stringKeyedMap(Map value) {
    return value.map(
      (key, dynamic item) => MapEntry(key.toString(), item),
    );
  }

  Map<String, dynamic> _bookmarkStoreJson(RestaurantModel restaurant) {
    return {
      ...restaurant.toJson(),
      'id': restaurant.effectiveStoreId,
      'storeId': restaurant.effectiveStoreId,
      'link': restaurant.placeUrl,
      'placeUrl': restaurant.placeUrl,
      'latitude': restaurant.latitude,
      'longitude': restaurant.longitude,
    };
  }

  List<RestaurantModel> _dedupeRestaurants(List<RestaurantModel> restaurants) {
    final seen = <String>{};
    final deduped = <RestaurantModel>[];

    for (final restaurant in restaurants) {
      final storeId = restaurant.effectiveStoreId;
      if (storeId.isEmpty || seen.contains(storeId)) continue;
      seen.add(storeId);
      deduped.add(restaurant);
    }

    return deduped;
  }
}

// 지도 레이어 표시 여부
final showLayerMenuProvider = StateProvider<bool>((ref) => false);

// 지도 화면에서 획득한 현재 위치
final currentLocationProvider = StateProvider<MapPoint?>((ref) => null);
