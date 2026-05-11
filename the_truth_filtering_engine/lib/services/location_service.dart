import 'package:geolocator/geolocator.dart';

import '../features/1-1_map/models/map_point.dart';

class LocationService {
  Future<MapPoint?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition();
    return MapPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
