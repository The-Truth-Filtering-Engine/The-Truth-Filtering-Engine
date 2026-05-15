import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/backend_config.dart';
import '../../core/config/supabase_config.dart';
import '../map/models/restaurant_model.dart';
import 'bookmark_folder.dart';
import 'bookmark_options.dart';

class BookmarkService {
  static const _storageKey = 'bookmarked_restaurants';
  static const _initialSeededKey = 'bookmarked_restaurants_initial_seeded';
  static const _defaultTopicId = BookmarkTopics.defaultTopicId;
  static const _defaultColorKey = 'sky';
  static const _defaultInitialRegion = '광교';

  Future<List<RestaurantModel>> loadBookmarks() async {
    final localItems = await _loadLocal();
    final remoteItems = await _loadRemote();
    if (remoteItems == null) {
      if (localItems.isEmpty) {
        return _loadInitialBookmarksIfNeeded();
      }
      return localItems;
    }

    final merged = _mergeBookmarks(remoteItems, localItems);
    if (merged.isEmpty) {
      return _loadInitialBookmarksIfNeeded();
    }

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
      isBookmarked: true,
      bookmarkedAt: restaurant.bookmarkedAt ?? now,
      updatedAt: now,
      bookmarkTopicIds: restaurant.bookmarkTopicIds.isEmpty
          ? const [_defaultTopicId]
          : restaurant.bookmarkTopicIds,
      bookmarkColorKey: restaurant.bookmarkColorKey ?? _defaultColorKey,
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

  Future<List<RestaurantModel>> addBookmark(
    RestaurantModel restaurant, {
    required List<String> topicIds,
    required String colorKey,
  }) async {
    final storeId = restaurant.effectiveStoreId;
    if (storeId.isEmpty) return loadBookmarks();

    final now = DateTime.now();
    final normalizedTopicIds = topicIds.isEmpty
        ? const [_defaultTopicId]
        : topicIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    final bookmarkedRestaurant = restaurant.copyWith(
      isBookmarked: true,
      bookmarkedAt: restaurant.bookmarkedAt ?? now,
      updatedAt: now,
      bookmarkTopicIds: normalizedTopicIds.isEmpty
          ? const [_defaultTopicId]
          : normalizedTopicIds,
      bookmarkColorKey: colorKey.trim().isEmpty ? _defaultColorKey : colorKey,
    );
    final current = await _loadLocal();
    final index = current.indexWhere(
      (item) => item.effectiveStoreId == storeId,
    );
    final next = index >= 0
        ? [
            ...current.sublist(0, index),
            bookmarkedRestaurant,
            ...current.sublist(index + 1),
          ]
        : [...current, bookmarkedRestaurant];

    await _saveLocal(next);
    await _syncRemoteAdd(bookmarkedRestaurant);
    return next;
  }

  Future<List<RestaurantModel>> updateBookmarkMetadata(
    String storeId, {
    required List<String> topicIds,
    required String colorKey,
  }) async {
    final normalizedStoreId = storeId.trim();
    if (normalizedStoreId.isEmpty) return loadBookmarks();

    final now = DateTime.now();
    final current = await _loadLocal();
    final next = current.map((restaurant) {
      if (restaurant.effectiveStoreId != normalizedStoreId) {
        return restaurant;
      }
      return restaurant.copyWith(
        isBookmarked: true,
        bookmarkTopicIds: topicIds,
        bookmarkColorKey: colorKey,
        updatedAt: now,
      );
    }).toList();

    await _saveLocal(next);
    final updated = next.where(
      (restaurant) => restaurant.effectiveStoreId == normalizedStoreId,
    );
    if (updated.isNotEmpty) {
      await _syncRemoteAdd(updated.first);
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

  Future<List<RestaurantModel>> clearLocalBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    return const [];
  }

  Future<List<RestaurantModel>> resetWithInitialBookmarks({
    required String region,
  }) async {
    await clearLocalBookmarks();

    final folders = await fetchInitialBookmarkFolders(region: region);
    final restaurants = _restaurantsFromInitialFolders(folders);
    if (restaurants.isEmpty) {
      return const [];
    }

    await _saveLocal(restaurants);
    await _markInitialSeeded();
    await _backfillRemote(localItems: restaurants, remoteItems: const []);
    return restaurants;
  }

  Future<List<BookmarkFolder>> fetchInitialBookmarkFolders({
    required String region,
  }) async {
    try {
      final uri = BackendConfig.apiUri('/bookmarks/initial').replace(
        queryParameters: {
          if (region.trim().isNotEmpty) 'region': region.trim(),
        },
      );
      final token = _accessToken;
      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawFolders = decoded is Map ? decoded['folders'] : decoded;
      if (rawFolders is! List) return const [];

      return rawFolders
          .whereType<Map>()
          .map((folder) => BookmarkFolder.fromJson(
                Map<String, dynamic>.from(folder),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
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

  Future<List<RestaurantModel>> _loadInitialBookmarksIfNeeded() async {
    if (await _hasSeededInitialBookmarks()) {
      return const [];
    }
    return resetWithInitialBookmarks(region: _defaultInitialRegion);
  }

  Future<bool> _hasSeededInitialBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_initialSeededKey) ?? false;
  }

  Future<void> _markInitialSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initialSeededKey, true);
  }

  List<RestaurantModel> _restaurantsFromInitialFolders(
    List<BookmarkFolder> folders,
  ) {
    final now = DateTime.now();
    final byStoreId = <String, RestaurantModel>{};

    for (final folder in folders) {
      final topicId = _topicIdForInitialFolder(folder.category);
      final colorKey = _colorKeyForTopic(topicId);

      for (final restaurant in folder.restaurants) {
        final storeId = restaurant.effectiveStoreId;
        if (storeId.isEmpty) continue;

        final current = byStoreId[storeId];
        final currentTopics = current?.bookmarkTopicIds ?? const [];
        final nextTopics = {
          ...currentTopics,
          if (topicId.isNotEmpty) topicId,
        }.toList();

        byStoreId[storeId] = restaurant.copyWith(
          isBookmarked: true,
          bookmarkedAt: current?.bookmarkedAt ?? now,
          updatedAt: now,
          bookmarkTopicIds:
              nextTopics.isEmpty ? const [_defaultTopicId] : nextTopics,
          bookmarkColorKey: current?.bookmarkColorKey ??
              restaurant.bookmarkColorKey ??
              colorKey,
        );
      }
    }

    return byStoreId.values.toList();
  }

  String _topicIdForInitialFolder(String category) {
    final normalizedCategory = category.trim();
    if (normalizedCategory.isEmpty) return _defaultTopicId;

    final matched = BookmarkTopics.items.where(
      (topic) =>
          topic.id == normalizedCategory || topic.label == normalizedCategory,
    );
    return matched.isEmpty ? _defaultTopicId : matched.first.id;
  }

  String _colorKeyForTopic(String topicId) {
    return switch (topicId) {
      'favorite' => 'sky',
      'date_place' => 'pink',
      'sns_like' => 'lavender',
      'nature_trip' => 'mint',
      'pretty_cafe' => 'peach',
      'unique_place' => 'coral',
      'local_traditional_food' => 'olive',
      'premium_restaurant' => 'graphite',
      'tv_featured_place' => 'ocean',
      'old_local_place' => 'yellow',
      _ => _defaultColorKey,
    };
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
