import '../models/restaurant_model.dart';

String? buildKakaoCarRouteUrl(RestaurantModel restaurant) {
  final placeId = _extractKakaoPlaceId(restaurant);
  if (placeId != null) {
    final encodedName = Uri.encodeComponent(restaurant.name);
    return 'https://map.kakao.com/?map_type=TYPE_MAP&target=car'
        '&rt=,,&rt1=$encodedName&rt2=&rtIds=,$placeId';
  }

  if (restaurant.latitude == 0 || restaurant.longitude == 0) {
    return null;
  }

  final encodedName = Uri.encodeComponent(restaurant.name);
  return 'https://map.kakao.com/link/to/'
      '$encodedName,${restaurant.latitude},${restaurant.longitude}';
}

String? _extractKakaoPlaceId(RestaurantModel restaurant) {
  final fromUrl = _numericTail(restaurant.placeUrl);
  if (fromUrl != null) return fromUrl;

  final fromStoreId = _numericOnly(restaurant.effectiveStoreId);
  if (fromStoreId != null) return fromStoreId;

  return _numericOnly(restaurant.id);
}

String? _numericTail(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  final source = uri?.pathSegments.isNotEmpty == true
      ? uri!.pathSegments.last
      : text.split('/').last;
  return _numericOnly(source);
}

String? _numericOnly(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return RegExp(r'^\d+$').hasMatch(text) ? text : null;
}
