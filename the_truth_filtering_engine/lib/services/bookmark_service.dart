import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/1-1_map/models/restaurant_model.dart';

class BookmarkService {
  static const _storageKey = 'bookmarked_restaurants';

  Future<List<RestaurantModel>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => RestaurantModel.fromJson(item.cast<String, dynamic>()))
        .where((restaurant) => restaurant.id.isNotEmpty)
        .toList();
  }

  Future<List<RestaurantModel>> toggleBookmark(
      RestaurantModel restaurant) async {
    final current = await loadBookmarks();
    final index = current.indexWhere((item) => item.id == restaurant.id);
    final next = index >= 0
        ? [
            ...current.sublist(0, index),
            ...current.sublist(index + 1),
          ]
        : [...current, restaurant];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return next;
  }
}
