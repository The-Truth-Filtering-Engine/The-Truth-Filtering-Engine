import 'dart:math' as math;

class MapPoint {
  final double latitude;
  final double longitude;

  const MapPoint({
    required this.latitude,
    required this.longitude,
  });
}

class MapBounds {
  final MapPoint southWest;
  final MapPoint northEast;

  const MapBounds({
    required this.southWest,
    required this.northEast,
  });
}

class KakaoMapCamera {
  final MapPoint center;
  final MapBounds bounds;
  final int level;

  const KakaoMapCamera({
    required this.center,
    required this.bounds,
    required this.level,
  });
}

double distanceMeters(MapPoint a, MapPoint b) {
  const earthRadiusMeters = 6371000.0;
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLng = _toRadians(b.longitude - a.longitude);

  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return earthRadiusMeters * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;
