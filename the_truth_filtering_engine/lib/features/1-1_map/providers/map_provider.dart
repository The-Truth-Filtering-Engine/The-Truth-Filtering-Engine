import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  void toggle(RestaurantModel restaurant) {
    final index = state.indexWhere((item) => item.id == restaurant.id);
    if (index >= 0) {
      state = [
        ...state.sublist(0, index),
        ...state.sublist(index + 1),
      ];
      _save();
      return;
    }

    state = [...state, restaurant];
    _save();
  }

  void remove(RestaurantModel restaurant) {
    state = state.where((item) => item.id != restaurant.id).toList();
    _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      state = decoded
          .whereType<Map>()
          .map((item) => RestaurantModel.fromJson(
                item.cast<String, dynamic>(),
              ))
          .where((restaurant) => restaurant.id.isNotEmpty)
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        state.map((restaurant) => restaurant.toJson()).toList(),
      );
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }
}

// 지도 레이어 표시 여부
final showLayerMenuProvider = StateProvider<bool>((ref) => false);

// 지도 화면에서 획득한 현재 위치
final currentLocationProvider = StateProvider<MapPoint?>((ref) => null);
