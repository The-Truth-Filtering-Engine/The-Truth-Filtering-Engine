import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/backend_config.dart';
import '../core/theme/app_theme.dart';
import '../features/map/models/restaurant_model.dart';
import '../features/search/semantic_search_keywords.dart';

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({
    super.key,
    required this.query,
    this.initialLatitude,
    this.initialLongitude,
    required this.onViewPlace,
  });

  final String query;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<RestaurantModel> onViewPlace;

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  late final TextEditingController _queryController;
  late String _query;

  bool _isLoading = true;
  String? _errorMessage;
  List<RestaurantModel> _results = [];
  String _sortBy = 'truth_score';

  @override
  void initState() {
    super.initState();
    _query = widget.query.trim();
    _queryController = TextEditingController(text: _query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search(_query);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _errorMessage = '검색어를 2글자 이상 입력해주세요';
        _isLoading = false;
      });
      return;
    }

    _query = trimmed;
    if (_queryController.text != _query) {
      _queryController.text = _query;
      _queryController.selection = TextSelection.collapsed(
        offset: _queryController.text.length,
      );
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }

      final (lat, lng) = await _resolveLocation();
      final queries = await semanticRestaurantQueriesFor(trimmed);
      final restaurantsById = <String, RestaurantModel>{};

      for (final query in queries) {
        final params = <String, String>{'query': query};
        if (lat != null) params['lat'] = lat.toString();
        if (lng != null) params['lng'] = lng.toString();

        final response = await http.get(
          BackendConfig.apiUri('/search/results', queryParameters: params),
          headers: {'Authorization': 'Bearer $token'},
        );

        final decoded = _decodeBody(response);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final detail = decoded is Map ? decoded['detail']?.toString() : null;
          if (!mounted) return;
          setState(() {
            _errorMessage = detail ?? '검색 API 오류 (${response.statusCode})';
            _isLoading = false;
          });
          return;
        }

        final rows = decoded is Map ? decoded['results'] : null;
        final restaurants = rows is List
            ? rows
                .whereType<Map>()
                .map((item) => _restaurantFromResult(item))
                .toList()
            : <RestaurantModel>[];
        for (final restaurant in restaurants) {
          restaurantsById[restaurant.effectiveStoreId] = restaurant;
        }
      }

      if (!mounted) return;
      setState(() {
        _results = restaurantsById.values.toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '검색 결과를 불러오지 못했습니다';
        _isLoading = false;
      });
    }
  }

  Object? _decodeBody(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (text.trim().isEmpty) return null;
    return jsonDecode(text);
  }

  RestaurantModel _restaurantFromResult(Map item) {
    final restaurant = RestaurantModel.fromJson(
      Map<String, dynamic>.from(item),
    );
    return restaurant.copyWith(
      truthScore: _mockTruthScore(restaurant.effectiveStoreId),
      reviewSummary: restaurant.reviewSummary.isNotEmpty
          ? restaurant.reviewSummary
          : restaurant.name,
    );
  }

  Future<(double?, double?)> _resolveLocation() async {
    var lat = widget.initialLatitude;
    var lng = widget.initialLongitude;
    if (lat != null && lng != null) return (lat, lng);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return (lat, lng);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return (lat, lng);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (_) {}

    return (lat, lng);
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.length < 2) {
      setState(() => _errorMessage = '검색어를 2글자 이상 입력해주세요');
      return;
    }
    _search(query);
  }

  int _mockTruthScore(String id) {
    final hash = id.hashCode.abs() % 40;
    return 60 + hash;
  }

  List<RestaurantModel> get _sortedResults {
    final list = [..._results];
    switch (_sortBy) {
      case 'distance':
        list.sort((a, b) => a.distance.compareTo(b.distance));
        break;
      case 'truth_score':
      default:
        list.sort((a, b) => b.truthScore.compareTo(a.truthScore));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _SearchField(
          controller: _queryController,
          onSubmitted: _submitSearch,
          onSearchTap: () => _submitSearch(_queryController.text),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(thickness: 0.5, height: 0.5, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => const _CardSkeleton(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _search(_query),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final results = _sortedResults;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '"$_query" ${results.length}개',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isDense: true,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'distance', child: Text('거리순')),
                    DropdownMenuItem(value: 'truth_score', child: Text('정확도순')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sortBy = value);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final restaurant = results[index];
                    return _RestaurantCard(
                      restaurant: restaurant,
                      onTap: () {
                        widget.onViewPlace(restaurant);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 52,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 14),
          Text(
            '"$_query" 검색 결과가 없습니다',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '다른 검색어로 다시 시도해보세요',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onSearchTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: AppColors.textHint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '음식점 또는 메뉴를 검색',
                hintStyle: TextStyle(color: AppColors.textHint),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              size: 16,
              color: AppColors.primary500,
            ),
            onPressed: onSearchTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '검색',
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  final RestaurantModel restaurant;
  final VoidCallback onTap;

  Color get _trustColor {
    if (restaurant.truthScore >= 80) return const Color(0xFF4CBB87);
    if (restaurant.truthScore >= 60) return const Color(0xFFF5A623);
    return const Color(0xFFE85C5C);
  }

  Color get _trustBgColor {
    if (restaurant.truthScore >= 80) return const Color(0xFFE8F6EE);
    if (restaurant.truthScore >= 60) return const Color(0xFFFEF5E7);
    return const Color(0xFFFEF0F0);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                size: 28,
                color: Color(0xFFCCBBAA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.primaryCategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _TruthBadge(
                        score: restaurant.truthScore,
                        color: _trustColor,
                        backgroundColor: _trustBgColor,
                      ),
                      const SizedBox(width: 8),
                      if (restaurant.distance > 0)
                        Text(
                          '${restaurant.distance}m',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _TruthBadge extends StatelessWidget {
  const _TruthBadge({
    required this.score,
    required this.color,
    required this.backgroundColor,
  });

  final int score;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFECECF4),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 140, height: 14, color: const Color(0xFFECECF4)),
                const SizedBox(height: 8),
                Container(
                    width: 90, height: 12, color: const Color(0xFFECECF4)),
                const SizedBox(height: 8),
                Container(
                    width: 180, height: 12, color: const Color(0xFFECECF4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
