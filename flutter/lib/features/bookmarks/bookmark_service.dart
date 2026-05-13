import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';
import '../../core/config/test_admin_auth_config.dart';
import '../map/models/restaurant_model.dart';

class BookmarkService {
  BookmarkService({required this.isAdmin});

  final bool isAdmin;
  List<RestaurantModel> _items = const [];

  Future<List<RestaurantModel>> loadBookmarks() async {
    final remoteItems = await _loadRemote();
    if (remoteItems != null) {
      _items = remoteItems;
    }
    return _items;
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
    final index = _items.indexWhere(
      (item) => item.effectiveStoreId == storeId,
    );
    final next = index >= 0
        ? [
            ..._items.sublist(0, index),
            ..._items.sublist(index + 1),
          ]
        : [..._items, bookmarkedRestaurant];
    _items = next;

    if (index >= 0) {
      await _syncRemoteRemove(storeId);
    } else {
      await _syncRemoteAdd(bookmarkedRestaurant);
    }

    return _items;
  }

  Future<List<RestaurantModel>> removeBookmark(
    RestaurantModel restaurant,
  ) async {
    return removeBookmarkById(restaurant.effectiveStoreId);
  }

  Future<List<RestaurantModel>> removeBookmarkById(String storeId) async {
    final normalizedStoreId = storeId.trim();
    if (normalizedStoreId.isEmpty) return loadBookmarks();

    final next = _items
        .where((item) => item.effectiveStoreId != normalizedStoreId)
        .toList();
    _items = next;
    await _syncRemoteRemove(normalizedStoreId);
    return _items;
  }

  Map<String, String>? get _authHeaders {
    final headers = TestAdminAuthConfig.headers(isAdmin: isAdmin);
    return headers.isEmpty ? null : headers;
  }

  Future<List<RestaurantModel>?> _loadRemote() async {
    final headers = _authHeaders;
    if (headers == null) return null;

    try {
      final response = await http.get(
        BackendConfig.apiUri('/user/me/bookmarks'),
        headers: headers,
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
    final headers = _authHeaders;
    if (headers == null) return;

    try {
      await http.post(
        BackendConfig.apiUri('/user/me/bookmarks'),
        headers: {
          ...headers,
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
    final headers = _authHeaders;
    if (headers == null) return;

    try {
      await http.delete(
        BackendConfig.apiUri(
          '/user/me/bookmarks/${Uri.encodeComponent(storeId)}',
        ),
        headers: headers,
      );
    } catch (_) {}
  }
}
