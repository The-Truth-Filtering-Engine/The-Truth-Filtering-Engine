import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/current_user_provider.dart';
import '../map/models/restaurant_model.dart';
import 'bookmark_service.dart';

final bookmarkRestaurantsProvider =
    StateNotifierProvider<BookmarkRestaurantsNotifier, List<RestaurantModel>>(
  (ref) {
    final authState = ref.watch(appAuthProvider);
    return BookmarkRestaurantsNotifier(
      bookmarkService: BookmarkService(
        isTestAccountLogin: authState.isTestAccountLogin,
      ),
    );
  },
);

class BookmarkRestaurantsNotifier extends StateNotifier<List<RestaurantModel>> {
  final BookmarkService _bookmarkService;

  BookmarkRestaurantsNotifier({
    required BookmarkService bookmarkService,
  })  : _bookmarkService = bookmarkService,
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
