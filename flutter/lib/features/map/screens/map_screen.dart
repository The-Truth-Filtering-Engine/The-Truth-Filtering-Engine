import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../bookmarks/bookmark_provider.dart';
import '../models/map_point.dart';
import '../models/restaurant_model.dart';
import '../map_provider.dart';
import '../widgets/kakao_map_view.dart';
import '../widgets/map_control_buttons.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/restaurant_bottom_sheet.dart';
import '../../../screens/restaurant_list_screen.dart';
import '../restaurant_detail/restaurant_detail_screen.dart';
import '../../search/search_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSettings;
  final ValueChanged<int>? onSelectTab;

  const MapScreen({super.key, this.onOpenSettings, this.onSelectTab});

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

  static const _initialCenter =
      MapPoint(latitude: 37.5245, longitude: 127.0370);
  static const _initialLevel = 4;
  static const _mapCategoryChips = <_MapCategoryChipData>[
    _MapCategoryChipData(
      label: '백반',
      keywords: ['백반', '집밥', '가정식'],
      icon: Icons.rice_bowl_rounded,
    ),
    _MapCategoryChipData(
      label: '한식',
      keywords: ['한식', '국밥', '찌개', '전골', '냉면'],
      icon: Icons.soup_kitchen_rounded,
    ),
    _MapCategoryChipData(
      label: '일식',
      keywords: ['일식', '초밥', '라멘', '돈카츠', '우동'],
      icon: Icons.set_meal_rounded,
    ),
    _MapCategoryChipData(
      label: '중식',
      keywords: ['중식', '짜장면', '짬뽕', '마라탕', '훠궈'],
      icon: Icons.ramen_dining_rounded,
    ),
    _MapCategoryChipData(
      label: '양식',
      keywords: ['양식', '파스타', '스테이크', '피자', '햄버거', '치킨'],
      icon: Icons.local_pizza_rounded,
    ),
    _MapCategoryChipData(
      label: '세계',
      keywords: ['세계음식', '쌀국수', '커리', '멕시칸', '인도', '태국', '베트남', '터키'],
      icon: Icons.public_rounded,
    ),
    _MapCategoryChipData(
      label: '뷔페',
      keywords: ['뷔페', '샐러드바', '무한리필'],
      icon: Icons.table_restaurant_rounded,
    ),
    _MapCategoryChipData(
      label: '야식',
      keywords: ['야식', '심야', '술안주'],
      icon: Icons.nightlife_rounded,
    ),
    _MapCategoryChipData(
      label: '후식',
      keywords: ['카페', '베이커리', '디저트', '아이스크림', '음료'],
      icon: Icons.local_cafe_rounded,
    ),
    _MapCategoryChipData(
      label: '분식',
      keywords: ['분식', '떡볶이', '김밥', '튀김', '순대'],
      icon: Icons.fastfood_rounded,
    ),
    _MapCategoryChipData(
      label: '채식',
      keywords: ['샐러드', '포케', '비건', '채식', '건강식'],
      icon: Icons.eco_rounded,
    ),
    _MapCategoryChipData(
      label: '회식',
      keywords: ['고기', '구이', '해산물', '횟집', '술집', '해장'],
      icon: Icons.groups_rounded,
    ),
    _MapCategoryChipData(
      label: '급식',
      keywords: ['구내식당', '학생식당', '사내식당', '직원식당'],
      icon: Icons.business_rounded,
    ),
    _MapCategoryChipData(
      label: '특식',
      keywords: ['보양식', '삼계탕', '장어', '추어탕', '갈비탕', '전복죽'],
      icon: Icons.workspace_premium_rounded,
    ),
    _MapCategoryChipData(
      label: '코스',
      keywords: ['고급요리', '파인다이닝', '오마카세', '코스요리', '맡김차림', '런치코스', '디너코스'],
      icon: Icons.restaurant_rounded,
    ),
  ];

  List<RestaurantModel>? _viewportRestaurants;
  String? _viewportSearchError;
  MapPoint? _lastSearchedCenter;
  int? _lastSearchedLevel;
  String? _lastSearchedCategoryLabel;
  KakaoMapCamera? _latestCamera;
  _MapCategoryChipData? _selectedMapCategory;
  int _latestMapLevel = _initialLevel;
  bool _isLayerToggled = false;

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
    ref.listen<RestaurantModel?>(mapFocusRestaurantProvider, (previous, next) {
      if (next == null) return;

      ref.read(selectedRestaurantProvider.notifier).state = next;
      setState(() {
        _viewportRestaurants = _appendRestaurantIfMissing(
          _viewportRestaurants,
          next,
        );
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapViewKey.currentState?.moveTo(
          MapPoint(latitude: next.latitude, longitude: next.longitude),
          level: 0,
        );
        setState(() {
          _isLayerToggled = false;
        });
      });
    });

    final selectedRestaurant = ref.watch(selectedRestaurantProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final focusedRestaurant = _selectedMapCategory == null
        ? ref.watch(mapFocusRestaurantProvider)
        : null;
    final bookmarkedRestaurants = ref.watch(bookmarkRestaurantsProvider);
    final displayRestaurants = _reduceRestaurantOverdraw(
      restaurants: _appendRestaurantIfMissing(
        _viewportRestaurants,
        focusedRestaurant,
      ),
      level: _latestMapLevel,
    );
    final isSelectedBookmarked = selectedRestaurant != null &&
        bookmarkedRestaurants.any(
          (item) =>
              item.effectiveStoreId == selectedRestaurant.effectiveStoreId,
        );

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
                onTap: () {
                  final currentLocation = ref.read(currentLocationProvider);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(
                        initialLatitude: currentLocation?.latitude,
                        initialLongitude: currentLocation?.longitude,
                        onSelectTab: widget.onSelectTab,
                        onViewPlace: _showRestaurantFromSearchResult,
                      ),
                    ),
                  );
                },
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
                        onViewPlace: _showRestaurantFromSearchResult,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.paddingOf(context).top + 66,
            child: PointerInterceptor(
              child: _MapCategoryChipRow(
                chips: _mapCategoryChips,
                selectedLabel: _selectedMapCategory?.label,
                onSelected: _openMapCategory,
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: selectedRestaurant != null ? 230 : 100,
            child: PointerInterceptor(
              child: MapControlButtons(
                onLocationTap: _moveToCurrentLocation,
                onLayerTap: _toggleLayer,
                onZoomIn: () => _mapViewKey.currentState?.zoomIn(),
                onZoomOut: () => _mapViewKey.currentState?.zoomOut(),
                isLayerToggled: _isLayerToggled,
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
                    final alreadyBookmarked = previous.any(
                      (item) =>
                          item.effectiveStoreId ==
                          selectedRestaurant.effectiveStoreId,
                    );
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
                  onCallTap: () {
                    _copyRestaurantPhone(selectedRestaurant, context);
                  },
                  onRouteTap: () async {
                    final link = selectedRestaurant.placeUrl?.trim();
                    if (link != null && link.isNotEmpty) {
                      final uri = Uri.parse(link);
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('길찾기 링크가 없습니다')),
                      );
                    }
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

  void _showRestaurantFromSearchResult(RestaurantModel restaurant) {
    setState(() {
      _selectedMapCategory = null;
      _lastSearchedCategoryLabel = null;
    });
    ref.read(mapFocusRestaurantProvider.notifier).state = restaurant;
    ref.read(selectedRestaurantProvider.notifier).state = restaurant;
  }

  void _openMapCategory(_MapCategoryChipData category) {
    final shouldClear = _selectedMapCategory?.label == category.label;
    final nextCategory = shouldClear ? null : category;

    _viewportSearchTimer?.cancel();
    setState(() {
      _selectedMapCategory = nextCategory;
      _viewportRestaurants = const [];
      _viewportSearchError = null;
      _lastSearchedCenter = null;
      _lastSearchedLevel = null;
      _lastSearchedCategoryLabel = null;
    });

    ref.read(selectedRestaurantProvider.notifier).state = null;
    ref.read(mapFocusRestaurantProvider.notifier).state = null;

    _refreshRestaurantsForCurrentViewport(category: nextCategory);
  }

  void _onCameraIdle(KakaoMapCamera camera) {
    _latestCamera = camera;
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

  Future<void> _copyRestaurantPhone(
    RestaurantModel restaurant,
    BuildContext context,
  ) async {
    final phone = restaurant.phone?.trim();
    if (phone == null || phone.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('등록된 전화번호가 없습니다'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('전화번호가 복사되었습니다'),
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
        category: _selectedMapCategory,
      );
    });
  }

  bool _shouldRefreshViewport(MapPoint center, int level) {
    if (_lastSearchedCenter == null || _lastSearchedLevel == null) return true;

    final movedMeters = distanceMeters(center, _lastSearchedCenter!);
    final levelChanged = level != _lastSearchedLevel;
    final categoryChanged =
        _selectedMapCategory?.label != _lastSearchedCategoryLabel;

    return categoryChanged ||
        movedMeters >= _refreshDistanceMeters ||
        levelChanged;
  }

  int _calculateViewportRadius(MapBounds bounds, MapPoint center) {
    final northEast = bounds.northEast;
    final southWest = bounds.southWest;
    final northWest =
        MapPoint(latitude: northEast.latitude, longitude: southWest.longitude);
    final southEast =
        MapPoint(latitude: southWest.latitude, longitude: northEast.longitude);

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
    _MapCategoryChipData? category,
  }) async {
    final requestId = ++_viewportSearchReqId;
    if (!mounted) return;

    setState(() => _viewportSearchError = null);

    try {
      final uri = category == null
          ? BackendConfig.uri('/places/nearby-restaurants', queryParameters: {
              'lat': center.latitude.toString(),
              'lng': center.longitude.toString(),
              'radius': radiusMeters.toString(),
              'display': '10',
            })
          : BackendConfig.uri('/places/search-restaurants', queryParameters: {
              'query': category.searchQuery,
              'lat': center.latitude.toString(),
              'lng': center.longitude.toString(),
              'radius': radiusMeters.toString(),
              'display': '10',
            });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        if (!mounted || requestId != _viewportSearchReqId) return;
        setState(() => _viewportSearchError = '서버 에러 (${response.statusCode})');
        return;
      }

      final data = jsonDecode(response.body);
      final List items = data['restaurants'] ?? [];
      if (category != null && category.keywords.length > 1) {
        final seenIds = {
          for (final item in items)
            if (item is Map && item['id'] != null) item['id'].toString(),
        };

        for (final keyword in category.keywords.skip(1)) {
          final keywordUri =
              BackendConfig.uri('/places/search-restaurants', queryParameters: {
            'query': keyword,
            'lat': center.latitude.toString(),
            'lng': center.longitude.toString(),
            'radius': radiusMeters.toString(),
            'display': '10',
          });
          final keywordResponse = await http.get(keywordUri);
          if (keywordResponse.statusCode != 200) {
            if (!mounted || requestId != _viewportSearchReqId) return;
            setState(
              () => _viewportSearchError =
                  '서버 오류 (${keywordResponse.statusCode})',
            );
            return;
          }

          final keywordData = jsonDecode(keywordResponse.body);
          final List keywordItems = keywordData['restaurants'] ?? [];
          for (final item in keywordItems) {
            if (item is! Map || item['id'] == null) continue;
            final id = item['id'].toString();
            if (seenIds.contains(id)) continue;
            seenIds.add(id);
            items.add(item);
          }
        }
      }

      final restaurants = items
          .map((item) => RestaurantModel(
                id: item['id']?.toString() ?? '',
                name: item['name'] ?? '',
                category: item['category'] ?? '음식점',
                address: item['address'] ?? '',
                truthScore: _mockTrustScore(item['id']?.toString() ?? ''),
                distance: item['distance'] ?? 0,
                phone: item['phone']?.toString(),
                placeUrl: item['link'],
                reviewSummary: item['name'] ?? '검색 결과',
                imageUrl: null,
                latitude: (item['lat'] as num).toDouble(),
                longitude: (item['lng'] as num).toDouble(),
              ))
          .toList();
      restaurants.sort((a, b) => a.distance.compareTo(b.distance));
      final visibleRestaurants = restaurants.take(_maxMapRestaurants).toList();

      if (!mounted || requestId != _viewportSearchReqId) return;

      final focusedRestaurant =
          category == null ? ref.read(mapFocusRestaurantProvider) : null;
      final mergedRestaurants = _appendRestaurantIfMissing(
            visibleRestaurants,
            focusedRestaurant,
          ) ??
          visibleRestaurants;
      final selectedRestaurant = ref.read(selectedRestaurantProvider);
      if (selectedRestaurant != null &&
          mergedRestaurants.every((r) => r.id != selectedRestaurant.id)) {
        ref.read(selectedRestaurantProvider.notifier).state = null;
      }

      setState(() {
        _viewportRestaurants = mergedRestaurants;
        _viewportSearchError = category != null && mergedRestaurants.isEmpty
            ? '${category.label} 주변 결과가 없습니다'
            : null;
        _lastSearchedCenter = center;
        _lastSearchedLevel = level;
        _lastSearchedCategoryLabel = category?.label;
      });
    } catch (_) {
      if (!mounted || requestId != _viewportSearchReqId) return;
      setState(() => _viewportSearchError = '네트워크 에러가 발생했습니다');
    }
  }

  void _refreshRestaurantsForCurrentViewport({
    _MapCategoryChipData? category,
  }) {
    final camera = _latestCamera;
    final center =
        camera?.center ?? ref.read(currentLocationProvider) ?? _initialCenter;
    final level = camera?.level ?? _latestMapLevel;
    final radiusMeters = camera == null
        ? 1500
        : _calculateViewportRadius(camera.bounds, camera.center);

    if (radiusMeters <= 0) return;

    _searchViewportRestaurants(
      center: center,
      level: level,
      radiusMeters: radiusMeters,
      category: category,
    );
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

  List<RestaurantModel>? _appendRestaurantIfMissing(
    List<RestaurantModel>? restaurants,
    RestaurantModel? restaurant,
  ) {
    if (restaurant == null) return restaurants;

    final source = restaurants ?? const <RestaurantModel>[];
    if (source.any((item) => item.id == restaurant.id)) return restaurants;

    return [restaurant, ...source];
  }

  void _moveToCurrentLocation() {
    _syncCurrentLocationToProvider();
  }

  void _toggleLayer() {
    _mapViewKey.currentState?.toggleMapType();
    setState(() {
      _isLayerToggled = !_isLayerToggled;
    });
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
      final location =
          MapPoint(latitude: position.latitude, longitude: position.longitude);
      ref.read(currentLocationProvider.notifier).state = location;
      _mapViewKey.currentState?.moveTo(location, level: _initialLevel);
    } catch (_) {}
  }
}

