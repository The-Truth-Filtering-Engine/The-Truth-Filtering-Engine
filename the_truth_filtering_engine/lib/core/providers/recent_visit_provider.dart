import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/1-1_map/models/restaurant_model.dart';

/// 최근 본 식당 목록 (로컬 SharedPreferences, 최대 30개)
final recentVisitProvider =
    StateNotifierProvider<RecentVisitNotifier, List<RestaurantModel>>(
  (ref) => RecentVisitNotifier(),
);

class RecentVisitNotifier extends StateNotifier<List<RestaurantModel>> {
  static const _key = 'recent_visited_restaurants';
  static const _maxCount = 30;

  RecentVisitNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    state = raw
        .map((e) {
          try {
            return RestaurantModel.fromJson(
                jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<RestaurantModel>()
        .toList();
  }

  /// 식당 상세 진입 시 호출
  Future<void> add(RestaurantModel restaurant) async {
    final storeId = restaurant.effectiveStoreId;
    if (storeId.isEmpty) return;

    // 중복 제거 후 맨 앞에 삽입
    final updated = [
      restaurant,
      ...state.where((r) => r.effectiveStoreId != storeId),
    ].take(_maxCount).toList();

    state = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      updated.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<void> remove(String storeId) async {
    state = state.where((r) => r.effectiveStoreId != storeId).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      state.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
