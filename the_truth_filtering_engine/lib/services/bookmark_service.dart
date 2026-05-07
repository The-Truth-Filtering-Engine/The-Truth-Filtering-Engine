import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/1-1_map/models/restaurant_model.dart';

class BookmarkService {
  static const String storageKey = 'bookmarked_restaurants';

  Future<List<RestaurantModel>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RestaurantModel.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> saveBookmarks(List<RestaurantModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<RestaurantModel>> toggleBookmark(
      RestaurantModel restaurant) async {
    final previous = await loadBookmarks();
    final exists = previous.any((item) => item.id == restaurant.id);
    final next = exists
        ? previous.where((item) => item.id != restaurant.id).toList()
        : [restaurant, ...previous];
    await saveBookmarks(next);
    return next;
  }
}
