import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ✅ iOS에서 WebView 초기화에 필요 (webview_flutter_wkwebview)
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../bookmarks/bookmark_options.dart';
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
  late final WebViewController _controller;
  bool _mapReady = false;
  bool _roadmapType = true;
  String? _loadError;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();

    // ✅ iOS(WKWebView) / Android(WebView) 플랫폼별 파라미터 설정
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (message) {
          final data = jsonDecode(message.message);
          final type = data['type'] as String;

          if (type == 'markerTap') {
            final id = data['id'] as String;
            final restaurant = widget.restaurants.firstWhere((r) => r.id == id);
            widget.onMarkerTap(restaurant);
          } else if (type == 'cameraIdle') {
            final center = MapPoint(
              latitude: (data['lat'] as num).toDouble(),
              longitude: (data['lng'] as num).toDouble(),
            );
            final sw = MapPoint(
              latitude: (data['swLat'] as num).toDouble(),
              longitude: (data['swLng'] as num).toDouble(),
            );
            final ne = MapPoint(
              latitude: (data['neLat'] as num).toDouble(),
              longitude: (data['neLng'] as num).toDouble(),
            );
            final level = (data['level'] as num).toInt();

            widget.onCameraIdle(
              KakaoMapCamera(
                center: center,
                bounds: MapBounds(southWest: sw, northEast: ne),
                level: level,
              ),
            );
          } else if (type == 'mapTap') {
            widget.onMapTap?.call();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _mapReady = true);
            _syncRestaurantOverlays();
            _syncCurrentLocationOverlay();
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );

    // ✅ iOS WKWebView: 백그라운드 색상 투명 설정
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController).setInspectable(
        true,
      ); // Safari 디버깅 허용 (개발 중 유용)
    }

    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      final kakaoJsKey = await _fetchKakaoJsKey();
      if (kakaoJsKey.isEmpty) {
        throw Exception('백엔드 /config에 KAKAO_JS_KEY가 없습니다');
      }

      final htmlContent = _buildHtml(kakaoJsKey);
      // ✅ iOS에서는 baseUrl 없이 loadHtmlString 사용
      //    (WKWebView는 file:// 기반 baseUrl 필요 or 없음)
      await _controller.loadHtmlString(htmlContent);
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<String> _fetchKakaoJsKey() async {
    try {
      final response = await http
          .get(BackendConfig.uri('/config'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['kakaoJsKey']?.toString().trim() ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching kakaoJsKey: $e');
    }
    return '';
  }

  String _buildHtml(String apiKey) {
    final initialPoint = widget.currentLocation ?? widget.initialCenter;
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        * { -webkit-tap-highlight-color: transparent; }
        body, html, #mapClip { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; }
        #map {
            width: 100%;
            height: 100%;
            backface-visibility: hidden;
        }
    </style>
</head>
<body>
    <div id="mapClip"><div id="map"></div></div>
    <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$apiKey&autoload=false"></script>
    <script>
        var map;
        var markers = [];
        var currentLocationOverlay;
        var isRoadmap = true;
        var MAX_MAP_LEVEL = 12;

        kakao.maps.load(function() {
            var container = document.getElementById('map');
            var options = {
                center: new kakao.maps.LatLng(${initialPoint.latitude}, ${initialPoint.longitude}),
                level: ${widget.initialLevel}
            };
            map = new kakao.maps.Map(container, options);
            applyLevelBounds();

            kakao.maps.event.addListener(map, 'idle', function() {
                var center = map.getCenter();
                var bounds = map.getBounds();
                var sw = bounds.getSouthWest();
                var ne = bounds.getNorthEast();
                
                FlutterChannel.postMessage(JSON.stringify({
                    type: 'cameraIdle',
                    lat: center.getLat(),
                    lng: center.getLng(),
                    swLat: sw.getLat(),
                    swLng: sw.getLng(),
                    neLat: ne.getLat(),
                    neLng: ne.getLng(),
                    level: map.getLevel()
                }));
            });

            kakao.maps.event.addListener(map, 'click', function() {
                FlutterChannel.postMessage(JSON.stringify({ type: 'mapTap' }));
            });
        });

        function moveTo(lat, lng, level) {
            var loc = new kakao.maps.LatLng(lat, lng);
            if (level !== null && level !== undefined) {
                map.setMapTypeId(kakao.maps.MapTypeId.ROADMAP);
                isRoadmap = true;
                applyLevelBounds();
                var targetLevel = Math.min(Math.max(level, 1), MAX_MAP_LEVEL);
                map.setLevel(targetLevel);
            }
            map.panTo(loc);
        }

        function setMarkers(restaurantsJson) {
            markers.forEach(m => m.setMap(null));
            markers = [];

            var restaurants = JSON.parse(restaurantsJson);
            restaurants.forEach(function(r) {
                var content = document.createElement('div');
                content.style.width = '28px';
                content.style.height = '28px';
                content.style.borderRadius = '50%';
                content.style.border = r.border || '1.5px solid white';
                content.style.backgroundColor = r.color;
                content.style.boxShadow = '0 2px 6px rgba(0,0,0,.18)';
                content.style.display = 'flex';
                content.style.alignItems = 'center';
                content.style.justifyContent = 'center';
                content.style.fontSize = '16px';
                content.style.fontWeight = r.fontWeight || '400';
                content.style.color = r.textColor || '';
                content.style.cursor = 'pointer';
                content.innerText = r.emoji;
                content.onclick = function() {
                    FlutterChannel.postMessage(JSON.stringify({
                        type: 'markerTap',
                        id: r.id
                    }));
                };

                var overlay = new kakao.maps.CustomOverlay({
                    position: new kakao.maps.LatLng(r.lat, r.lng),
                    content: content,
                    xAnchor: 0.5,
                    yAnchor: 0.5
                });
                overlay.setMap(map);
                markers.push(overlay);
            });
        }

        function setCurrentLocation(lat, lng) {
            if (currentLocationOverlay) currentLocationOverlay.setMap(null);
            if (!lat || !lng) return;

            var outer = document.createElement('div');
            outer.style.width = '34px';
            outer.style.height = '34px';
            outer.style.borderRadius = '50%';
            outer.style.background = 'rgba(35,160,255,.2)';
            outer.style.display = 'flex';
            outer.style.alignItems = 'center';
            outer.style.justifyContent = 'center';

            var inner = document.createElement('div');
            inner.style.width = '14px';
            inner.style.height = '14px';
            inner.style.borderRadius = '50%';
            inner.style.background = '#2196F3';
            inner.style.border = '2px solid white';
            outer.appendChild(inner);

            currentLocationOverlay = new kakao.maps.CustomOverlay({
                position: new kakao.maps.LatLng(lat, lng),
                content: outer,
                xAnchor: 0.5,
                yAnchor: 0.5
            });
            currentLocationOverlay.setMap(map);
        }

        function setMapType(type) {
            if (type === 'HYBRID') {
                map.setMapTypeId(kakao.maps.MapTypeId.HYBRID);
                isRoadmap = false;
            } else {
                map.setMapTypeId(kakao.maps.MapTypeId.ROADMAP);
                isRoadmap = true;
            }
            applyLevelBounds();
        }

        function applyLevelBounds() {
            if (!map) return;
            map.setMinLevel(isRoadmap ? 1 : 0);
            map.setMaxLevel(MAX_MAP_LEVEL);
        }

        function zoomIn() {
            var minLevel = isRoadmap ? 1 : 0;
            var targetLevel = Math.max(map.getLevel() - 1, minLevel);
            map.setLevel(targetLevel);
        }
        function zoomOut() {
            map.setLevel(Math.min(map.getLevel() + 1, MAX_MAP_LEVEL));
        }
    </script>
</body>
</html>
''';
  }

  @override
  void didUpdateWidget(covariant KakaoMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;

    if (oldWidget.restaurants != widget.restaurants) {
      _syncRestaurantOverlays();
    }
    if (oldWidget.currentLocation != widget.currentLocation) {
      _syncCurrentLocationOverlay();

      if (oldWidget.currentLocation == null && widget.currentLocation != null) {
        moveTo(widget.currentLocation!);
      }
    }
  }

  void _syncRestaurantOverlays() {
    final restaurantsJson = jsonEncode(
      widget.restaurants.map((r) {
        return {
          'id': r.id,
          'lat': r.latitude,
          'lng': r.longitude,
          'emoji': _markerEmoji(r),
          'color': _markerColor(r),
          'textColor': _markerTextColor(r),
          'border': _markerBorder(r),
          'fontWeight': _isFavoriteMarker(r) ? '800' : '400',
        };
      }).toList(),
    );
    // ✅ 작은따옴표 이스케이프 처리
    final escaped = restaurantsJson.replaceAll("'", "\\'");
    _controller.runJavaScript("setMarkers('$escaped')");
  }

  void _syncCurrentLocationOverlay() {
    if (widget.currentLocation != null) {
      _controller.runJavaScript(
        'setCurrentLocation(${widget.currentLocation!.latitude}, ${widget.currentLocation!.longitude})',
      );
    } else {
      _controller.runJavaScript('setCurrentLocation(null, null)');
    }
  }

  void moveTo(MapPoint point, {int? level}) {
    if (!_mapReady) return;
    _controller.runJavaScript(
      'moveTo(${point.latitude}, ${point.longitude}, ${level ?? 'null'})',
    );
  }

  void zoomIn() {
    if (!_mapReady) return;
    _controller.runJavaScript('zoomIn()');
  }

  void zoomOut() {
    if (!_mapReady) return;
    _controller.runJavaScript('zoomOut()');
  }

  void toggleMapType() {
    if (!_mapReady) return;
    _roadmapType = !_roadmapType;
    _controller.runJavaScript(
      "setMapType('${_roadmapType ? 'ROADMAP' : 'HYBRID'}')",
    );
  }

  String _markerEmoji(RestaurantModel restaurant) {
    if (_isFavoriteMarker(restaurant)) {
      return '★';
    }

    final category = restaurant.category;
    final normalized = category.toLowerCase();
    if (category.contains('카페') ||
        normalized.contains('cafe') ||
        normalized.contains('coffee') ||
        normalized.contains('☕')) {
      return '☕';
    }
    return '🍽️';
  }

  bool _isFavoriteMarker(RestaurantModel restaurant) {
    return restaurant.isBookmarked ||
        restaurant.bookmarkColorKey != null ||
        restaurant.bookmarkTopicIds.isNotEmpty;
  }

  String _markerTextColor(RestaurantModel restaurant) {
    return _isFavoriteMarker(restaurant) ? '#FFFFFF' : '';
  }

  String _markerBorder(RestaurantModel restaurant) {
    return '1.5px solid #FFFFFF';
  }

  String _markerColor(RestaurantModel restaurant) {
    if (_isFavoriteMarker(restaurant)) {
      return _bookmarkMarkerColor(restaurant);
    }

    Color color;
    switch (restaurant.markerType) {
      case MarkerType.high:
      case MarkerType.mid:
      case MarkerType.low:
        color = AppColors.markerHigh;
    }
    return '#${color.r.toInt().toRadixString(16).padLeft(2, '0')}'
        '${color.g.toInt().toRadixString(16).padLeft(2, '0')}'
        '${color.b.toInt().toRadixString(16).padLeft(2, '0')}';
  }

  String _bookmarkMarkerColor(RestaurantModel restaurant) {
    final colorKey = BookmarkTopics.colorKeyForTopicIds(
      restaurant.bookmarkTopicIds,
      fallbackColorKey: restaurant.bookmarkColorKey,
    );
    return BookmarkColors.markerHex(colorKey);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const ColoredBox(
        color: Color(0xFFE9EEF1),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return ColoredBox(
        color: const Color(0xFFE9EEF1),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '카카오맵 설정을 불러오지 못했습니다\n$_loadError',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return WebViewWidget(controller: _controller);
  }
}
