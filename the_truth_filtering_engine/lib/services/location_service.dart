import '../features/1-1_map/models/map_point.dart';

class LocationService {
  Future<MapPoint?> getCurrentPosition() async {
    // geolocator 패키지를 연결할 때 여기에서 실제 위치 권한/좌표를 처리하세요.
    // 현재는 React 코드의 INITIAL_CENTER와 같은 기본 좌표를 반환합니다.
    return const MapPoint(latitude: 37.5245, longitude: 127.037);
  }
}
