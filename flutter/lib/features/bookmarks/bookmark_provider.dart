import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../map/models/restaurant_model.dart';
import 'bookmark_service.dart';

final bookmarkRestaurantsProvider =
    StateNotifierProvider<BookmarkRestaurantsNotifier, List<RestaurantModel>>(
  (ref) => BookmarkRestaurantsNotifier(),
);

class BookmarkRestaurantsNotifier extends StateNotifier<List<RestaurantModel>> {
  final BookmarkService _bookmarkService;

  BookmarkRestaurantsNotifier({
    BookmarkService? bookmarkService,
  })  : _bookmarkService = bookmarkService ?? BookmarkService(),
        super(const []) {
    _load();
  }

  Future<void> toggle(RestaurantModel restaurant) async {
    state = await _bookmarkService.toggleBookmark(restaurant);
  }

  Future<void> remove(RestaurantModel restaurant) async {
    state = await _bookmarkService.removeBookmark(restaurant);
  }

  Future<void> _load() async {
    try {
      state = await _bookmarkService.loadBookmarks();
    } catch (_) {
      state = const [];
    }
  }
}
