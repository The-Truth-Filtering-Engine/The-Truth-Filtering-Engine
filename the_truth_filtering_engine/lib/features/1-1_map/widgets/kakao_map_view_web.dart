// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

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
  static Completer<void>? _sdkLoader;

  late final String _viewType;
  late final html.DivElement _container;

  js.JsObject? _map;
  bool _mapReady = false;
  bool _roadmapType = true;
  String? _loadError;
  final List<js.JsObject> _restaurantOverlays = [];
  js.JsObject? _currentLocationOverlay;

  @override
  void initState() {
    super.initState();
    _viewType = 'kakao-map-${DateTime.now().microsecondsSinceEpoch}';
    _container = html.DivElement()
      ..id = _viewType
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0'
      ..style.cursor = 'pointer';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _container,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
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

      // 현재 위치가 처음으로 설정되었을 때 지도를 해당 위치로 이동
      if (oldWidget.currentLocation == null && widget.currentLocation != null) {
        moveTo(widget.currentLocation!);
      }
    }
  }

  @override
  void dispose() {
    _clearRestaurantOverlays();
    _currentLocationOverlay?.callMethod('setMap', [null]);
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      final kakaoJsKey = await _fetchKakaoJsKey();
      if (kakaoJsKey.isEmpty) {
        throw StateError('백엔드 /config에 KAKAO_JS_KEY가 없습니다');
      }

      await _loadKakaoSdk(kakaoJsKey);
      if (!mounted) return;

      final maps = _maps;
      // 현재 위치가 이미 확보되어 있다면 초기 위치로 사용, 없으면 기본값 사용
      final initialPoint = widget.currentLocation ?? widget.initialCenter;
      final center = _latLng(initialPoint);
      final options = js.JsObject.jsify({'level': widget.initialLevel});
      options['center'] = center;

      _map = js.JsObject(maps['Map'], [_container, options]);
      _mapReady = true;

      _addMapListener('idle', _emitCameraIdle);
      _addMapListener('click', () {
        widget.onMapTap?.call();
      });

      _syncRestaurantOverlays();
      _syncCurrentLocationOverlay();
      _emitCameraIdle();

      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || _map == null) return;
        _map!.callMethod('relayout');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    }
  }

  static Future<String> _fetchKakaoJsKey() async {
    final response = await html.HttpRequest.getString(
      '$_backendBaseUrl/config',
    );
    final decoded = jsonDecode(response) as Map<String, dynamic>;
    return decoded['kakaoJsKey']?.toString().trim() ?? '';
  }

  static Future<void> _loadKakaoSdk(String kakaoJsKey) {
    if (_sdkLoader != null) return _sdkLoader!.future;

    _sdkLoader = Completer<void>();
    if (js.context.hasProperty('kakao')) {
      _loadKakaoMaps();
      return _sdkLoader!.future;
    }

    final script = html.ScriptElement()
      ..src =
          'https://dapi.kakao.com/v2/maps/sdk.js?appkey=$kakaoJsKey&autoload=false'
      ..async = true;
    script.onLoad.first.then((_) => _loadKakaoMaps());
    script.onError.first.then((_) {
      if (!(_sdkLoader?.isCompleted ?? true)) {
        _sdkLoader?.completeError(StateError('Kakao 지도 SDK 로드 실패'));
      }
    });
    html.document.head?.append(script);
    return _sdkLoader!.future;
  }

  static void _loadKakaoMaps() {
    final maps = js.context['kakao']['maps'] as js.JsObject;
    maps.callMethod('load', [
      (() {
        if (!(_sdkLoader?.isCompleted ?? true)) {
          _sdkLoader?.complete();
        }
      }).toJS,
    ]);
  }

  js.JsObject get _maps => js.context['kakao']['maps'] as js.JsObject;

  js.JsObject _latLng(MapPoint point) {
    return js.JsObject(_maps['LatLng'], [point.latitude, point.longitude]);
  }

  void _addMapListener(String eventName, void Function() callback) {
    _maps['event'].callMethod('addListener', [
      _map,
      eventName,
      callback.toJS,
    ]);
  }

  void _syncRestaurantOverlays() {
    _clearRestaurantOverlays();
    if (_map == null) return;

    for (final restaurant in widget.restaurants) {
      final marker = _buildRestaurantMarker(restaurant);
      final options = js.JsObject.jsify({
        'content': marker,
        'xAnchor': 0.5,
        'yAnchor': 0.5,
      });
      options['position'] = _latLng(
        MapPoint(restaurant.latitude, restaurant.longitude),
      );

      final overlay = js.JsObject(_maps['CustomOverlay'], [options]);
      overlay.callMethod('setMap', [_map]);
      _restaurantOverlays.add(overlay);
    }
  }

  html.Element _buildRestaurantMarker(RestaurantModel restaurant) {
    final button = html.ButtonElement()
      ..type = 'button'
      ..title = restaurant.name
      ..text = _markerEmoji(restaurant)
      ..style.width = '28px'
      ..style.height = '28px'
      ..style.padding = '0'
      ..style.borderRadius = '50%'
      ..style.border = '1.5px solid white'
      ..style.backgroundColor = _markerColor(restaurant)
      ..style.boxShadow = '0 2px 6px rgba(0,0,0,.18)'
      ..style.cursor = 'pointer'
      ..style.fontSize = '16px'
      ..style.lineHeight = '25px'
      ..style.textAlign = 'center';

    button.onClick.listen((event) {
      event.stopPropagation();
      widget.onMarkerTap(restaurant);
    });

    return button;
  }

  void _syncCurrentLocationOverlay() {
    _currentLocationOverlay?.callMethod('setMap', [null]);
    _currentLocationOverlay = null;
    if (_map == null || widget.currentLocation == null) return;

    final outer = html.DivElement()
      ..style.width = '34px'
      ..style.height = '34px'
      ..style.borderRadius = '50%'
      ..style.background = 'rgba(35,160,255,.2)'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center';
    final inner = html.DivElement()
      ..style.width = '14px'
      ..style.height = '14px'
      ..style.borderRadius = '50%'
      ..style.background = '#FF0000';
    outer.append(inner);

    final options = js.JsObject.jsify({
      'content': outer,
      'xAnchor': 0.5,
      'yAnchor': 0.5,
    });
    options['position'] = _latLng(widget.currentLocation!);

    _currentLocationOverlay = js.JsObject(_maps['CustomOverlay'], [options]);
    _currentLocationOverlay!.callMethod('setMap', [_map]);
  }

  void _clearRestaurantOverlays() {
    for (final overlay in _restaurantOverlays) {
      overlay.callMethod('setMap', [null]);
    }
    _restaurantOverlays.clear();
  }

  void _emitCameraIdle() {
    if (_map == null) return;

    final center = _map!.callMethod('getCenter') as js.JsObject;
    final bounds = _map!.callMethod('getBounds') as js.JsObject;
    final southWest = bounds.callMethod('getSouthWest') as js.JsObject;
    final northEast = bounds.callMethod('getNorthEast') as js.JsObject;
    final level = (_map!.callMethod('getLevel') as num).toInt();

    widget.onCameraIdle(
      KakaoMapCamera(
        center: _pointFromLatLng(center),
        bounds: MapBounds(
          southWest: _pointFromLatLng(southWest),
          northEast: _pointFromLatLng(northEast),
        ),
        level: level,
      ),
    );
  }

  MapPoint _pointFromLatLng(js.JsObject latLng) {
    return MapPoint(
      (latLng.callMethod('getLat') as num).toDouble(),
      (latLng.callMethod('getLng') as num).toDouble(),
    );
  }

  void moveTo(MapPoint point, {int? level}) {
    if (_map == null) return;
    _map!.callMethod('setCenter', [_latLng(point)]);
    if (level != null) {
      _map!.callMethod('setLevel', [level]);
    }
    _emitCameraIdle();
  }

  void zoomIn() {
    if (_map == null) return;
    final level = (_map!.callMethod('getLevel') as num).toInt();
    _map!.callMethod('setLevel', [level > 1 ? level - 1 : 1]);
  }

  void zoomOut() {
    if (_map == null) return;
    final level = (_map!.callMethod('getLevel') as num).toInt();
    _map!.callMethod('setLevel', [level + 1]);
  }

  void toggleMapType() {
    if (_map == null) return;
    final mapTypeId = _roadmapType
        ? _maps['MapTypeId']['SKYVIEW']
        : _maps['MapTypeId']['ROADMAP'];
    _map!.callMethod('setMapTypeId', [mapTypeId]);
    _roadmapType = !_roadmapType;
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
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
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

    return HtmlElementView(viewType: _viewType);
  }
}
