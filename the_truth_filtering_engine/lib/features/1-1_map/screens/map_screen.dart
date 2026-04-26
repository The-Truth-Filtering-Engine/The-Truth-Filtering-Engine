import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../models/restaurant_model.dart';
import '../providers/map_provider.dart';
import '../widgets/map_control_buttons.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/restaurant_bottom_sheet.dart';
import '../widgets/truth_score_marker.dart';
import '../../1-2_restaurant_list/screens/restaurant_list_screen.dart';
import '../../1-3_restaurant_detail/screens/restaurant_detail_screen.dart';

class MapScreen extends ConsumerStatefulWidget { 
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  int _mapModeIndex = 3;

  static const _initialCenter = LatLng(37.5245, 127.0370);
  static const _initialZoom = 14.0;

  static final _mapTileModes = [
    _MapTileMode(
      label: 'Carto Light',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
    ),
    _MapTileMode(
      label: 'Carto Dark',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
    ),
    _MapTileMode(
      label: 'OpenTopoMap',
      urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
    ),
    _MapTileMode(
      label: 'OpenStreetMap Standard',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: [],
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCurrentLocationToProvider();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantListProvider);
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final mapMode = _currentMapMode();

        return Scaffold(
      backgroundColor: AppColors.mapTeal,
      body: Stack(
        children: [
          // ── flutter_map ──────────────────────────
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
              TileLayer(
                urlTemplate: mapMode.urlTemplate,
                subdomains: mapMode.subdomains,
                userAgentPackageName: 'com.example.truth_map',
              ),
              MarkerLayer(
                markers: [
                  ...restaurants.map((restaurant) {
                    return Marker(
                      point: LatLng(restaurant.latitude, restaurant.longitude),
                      width: 80,
                      height: 50,
                      child: TruthScoreMarker(
                        restaurant: restaurant,
                        onTap: () => _onMarkerTapped(restaurant),
                      ),
                    );
                  }),
                  if (currentLocation != null)
                    Marker(
                      point: currentLocation,
                      width: 30,
                      height: 30,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0x3323A0FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                ].toList(),
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MapSearchBar(
                controller: _searchController,
                hintText: '음식점 또는 메뉴를 검색',
                onSubmitted: (value) {
                  final query = value.trim();
                  if (query.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('검색어를 입력해 주세요'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    return;
                  }

                  final currentLocation = ref.read(currentLocationProvider);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RestaurantListScreen(
                        query: query,
                        initialLatitude: currentLocation?.latitude,
                        initialLongitude: currentLocation?.longitude,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: selectedRestaurant != null ? 230 : 100,
            child: MapControlButtons(
              onLocationTap: _moveToCurrentLocation,
              onLayerTap: () {
                _cycleMapMode();
              },
              onZoomIn: () => _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              ),
              onZoomOut: () => _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              ),
            ),
          ),

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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(
                          restaurant: selectedRestaurant,
                        ),
                      ),
                    );
                  },
                  onBookmarkTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('북마크 저장은 준비 중입니다'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  onShareTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('공유는 준비 중입니다'),
                        duration: Duration(seconds: 1),
                      ),
                    );
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
    _syncCurrentLocationToProvider();
  }

  void _cycleMapMode() {
    if (_mapTileModes.isEmpty) return;

    setState(() {
      _mapModeIndex = (_mapModeIndex + 1) % _mapTileModes.length;
    });
  }

  _MapTileMode _currentMapMode() {
    if (_mapTileModes.isEmpty) {
      return const _MapTileMode(
        label: 'OpenStreetMap Standard',
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        subdomains: [],
      );
    }

    final normalizedIndex = _mapModeIndex % _mapTileModes.length;
    return _mapTileModes[normalizedIndex];
  }

  Future<void> _syncCurrentLocationToProvider() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);
      ref.read(currentLocationProvider.notifier).state = location;
      _mapController.move(location, _initialZoom);
    } catch (_) {}
  }
}

class _MapTileMode {
  final String label;
  final String urlTemplate;
  final List<String> subdomains;

  const _MapTileMode({
    required this.label,
    required this.urlTemplate,
    required this.subdomains,
  });
}