class _MapCategoryChipRow extends StatelessWidget {
  const _MapCategoryChipRow({
    required this.chips,
    this.selectedLabel,
    required this.onSelected,
  });

  final List<_MapCategoryChipData> chips;
  final String? selectedLabel;
  final ValueChanged<_MapCategoryChipData> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
          },
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          primary: false,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final chip = chips[index];
            return _MapCategoryChip(
              data: chip,
              isSelected: chip.label == selectedLabel,
              onTap: () => onSelected(chip),
            );
          },
        ),
      ),
    );
  }
}

class _MapCategoryChip extends StatelessWidget {
  const _MapCategoryChip({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _MapCategoryChipData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const normalBackground = Color(0xFFF2F3F5);
    const selectedBackground = AppColors.success50;
    const normalBorder = Color(0xFFD9DDE3);
    const selectedBorder = AppColors.success400;
    final contentColor =
        isSelected ? AppColors.success700 : AppColors.textSecondary;

    return Material(
      color: isSelected ? selectedBackground : normalBackground,
      borderRadius: BorderRadius.circular(17),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isSelected ? selectedBorder : normalBorder,
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                data.icon,
                size: 14,
                color: contentColor,
              ),
              const SizedBox(width: 6),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      isSelected ? AppColors.success700 : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapCategoryChipData {
  const _MapCategoryChipData({
    required this.label,
    required this.keywords,
    required this.icon,
  });

  final String label;
  final List<String> keywords;
  final IconData icon;

  String get searchQuery => keywords.first;
}
