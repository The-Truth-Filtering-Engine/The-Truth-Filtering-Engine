import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
  final Distance _distance = const Distance();
  Timer? _viewportSearchTimer;
  int _viewportSearchReqId = 0;

  int _mapModeIndex = 3;

  static const String _kakaoApiKey = 'f93a0dfc8ddbcbd58a4c74a1b8434cdb';
  static const int _maxMapRestaurants = 50;
  static const int _categoryRequestSize = 15;
  static const Duration _viewportDebounce = Duration(milliseconds: 600);
  static const int _refreshDistanceMeters = 150;
  static const double _refreshZoomDelta = 0.2;
  static const List<String> _viewportCategoryCodes = ['FD6', 'CE7'];

  static const _initialCenter = LatLng(37.5245, 127.0370);
  static const _initialZoom = 14.0;

  List<RestaurantModel>? _viewportRestaurants;
  String? _viewportSearchError;
  LatLng? _lastSearchedCenter;
  double? _lastSearchedZoom;
  LatLng _latestMapCenter = _initialCenter;
  double _latestMapZoom = _initialZoom;
  bool _isMapReady = false;

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
    _viewportSearchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final bookmarkedRestaurants = ref.watch(bookmarkRestaurantsProvider);
    final mapMode = _currentMapMode();
    final displayRestaurants = _reduceRestaurantOverdraw(
      restaurants: _viewportRestaurants,
      zoom: _latestMapZoom,
    );
    final isSelectedBookmarked = selectedRestaurant != null &&
        bookmarkedRestaurants.any((item) => item.id == selectedRestaurant.id);

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
              onPositionChanged: (camera, hasGesture) {
                _updateLatestMapCamera(camera);
                _onViewportChanged(camera, hasGesture: hasGesture);
              },
              onMapEvent: (event) {
                _updateLatestMapCamera(event.camera);
                _onMapEvent(event);
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
                  ...displayRestaurants.map((restaurant) {
                    return Marker(
                      point: LatLng(restaurant.latitude, restaurant.longitude),
                      width: 36,
                      height: 36,
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
                    color: Colors.black.withOpacity(0.75),
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
              onLayerTap: () {
                _cycleMapMode();
              },
              onZoomIn: () => _zoomMap(1),
              onZoomOut: () => _zoomMap(-1),
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

  void _updateLatestMapCamera(MapCamera camera) {
    _latestMapCenter = camera.center;
    _latestMapZoom = camera.zoom;
    _isMapReady = true;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('링크가 복사되었습니다'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _zoomMap(double delta) {
    if (!_isMapReady) return;
    _mapController.move(
      _latestMapCenter,
      _latestMapZoom + delta,
    );
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd ||
        event is MapEventDoubleTapZoomEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventRotateEnd ||
        event is MapEventNonRotatedSizeChange) {
      _onViewportChanged(event.camera, hasGesture: false, force: true);
    }
  }

  void _onViewportChanged(
    MapCamera camera, {
    required bool hasGesture,
    bool force = false,
  }) {
    if (hasGesture && !force) return;
    if (camera.nonRotatedSize.x <= 0 || camera.nonRotatedSize.y <= 0) return;
    if (!force && !_shouldRefreshViewport(camera.center, camera.zoom)) return;

    final radiusMeters = _calculateViewportRadius(
      camera.visibleBounds,
      camera.center,
    );
    if (radiusMeters <= 0) return;

    _viewportSearchTimer?.cancel();
    _viewportSearchTimer = Timer(_viewportDebounce, () {
      if (!mounted) return;
      _searchViewportRestaurants(
        center: camera.center,
        zoom: camera.zoom,
        radiusMeters: radiusMeters,
      );
    });
  }

  bool _shouldRefreshViewport(LatLng center, double zoom) {
    if (_lastSearchedCenter == null || _lastSearchedZoom == null) return true;

    final movedMeters = _distance.as(
      LengthUnit.Meter,
      center,
      _lastSearchedCenter!,
    );
    final zoomDelta = (zoom - _lastSearchedZoom!).abs();

    return movedMeters >= _refreshDistanceMeters ||
        zoomDelta >= _refreshZoomDelta;
  }

  int _calculateViewportRadius(LatLngBounds bounds, LatLng center) {
    final northEast = bounds.northEast;
    final southWest = bounds.southWest;
    final northWest = LatLng(northEast.latitude, southWest.longitude);
    final southEast = LatLng(southWest.latitude, northEast.longitude);

    final candidates = [
      _distance.as(LengthUnit.Meter, center, northWest),
      _distance.as(LengthUnit.Meter, center, southEast),
      _distance.as(LengthUnit.Meter, center, northEast),
      _distance.as(LengthUnit.Meter, center, southWest),
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
    required LatLng center,
    required double zoom,
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
          'display': '20',
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
        _lastSearchedZoom = zoom;
      });
    } catch (e) {
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
    required double zoom,
  }) {
    final source = restaurants ?? const <RestaurantModel>[];
    if (source.isEmpty) return const [];

    final maxMarkers = _maxMapMarkersByZoom(zoom);
    if (source.length <= maxMarkers) return List.of(source);

    final minCellMeters = _markerCellSizeMeters(zoom);
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

  int _maxMapMarkersByZoom(double zoom) {
    if (zoom <= 11.9) return 15;
    if (zoom <= 12.9) return 25;
    if (zoom <= 13.9) return 40;
    return _maxMapRestaurants;
  }

  double _markerCellSizeMeters(double zoom) {
    if (zoom <= 11.9) return 800;
    if (zoom <= 12.9) return 400;
    if (zoom <= 13.9) return 200;
    if (zoom <= 14.9) return 100;
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

  void _cycleMapMode() {
    if (_mapTileModes.isEmpty) return;

    setState(() {
      _mapModeIndex = (_mapModeIndex + 1) % _mapTileModes.length;
    });
  }

  void _moveToCurrentLocation() {
    _syncCurrentLocationToProvider();
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
