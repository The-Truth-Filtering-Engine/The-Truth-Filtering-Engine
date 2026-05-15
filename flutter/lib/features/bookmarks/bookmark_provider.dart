import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../map/models/restaurant_model.dart';
import 'bookmark_options.dart';
import 'bookmark_service.dart';

final bookmarkRestaurantsProvider =
    StateNotifierProvider<BookmarkRestaurantsNotifier, List<RestaurantModel>>(
  (ref) => BookmarkRestaurantsNotifier(),
);

final bookmarkCustomTopicsProvider = StateNotifierProvider<
    BookmarkCustomTopicsNotifier, List<BookmarkTopicOption>>(
  (ref) => BookmarkCustomTopicsNotifier(),
);

final bookmarkHiddenTopicIdsProvider =
    StateNotifierProvider<BookmarkHiddenTopicIdsNotifier, Set<String>>(
  (ref) => BookmarkHiddenTopicIdsNotifier(),
);

class BookmarkCustomTopicsNotifier
    extends StateNotifier<List<BookmarkTopicOption>> {
  BookmarkCustomTopicsNotifier() : super(const []) {
    _load();
  }

  Future<BookmarkTopicOption?> add(
    String label, {
    String colorKey = BookmarkColors.defaultColorKey,
  }) async {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty) return null;

    final normalizedId = _customTopicId(normalizedLabel);
    final existingLabels = BookmarkTopics.all(state)
        .map((topic) => topic.label.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (existingLabels.contains(normalizedLabel)) return null;

    final existingIds =
        BookmarkTopics.all(state).map((topic) => topic.id).toSet();
    var id = normalizedId;
    var suffix = 2;
    while (existingIds.contains(id)) {
      id = '${normalizedId}_$suffix';
      suffix += 1;
    }

    final topic = BookmarkTopicOption(
      id,
      normalizedLabel,
      colorKey: BookmarkColors.byKey(colorKey).key,
    );
    state = [...state, topic];
    await BookmarkTopics.saveCustomTopics(state);
    return topic;
  }

  Future<void> delete(String topicId) async {
    final normalizedTopicId = BookmarkTopics.visibleTopicId(topicId);
    if (normalizedTopicId.isEmpty ||
        BookmarkTopics.isDefaultTopic(normalizedTopicId)) {
      return;
    }

    state = state
        .where((topic) =>
            BookmarkTopics.visibleTopicId(topic.id) != normalizedTopicId)
        .toList();
    await BookmarkTopics.saveCustomTopics(state);
  }

  Future<void> _load() async {
    state = await BookmarkTopics.loadCustomTopics();
  }

  String _customTopicId(String label) {
    final compact = label
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9가-힣_]'), '');
    final seed = compact.isEmpty ? 'topic' : compact;
    return 'custom_$seed';
  }
}

class BookmarkHiddenTopicIdsNotifier extends StateNotifier<Set<String>> {
  BookmarkHiddenTopicIdsNotifier() : super(const {}) {
    _load();
  }

  Future<void> hide(String topicId) async {
    final normalizedTopicId = BookmarkTopics.visibleTopicId(topicId);
    if (!BookmarkTopics.canDeleteTopic(normalizedTopicId)) return;

    state = {...state, normalizedTopicId};
    await BookmarkTopics.saveHiddenTopicIds(state);
  }

  Future<void> _load() async {
    state = await BookmarkTopics.loadHiddenTopicIds();
  }
}

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

  Future<void> add(
    RestaurantModel restaurant, {
    required List<String> topicIds,
    required String colorKey,
  }) async {
    state = await _bookmarkService.addBookmark(
      restaurant,
      topicIds: topicIds,
      colorKey: colorKey,
    );
  }

  Future<void> remove(RestaurantModel restaurant) async {
    state = await _bookmarkService.removeBookmark(restaurant);
  }

  Future<void> removeByTopicId(String topicId) async {
    final normalizedTopicId = BookmarkTopics.visibleTopicId(topicId);
    if (normalizedTopicId.isEmpty) return;

    final targets = state.where((restaurant) {
      final topicIds = restaurant.bookmarkTopicIds.isEmpty
          ? const [BookmarkTopics.defaultTopicId]
          : restaurant.bookmarkTopicIds;
      return topicIds.map(BookmarkTopics.visibleTopicId).contains(
            normalizedTopicId,
          );
    }).toList();

    var next = state;
    for (final restaurant in targets) {
      next = await _bookmarkService.removeBookmarkById(
        restaurant.effectiveStoreId,
      );
    }
    state = next;
  }

  Future<void> updateMetadata(
    RestaurantModel restaurant, {
    required List<String> topicIds,
    required String colorKey,
  }) async {
    state = await _bookmarkService.updateBookmarkMetadata(
      restaurant.effectiveStoreId,
      topicIds: topicIds,
      colorKey: colorKey,
    );
  }

  Future<void> clearLocal() async {
    state = await _bookmarkService.clearLocalBookmarks();
  }

  Future<void> resetWithInitialBookmarks({required String region}) async {
    state = await _bookmarkService.resetWithInitialBookmarks(region: region);
  }

  Future<void> _load() async {
    try {
      state = await _bookmarkService.loadBookmarks();
    } catch (_) {
      state = const [];
    }
  }
}
