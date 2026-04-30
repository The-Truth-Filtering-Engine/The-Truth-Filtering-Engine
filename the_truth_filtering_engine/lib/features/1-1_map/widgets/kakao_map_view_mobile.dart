import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_colors.dart';
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
  static const _backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  late final WebViewController _controller;
  bool _mapReady = false;
  bool _roadmapType = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      final kakaoJsKey = await _fetchKakaoJsKey();
      if (kakaoJsKey.isEmpty) {
        throw Exception('백엔드 /config에 KAKAO_JS_KEY가 없습니다');
      }

      _controller = WebViewController()
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
                (data['lat'] as num).toDouble(),
                (data['lng'] as num).toDouble(),
              );
              final sw = MapPoint(
                (data['swLat'] as num).toDouble(),
                (data['swLng'] as num).toDouble(),
              );
              final ne = MapPoint(
                (data['neLat'] as num).toDouble(),
                (data['neLng'] as num).toDouble(),
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
          ),
        );

      final htmlContent = _buildHtml(kakaoJsKey);
      await _controller.loadHtmlString(htmlContent);
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
    }
  }

  Future<String> _fetchKakaoJsKey() async {
    try {
      final response = await http.get(Uri.parse('$_backendBaseUrl/config'));
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
        body, html, #map { width: 100%; height: 100%; margin: 0; padding: 0; }
    </style>
</head>
<body>
    <div id="map"></div>
    <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$apiKey&autoload=false"></script>
    <script>
        var map;
        var markers = [];
        var currentLocationOverlay;

        kakao.maps.load(function() {
            var container = document.getElementById('map');
            var options = {
                center: new kakao.maps.LatLng(${initialPoint.latitude}, ${initialPoint.longitude}),
                level: ${widget.initialLevel}
            };
            map = new kakao.maps.Map(container, options);

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
            map.setCenter(loc);
            if (level) map.setLevel(level);
        }

        function setMarkers(restaurantsJson) {
            // Clear existing markers
            markers.forEach(m => m.setMap(null));
            markers = [];

            var restaurants = JSON.parse(restaurantsJson);
            restaurants.forEach(function(r) {
                var content = document.createElement('div');
                content.style.width = '28px';
                content.style.height = '28px';
                content.style.borderRadius = '50%';
                content.style.border = '1.5px solid white';
                content.style.backgroundColor = r.color;
                content.style.boxShadow = '0 2px 6px rgba(0,0,0,.18)';
                content.style.display = 'flex';
                content.style.alignItems = 'center';
                content.style.justifyContent = 'center';
                content.style.fontSize = '16px';
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
            inner.style.background = '#FF0000';
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
            if (type === 'SKYVIEW') {
                map.setMapTypeId(kakao.maps.MapTypeId.SKYVIEW);
            } else {
                map.setMapTypeId(kakao.maps.MapTypeId.ROADMAP);
            }
        }

        function zoomIn() {
            map.setLevel(map.getLevel() - 1);
        }

        function zoomOut() {
            map.setLevel(map.getLevel() + 1);
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
    }
  }

  void _syncRestaurantOverlays() {
    final restaurantsJson = jsonEncode(widget.restaurants.map((r) {
      return {
        'id': r.id,
        'lat': r.latitude,
        'lng': r.longitude,
        'emoji': _markerEmoji(r),
        'color': _markerColor(r),
      };
    }).toList());
    _controller.runJavaScript('setMarkers(\'$restaurantsJson\')');
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
    _controller.runJavaScript('setMapType(\'${_roadmapType ? 'ROADMAP' : 'SKYVIEW'}\')');
  }

  String _markerEmoji(RestaurantModel restaurant) {
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

  String _markerColor(RestaurantModel restaurant) {
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

  @override
  Widget build(BuildContext context) {
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
