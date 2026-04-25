import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../models/restaurant_model.dart';
import '../providers/map_provider.dart';
import '../widgets/map_control_buttons.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/restaurant_bottom_sheet.dart';
import '../widgets/truth_score_marker.dart';
import '../../1-2_restaurant_detail/screens/search_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  static const _initialCenter = LatLng(37.5245, 127.0370);
  static const _initialZoom = 14.0;

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantListProvider);
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);

    return Scaffold(
      backgroundColor: AppColors.mapTeal,
      body: Stack(
        children: [
          // ── flutter_map ───────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              onTap: (_, __) {
                ref.read(selectedRestaurantProvider.notifier).state = null;
              },
            ),
            children: [
              // OpenStreetMap 타일
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.truth_map',
              ),
              // 마커 레이어
              MarkerLayer(
                markers: restaurants.map((restaurant) {
                  return Marker(
                    point: LatLng(restaurant.latitude, restaurant.longitude),
                    width: 80,
                    height: 50,
                    child: TruthScoreMarker(
                      restaurant: restaurant,
                      onTap: () => _onMarkerTapped(restaurant),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── 상단 검색바 ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MapSearchBar(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SearchScreen(),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── 우측 컨트롤 버튼 ─────────────────────────────────
          Positioned(
            right: 16,
            bottom: selectedRestaurant != null ? 230 : 100,
            child: MapControlButtons(
              onLocationTap: _moveToCurrentLocation,
              onLayerTap: () {
                ref.read(showLayerMenuProvider.notifier).state =
                    !ref.read(showLayerMenuProvider);
              },
              onZoomIn: () {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                );
              },
              onZoomOut: () {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                );
              },
            ),
          ),

          // ── 바텀시트 ─────────────────────────────────────────
          if (selectedRestaurant != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: Offset.zero,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: RestaurantBottomSheet(
                  restaurant: selectedRestaurant,
                  onDetailTap: () {
                    // TODO: 상세 화면으로 이동
                  },
                  onBookmarkTap: () {
                    // TODO: 북마크 처리
                  },
                  onShareTap: () {
                    // TODO: 공유 처리
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onMarkerTapped(RestaurantModel restaurant) {
    ref.read(selectedRestaurantProvider.notifier).state = restaurant;
    _mapController.move(
      LatLng(restaurant.latitude, restaurant.longitude),
      15,
    );
  }

  void _moveToCurrentLocation() {
    // TODO: 실제 GPS 연동
    _mapController.move(_initialCenter, 15);
  }
}
