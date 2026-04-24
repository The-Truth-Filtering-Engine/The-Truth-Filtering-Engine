import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant_model.dart';

// 레스토랑 목록 provider (더미 데이터)
final restaurantListProvider = Provider<List<RestaurantModel>>((ref) {
  return RestaurantDummyData.restaurants;
});

// 선택된 레스토랑 provider (바텀시트 표시용)
final selectedRestaurantProvider =
    StateProvider<RestaurantModel?>((ref) => null);

// 지도 레이어 표시 여부
final showLayerMenuProvider = StateProvider<bool>((ref) => false);
