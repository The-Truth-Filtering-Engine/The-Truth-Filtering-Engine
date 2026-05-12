import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_service.dart';
import '../../../services/bookmark_service.dart';
import '../models/map_point.dart';
import '../models/restaurant_model.dart';

// 레스토랑 목록 provider (실제 API)
final restaurantListProvider =
    FutureProvider<List<RestaurantModel>>((ref) async {
  final api = ApiService();

  return api.fetchNearbyRestaurants(
    center: const MapPoint(
      latitude: 37.5245,
      longitude: 127.037,
    ),
    radius: 1200,
  );
});

// 선택된 레스토랑 provider (바텀시트 표시용)
final selectedRestaurantProvider =
    StateProvider<RestaurantModel?>((ref) => null);

// 외부 화면에서 지도 탭으로 이동시키며 특정 식당에 포커스할 때 사용
final mapFocusRestaurantProvider =
    StateProvider<RestaurantModel?>((ref) => null);

// 북마크 목록
final bookmarkRestaurantsProvider =
    StateNotifierProvider<BookmarkRestaurantsNotifier, List<RestaurantModel>>(
  (ref) => BookmarkRestaurantsNotifier(),
);

// 북마크 추가/삭제
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

// 지도 레이어 표시 여부
final showLayerMenuProvider = StateProvider<bool>((ref) => false);

// 지도 화면에서 획득한 현재 위치
final currentLocationProvider = StateProvider<MapPoint?>((ref) => null);
