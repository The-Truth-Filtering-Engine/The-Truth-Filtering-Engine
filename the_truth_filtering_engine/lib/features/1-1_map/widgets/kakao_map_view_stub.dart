import 'package:flutter/material.dart';

import '../models/map_point.dart';
import '../models/restaurant_model.dart';

class KakaoMapView extends StatefulWidget {
  final MapPoint initialCenter;
  final int initialLevel;
  final List<RestaurantModel> restaurants;
  final MapPoint? currentLocation;
  final ValueChanged<RestaurantModel> onMarkerTap;
  final ValueChanged<KakaoMapCamera> onCameraIdle;
  final VoidCallback? onMapTap;

  const KakaoMapView({
    super.key,
    required this.initialCenter,
    required this.initialLevel,
    required this.restaurants,
    required this.currentLocation,
    required this.onMarkerTap,
    required this.onCameraIdle,
    this.onMapTap,
  });

  @override
  KakaoMapViewState createState() => KakaoMapViewState();
}

class KakaoMapViewState extends State<KakaoMapView> {
  void moveTo(MapPoint point, {int? level}) {}

  void zoomIn() {}

  void zoomOut() {}

  void toggleMapType() {}

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE9EEF1),
      child: Center(
        child: Text(
          '카카오맵은 현재 Chrome 웹에서만 지원됩니다',
          style: TextStyle(
            color: Color(0xFF334155),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
