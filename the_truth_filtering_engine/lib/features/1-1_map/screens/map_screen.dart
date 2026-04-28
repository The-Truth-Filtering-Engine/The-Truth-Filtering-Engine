import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_colors.dart';
import '../models/map_point.dart';
import '../models/restaurant_model.dart';
import '../providers/map_provider.dart';
import '../widgets/kakao_map_view.dart';
import '../widgets/map_control_buttons.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/restaurant_bottom_sheet.dart';
import '../../1-2_restaurant_list/screens/restaurant_list_screen.dart';
import '../../1-3_restaurant_detail/screens/restaurant_detail_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final GlobalKey<KakaoMapViewState> _mapViewKey =
      GlobalKey<KakaoMapViewState>();
  final TextEditingController _searchController = TextEditingController();
  Timer? _viewportSearchTimer;
  int _viewportSearchReqId = 0;

  static const int _maxMapRestaurants = 10;
  static const Duration _viewportDebounce = Duration(milliseconds: 600);
  static const int _refreshDistanceMeters = 150;

  static const _initialCenter = MapPoint(37.5245, 127.0370);
  static const _initialLevel = 4;

  List<RestaurantModel>? _viewportRestaurants;
  String? _viewportSearchError;
  MapPoint? _lastSearchedCenter;
  int? _lastSearchedLevel;
  int _latestMapLevel = _initialLevel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCurrentLocationToProvider();
    });
  }

  @override
  void dispose() {
    _viewportSearchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final bookmarkedRestaurants = ref.watch(bookmarkRestaurantsProvider);
    final displayRestaurants = _reduceRestaurantOverdraw(
      restaurants: _viewportRestaurants,
      level: _latestMapLevel,
    );
    final isSelectedBookmarked = selectedRestaurant != null &&
        bookmarkedRestaurants.any((item) => item.id == selectedRestaurant.id);

    return Scaffold(
      backgroundColor: AppColors.mapTeal,
      body: Stack(
        children: [
          KakaoMapView(
            key: _mapViewKey,
            initialCenter: _initialCenter,
            initialLevel: _initialLevel,
            restaurants: displayRestaurants,
            currentLocation: currentLocation,
            onMarkerTap: _onMarkerTapped,
            onMapTap: () {
              ref.read(selectedRestaurantProvider.notifier).state = null;
            },
            onCameraIdle: _onCameraIdle,
          ),
          if (_viewportSearchError != null)
            Positioned(
              left: 16,
              right: 16,
              top: 84,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _viewportSearchError!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
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
              onLayerTap: () => _mapViewKey.currentState?.toggleMapType(),
              onZoomIn: () => _mapViewKey.currentState?.zoomIn(),
              onZoomOut: () => _mapViewKey.currentState?.zoomOut(),
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
                  isBookmarked: isSelectedBookmarked,
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
                    final previous = ref.read(bookmarkRestaurantsProvider);
                    final alreadyBookmarked = previous
                        .any((item) => item.id == selectedRestaurant.id);
                    ref
                        .read(bookmarkRestaurantsProvider.notifier)
                        .toggle(selectedRestaurant);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          alreadyBookmarked ? '북마크에서 해제되었습니다' : '북마크에 저장했습니다',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  onShareTap: () {
                    _shareRestaurant(selectedRestaurant, context);
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
  }

  void _onCameraIdle(KakaoMapCamera camera) {
    _latestMapLevel = camera.level;
    _onViewportChanged(camera);
  }

  Future<void> _shareRestaurant(
    RestaurantModel restaurant,
    BuildContext context,
  ) async {
    final link = restaurant.placeUrl?.trim();
    if (link == null || link.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('공유 가능한 링크가 없습니다'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('링크가 복사되었습니다'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onViewportChanged(KakaoMapCamera camera) {
    if (!_shouldRefreshViewport(camera.center, camera.level)) return;

    final radiusMeters = _calculateViewportRadius(
      camera.bounds,
      camera.center,
    );
    if (radiusMeters <= 0) return;

    _viewportSearchTimer?.cancel();
    _viewportSearchTimer = Timer(_viewportDebounce, () {
      if (!mounted) return;
      _searchViewportRestaurants(
        center: camera.center,
        level: camera.level,
        radiusMeters: radiusMeters,
      );
    });
  }

  bool _shouldRefreshViewport(MapPoint center, int level) {
    if (_lastSearchedCenter == null || _lastSearchedLevel == null) return true;

    final movedMeters = distanceMeters(center, _lastSearchedCenter!);
    final levelChanged = level != _lastSearchedLevel;

    return movedMeters >= _refreshDistanceMeters || levelChanged;
  }

  int _calculateViewportRadius(MapBounds bounds, MapPoint center) {
    final northEast = bounds.northEast;
    final southWest = bounds.southWest;
    final northWest = MapPoint(northEast.latitude, southWest.longitude);
    final southEast = MapPoint(southWest.latitude, northEast.longitude);

    final candidates = [
      distanceMeters(center, northWest),
      distanceMeters(center, southEast),
      distanceMeters(center, northEast),
      distanceMeters(center, southWest),
    ];

    var maxDistance = 0.0;
    for (final distance in candidates) {
      if (distance > maxDistance) maxDistance = distance;
    }

    final radius = maxDistance.floor().toInt();
    if (radius <= 0) return 0;

    if (radius > 20000) return 20000;
    if (radius < 100) return 100;
    return radius;
  }

  Future<void> _searchViewportRestaurants({
    required MapPoint center,
    required int level,
    required int radiusMeters,
  }) async {
    final requestId = ++_viewportSearchReqId;
    if (!mounted) return;

    setState(() => _viewportSearchError = null);

    try {
      final uri = Uri.http(
        'localhost:8000',
        '/places/nearby-restaurants',
        {
          'lat': center.latitude.toString(),
          'lng': center.longitude.toString(),
          'radius': radiusMeters.toString(),
          'display': '10',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        if (!mounted || requestId != _viewportSearchReqId) return;
        setState(() => _viewportSearchError = '서버 에러 (${response.statusCode})');
        return;
      }

      final data = jsonDecode(response.body);
      final List items = data['restaurants'] ?? [];

      final restaurants = items
          .map((item) => RestaurantModel(
                id: item['id']?.toString() ?? '',
                name: item['name'] ?? '',
                category: item['category'] ?? '음식점',
                address: item['address'] ?? '',
                truthScore: _mockTrustScore(item['id']?.toString() ?? ''),
                distance: item['distance'] ?? 0,
                phone: null,
                placeUrl: item['link'],
                reviewSummary: item['name'] ?? '검색 결과',
                imageUrl: null,
                latitude: (item['lat'] as num).toDouble(),
                longitude: (item['lng'] as num).toDouble(),
              ))
          .toList();

      if (!mounted || requestId != _viewportSearchReqId) return;

      final selectedRestaurant = ref.read(selectedRestaurantProvider);
      if (selectedRestaurant != null &&
          restaurants.every((r) => r.id != selectedRestaurant.id)) {
        ref.read(selectedRestaurantProvider.notifier).state = null;
      }

      setState(() {
        _viewportRestaurants = restaurants;
        _viewportSearchError = null;
        _lastSearchedCenter = center;
        _lastSearchedLevel = level;
      });
    } catch (_) {
      if (!mounted || requestId != _viewportSearchReqId) return;
      setState(() => _viewportSearchError = '네트워크 에러가 발생했습니다');
    }
  }

  int _mockTrustScore(String id) {
    final hash = id.hashCode.abs() % 40;
    return 60 + hash;
  }

  List<RestaurantModel> _reduceRestaurantOverdraw({
    required List<RestaurantModel>? restaurants,
    required int level,
  }) {
    final source = restaurants ?? const <RestaurantModel>[];
    if (source.isEmpty) return const [];

    final maxMarkers = _maxMapMarkersByLevel(level);
    if (source.length <= maxMarkers) return List.of(source);

    final minCellMeters = _markerCellSizeMeters(level);
    if (minCellMeters <= 0) return source.take(maxMarkers).toList();

    final selected = <RestaurantModel>[];
    final usedCells = <String>{};

    for (final restaurant in source) {
      if (selected.length >= maxMarkers) break;

      final key = _restaurantCellKey(
        lat: restaurant.latitude,
        lng: restaurant.longitude,
        cellMeters: minCellMeters,
      );
      if (usedCells.contains(key)) continue;

      usedCells.add(key);
      selected.add(restaurant);
    }

    return selected;
  }

  int _maxMapMarkersByLevel(int level) {
    if (level >= 7) return 15;
    if (level >= 6) return 25;
    if (level >= 5) return 40;
    return _maxMapRestaurants;
  }

  double _markerCellSizeMeters(int level) {
    if (level >= 7) return 800;
    if (level >= 6) return 400;
    if (level >= 5) return 200;
    if (level >= 4) return 100;
    return 40;
  }

  String _restaurantCellKey({
    required double lat,
    required double lng,
    required double cellMeters,
  }) {
    final latCellDeg = cellMeters / 111320;
    final lngCellDeg = cellMeters /
        math.max(
          1.0,
          111320 * math.cos(lat * math.pi / 180).abs(),
        );

    if (latCellDeg <= 0 || lngCellDeg <= 0) {
      return '${lat.toStringAsFixed(6)}:${lng.toStringAsFixed(6)}';
    }

    final latIndex = (lat / latCellDeg).floor();
    final lngIndex = (lng / lngCellDeg).floor();
    return '$latIndex:$lngIndex';
  }

  void _moveToCurrentLocation() {
    _syncCurrentLocationToProvider();
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final location = MapPoint(position.latitude, position.longitude);
      ref.read(currentLocationProvider.notifier).state = location;
      _mapViewKey.currentState?.moveTo(location, level: _initialLevel);
    } catch (_) {}
  }
}
