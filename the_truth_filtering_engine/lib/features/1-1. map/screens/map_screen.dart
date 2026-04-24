import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/restaurant_model.dart';
import '../providers/map_provider.dart';
import '../widgets/map_control_buttons.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/restaurant_bottom_sheet.dart';
import '../widgets/truth_score_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NaverMapController? _mapController;

  // 서울 강남 중심 초기 위치
  static const _initialCameraPosition = NCameraPosition(
    target: NLatLng(37.5245, 127.0370),
    zoom: 14,
  );

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantListProvider);
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);

    return Scaffold(
      backgroundColor: AppColors.mapTeal,
      body: Stack(
        children: [
          // ── 네이버 지도 ──────────────────────────────────────
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: _initialCameraPosition,
              mapType: NMapType.basic,
              activeLayerGroups: [NLayerGroup.building, NLayerGroup.transit],
              locationButtonEnable: false,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _addMarkers(restaurants);
            },
            onMapTapped: (_, __) {
              // 지도 탭 시 바텀시트 닫기
              ref.read(selectedRestaurantProvider.notifier).state = null;
            },
          ),

          // ── 상단 검색바 ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MapSearchBar(
                onTap: () {
                  // TODO: 검색 화면으로 이동
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
              onZoomIn: () async {
                final zoom = await _currentZoom();
                _mapController?.updateCamera(
                  NCameraUpdate.withParams(zoom: zoom + 1),
                );
              },
              onZoomOut: () async {
                final zoom = await _currentZoom();
                _mapController?.updateCamera(
                  NCameraUpdate.withParams(zoom: zoom - 1),
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

  /// 네이버 지도에 커스텀 마커 추가
  Future<void> _addMarkers(List<RestaurantModel> restaurants) async {
    if (_mapController == null) return;

    for (final restaurant in restaurants) {
      // 마커 위젯을 오버레이 이미지로 변환
      final markerWidget = TruthScoreMarker(
        restaurant: restaurant,
        onTap: () => _onMarkerTapped(restaurant),
      );

      final overlayImage = await NOverlayImage.fromWidget(
        widget: markerWidget,
        size: const Size(80, 50),
        context: context,
      );

      final marker = NMarker(
        id: restaurant.id,
        position: NLatLng(restaurant.latitude, restaurant.longitude),
        icon: overlayImage,
        anchor: const NPoint(0.5, 1.0),
      );

      marker.setOnTapListener((_) => _onMarkerTapped(restaurant));
      await _mapController!.addOverlay(marker);
    }
  }

  void _onMarkerTapped(RestaurantModel restaurant) {
    ref.read(selectedRestaurantProvider.notifier).state = restaurant;

    // 카메라 이동
    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(restaurant.latitude, restaurant.longitude),
        zoom: 15,
      ),
    );
  }

  Future<double> _currentZoom() async {
    final cameraPosition = await _mapController?.getCameraPosition();
    return cameraPosition?.zoom ?? 14;
  }

  void _moveToCurrentLocation() {
    // TODO: 실제 GPS 연동
    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: const NLatLng(37.5245, 127.0370),
        zoom: 15,
      ),
    );
  }
}
