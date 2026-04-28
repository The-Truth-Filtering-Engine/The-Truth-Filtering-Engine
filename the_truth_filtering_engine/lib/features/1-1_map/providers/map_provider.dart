import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/map_point.dart';
import '../models/restaurant_model.dart';

// 레스토랑 목록 provider (더미 데이터)
final restaurantListProvider = Provider<List<RestaurantModel>>((ref) {
  return RestaurantDummyData.restaurants;
});

// 선택된 레스토랑 provider (바텀시트 표시용)
final selectedRestaurantProvider =
    StateProvider<RestaurantModel?>((ref) => null);

// 북마크 목록
final bookmarkRestaurantsProvider =
    StateNotifierProvider<BookmarkRestaurantsNotifier, List<RestaurantModel>>(
  (ref) => BookmarkRestaurantsNotifier(),
);

// 북마크 추가/삭제
class BookmarkRestaurantsNotifier extends StateNotifier<List<RestaurantModel>> {
  BookmarkRestaurantsNotifier() : super(const []);

  void toggle(RestaurantModel restaurant) {
    final index = state.indexWhere((item) => item.id == restaurant.id);
    if (index >= 0) {
      state = [
        ...state.sublist(0, index),
        ...state.sublist(index + 1),
      ];
      return;
    }

    state = [...state, restaurant];
  }

  void remove(RestaurantModel restaurant) {
    state = state.where((item) => item.id != restaurant.id).toList();
  }
}

// 지도 레이어 표시 여부
final showLayerMenuProvider = StateProvider<bool>((ref) => false);

// 지도 화면에서 획득한 현재 위치
final currentLocationProvider = StateProvider<MapPoint?>((ref) => null);
