import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import '../config/supabase_config.dart';
import 'current_user_provider.dart';
import '../../features/1-1_map/models/restaurant_model.dart';

/// 최근 본 식당 목록 (로컬 SharedPreferences, 최대 30개)
final recentVisitProvider =
    StateNotifierProvider<RecentVisitNotifier, List<RestaurantModel>>(
  (ref) {
    final authState = ref.watch(appAuthProvider);
    return RecentVisitNotifier(
      enableRemoteSync: authState.isLoggedIn && !authState.isAdmin,
    );
  },
);

class RecentVisitNotifier extends StateNotifier<List<RestaurantModel>> {
  static const _key = 'recent_visited_restaurants';
  static const _maxCount = 30;

  final bool enableRemoteSync;

  RecentVisitNotifier({required this.enableRemoteSync}) : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final localItems = await _loadLocal();
    state = localItems;

    final localItemsWithReviewUrls = await _withReviewUrls(localItems);
    if (_hasReviewUrlChanges(localItems, localItemsWithReviewUrls)) {
      state = localItemsWithReviewUrls;
      await _saveLocal(localItemsWithReviewUrls);
    }

    if (!enableRemoteSync) return;

    final remoteItems = await _loadRemote();
    if (remoteItems == null) return;

    final merged = await _withReviewUrls(
      _mergeRecent(remoteItems, localItemsWithReviewUrls),
    );
    state = merged;
    await _saveLocal(merged);

    for (final restaurant in localItemsWithReviewUrls) {
      if (remoteItems.any(
        (item) => item.effectiveStoreId == restaurant.effectiveStoreId,
      )) {
        continue;
      }
      await _syncRemoteAdd(restaurant);
    }
  }

  Future<List<RestaurantModel>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
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

    final now = DateTime.now();
    final visitedRestaurant = await _withReviewUrl(
      restaurant.copyWith(
        updatedAt: now,
        visitedAt: now,
      ),
    );

    // 중복 제거 후 맨 앞에 삽입
    final updated = [
      visitedRestaurant,
      ...state.where((r) => r.effectiveStoreId != storeId),
    ].take(_maxCount).toList();

    state = updated;

    await _saveLocal(updated);
    await _syncRemoteAdd(visitedRestaurant);
  }

  Future<void> remove(String storeId) async {
    state = state.where((r) => r.effectiveStoreId != storeId).toList();
    await _saveLocal(state);
    await _syncRemoteRemove(storeId);
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await _syncRemoteClear();
  }

  Future<void> _saveLocal(List<RestaurantModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<List<RestaurantModel>> _withReviewUrls(
    List<RestaurantModel> restaurants,
  ) async {
    final updated = <RestaurantModel>[];
    for (final restaurant in restaurants) {
      updated.add(await _withReviewUrl(restaurant));
    }
    return updated;
  }

  Future<RestaurantModel> _withReviewUrl(RestaurantModel restaurant) async {
    final currentReviewUrl = restaurant.reviewUrl?.trim();
    if (currentReviewUrl != null && currentReviewUrl.isNotEmpty) {
      return restaurant;
    }

    final reviewUrl = await _latestReviewUrlForStore(
      restaurant.effectiveStoreId,
    );
    if (reviewUrl == null || reviewUrl.isEmpty) return restaurant;

    return restaurant.copyWith(reviewUrl: reviewUrl);
  }

  bool _hasReviewUrlChanges(
    List<RestaurantModel> previous,
    List<RestaurantModel> next,
  ) {
    if (previous.length != next.length) return true;
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].reviewUrl != next[index].reviewUrl) return true;
    }
    return false;
  }

  String? get _accessToken {
    if (!enableRemoteSync) return null;
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  Future<List<RestaurantModel>?> _loadRemote() async {
    final token = _accessToken;
    if (token == null) return null;

    try {
      final response = await http.get(
        BackendConfig.apiUri('/user/me/recent-visits'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Recent visits load failed: ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final items = decoded is Map ? decoded['items'] : null;
      if (items is! List) return const [];

      return items
          .whereType<Map>()
          .map((item) => RestaurantModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((restaurant) => restaurant.effectiveStoreId.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncRemoteAdd(RestaurantModel restaurant) async {
    final token = _accessToken;
    if (token == null) return;

    try {
      final response = await http.post(
        BackendConfig.apiUri('/user/me/recent-visits'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'storeId': restaurant.effectiveStoreId,
          'store': restaurant.toJson(),
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('recent visit add failed: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Recent visit remote add failed: $error');
    }
  }

  Future<void> _syncRemoteRemove(String storeId) async {
    final token = _accessToken;
    if (token == null) return;

    try {
      final response = await http.delete(
        BackendConfig.apiUri(
          '/user/me/recent-visits/${Uri.encodeComponent(storeId)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('recent visit remove failed: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Recent visit remote remove failed: $error');
    }
  }

  Future<void> _syncRemoteClear() async {
    final token = _accessToken;
    if (token == null) return;

    try {
      final response = await http.delete(
        BackendConfig.apiUri('/user/me/recent-visits'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('recent visits clear failed: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Recent visits remote clear failed: $error');
    }
  }

  Future<String?> _latestReviewUrlForStore(String storeId) async {
    final normalizedStoreId = storeId.trim();
    if (!SupabaseConfig.isConfigured || normalizedStoreId.isEmpty) {
      return null;
    }

    try {
      final rows = await Supabase.instance.client
          .from('reviews')
          .select('review_url')
          .eq('store_id', normalizedStoreId)
          .order('created_at', ascending: false)
          .limit(10);

      for (final row in rows.whereType<Map>()) {
        final reviewUrl = row['review_url']?.toString().trim();
        if (reviewUrl != null && reviewUrl.isNotEmpty) {
          return reviewUrl;
        }
      }
    } catch (error) {
      debugPrint('Recent visit review_url load failed: $error');
    }

    return null;
  }

  List<RestaurantModel> _mergeRecent(
    List<RestaurantModel> remoteItems,
    List<RestaurantModel> localItems,
  ) {
    final seen = <String>{};
    final merged = <RestaurantModel>[];

    for (final restaurant in [...remoteItems, ...localItems]) {
      final storeId = restaurant.effectiveStoreId;
      if (storeId.isEmpty || !seen.add(storeId)) continue;
      merged.add(restaurant);
      if (merged.length >= _maxCount) break;
    }

    return merged;
  }
}
