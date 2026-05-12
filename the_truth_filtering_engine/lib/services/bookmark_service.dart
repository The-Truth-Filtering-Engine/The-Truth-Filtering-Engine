import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/backend_config.dart';
import '../core/config/supabase_config.dart';
import '../features/1-1_map/models/restaurant_model.dart';

class BookmarkService {
  static const _storageKey = 'bookmarked_restaurants';

  Future<List<RestaurantModel>> loadBookmarks() async {
    final localItems = await _loadLocal();
    final remoteItems = await _loadRemote();
    if (remoteItems == null) return localItems;

    final merged = _mergeBookmarks(remoteItems, localItems);
    await _saveLocal(merged);
    await _backfillRemote(localItems: localItems, remoteItems: remoteItems);
    return merged;
  }

  Future<List<RestaurantModel>> toggleBookmark(
    RestaurantModel restaurant,
  ) async {
    final storeId = restaurant.effectiveStoreId;
    if (storeId.isEmpty) return loadBookmarks();

    final now = DateTime.now();
    final bookmarkedRestaurant = restaurant.copyWith(
      bookmarkedAt: restaurant.bookmarkedAt ?? now,
      updatedAt: now,
    );
    final current = await _loadLocal();
    final index = current.indexWhere(
      (item) => item.effectiveStoreId == storeId,
    );
    final next = index >= 0
        ? [
            ...current.sublist(0, index),
            ...current.sublist(index + 1),
          ]
        : [...current, bookmarkedRestaurant];

    await _saveLocal(next);

    if (index >= 0) {
      await _syncRemoteRemove(storeId);
    } else {
      await _syncRemoteAdd(bookmarkedRestaurant);
    }

    return next;
  }

  Future<List<RestaurantModel>> removeBookmark(
    RestaurantModel restaurant,
  ) async {
    return removeBookmarkById(restaurant.effectiveStoreId);
  }

  Future<List<RestaurantModel>> removeBookmarkById(String storeId) async {
    final normalizedStoreId = storeId.trim();
    if (normalizedStoreId.isEmpty) return loadBookmarks();

    final next = (await _loadLocal())
        .where((item) => item.effectiveStoreId != normalizedStoreId)
        .toList();
    await _saveLocal(next);
    await _syncRemoteRemove(normalizedStoreId);
    return next;
  }

  Future<List<RestaurantModel>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((item) => RestaurantModel.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((restaurant) => restaurant.effectiveStoreId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocal(List<RestaurantModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  String? get _accessToken {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  Future<List<RestaurantModel>?> _loadRemote() async {
    final token = _accessToken;
    if (token == null) return null;

    try {
      final response = await http.get(
        BackendConfig.apiUri('/user/me/bookmarks'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const [];

      final bookmark = decoded['bookmark'];
      if (bookmark is! Map) return const [];

      final values = bookmark.values
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
        ..sort((a, b) {
          final aDate = a['updatedAt']?.toString() ?? '';
          final bDate = b['updatedAt']?.toString() ?? '';
          return bDate.compareTo(aDate);
        });

      return values
          .map(RestaurantModel.fromJson)
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
      await http.post(
        BackendConfig.apiUri('/user/me/bookmarks'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'storeId': restaurant.effectiveStoreId,
          'store': restaurant.toJson(),
        }),
      );
    } catch (_) {}
  }

  Future<void> _syncRemoteRemove(String storeId) async {
    final token = _accessToken;
    if (token == null) return;

    try {
      await http.delete(
        BackendConfig.apiUri(
          '/user/me/bookmarks/${Uri.encodeComponent(storeId)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  Future<void> _backfillRemote({
    required List<RestaurantModel> localItems,
    required List<RestaurantModel> remoteItems,
  }) async {
    final remoteIds = remoteItems
        .map((restaurant) => restaurant.effectiveStoreId)
        .where((storeId) => storeId.isNotEmpty)
        .toSet();

    for (final restaurant in localItems) {
      final storeId = restaurant.effectiveStoreId;
      if (storeId.isEmpty || remoteIds.contains(storeId)) continue;
      await _syncRemoteAdd(restaurant);
    }
  }

  List<RestaurantModel> _mergeBookmarks(
    List<RestaurantModel> remoteItems,
    List<RestaurantModel> localItems,
  ) {
    final seen = <String>{};
    final merged = <RestaurantModel>[];

    for (final restaurant in [...remoteItems, ...localItems]) {
      final storeId = restaurant.effectiveStoreId;
      if (storeId.isEmpty || !seen.add(storeId)) continue;
      merged.add(restaurant);
    }

    return merged;
  }
}
