import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/theme/app_theme.dart';
import '../features/map/models/restaurant_model.dart';

const _kakaoApiKey = 'f93a0dfc8ddbcbd58a4c74a1b8434cdb';

class RestaurantListScreen extends StatefulWidget {
  final String query;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<RestaurantModel> onViewPlace;

  const RestaurantListScreen({
    super.key,
    required this.query,
    this.initialLatitude,
    this.initialLongitude,
    required this.onViewPlace,
  });

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  late final TextEditingController _queryController;
  late String _query;
  bool _isLoading = true;
  String? _errorMessage;
  List<RestaurantModel> _results = [];
  String _sortBy = 'trust_score';
  final List<String> _sortOptions = ['distance', 'trust_score'];

  @override
  void initState() {
    super.initState();
    _query = widget.query.trim();
    _queryController = TextEditingController(text: _query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _search(_query);
      }
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Please enter a search keyword.';
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

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      double? lat;
      double? lng;

      try {
        lat = widget.initialLatitude;
        lng = widget.initialLongitude;

        if (lat == null || lng == null) {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }

            if (permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always) {
              final position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                ),
              );
              lat = position.latitude;
              lng = position.longitude;
            }
          }
        }
      } catch (_) {
        // 위치 권한/획득 실패 시 일반 검색으로 대비(fallback)
      }
      const categoryCodes = ['FD6', 'CE7'];
      final mergedDocuments = <Map<String, dynamic>>[];

      for (final categoryCode in categoryCodes) {
        String url = 'https://dapi.kakao.com/v2/local/search/keyword.json'
            '?query=${Uri.encodeComponent(trimmed)}'
            '&category_group_code=$categoryCode'
            '&size=15';

        if (lat != null && lng != null) {
          url += '&sort=distance';
          url += '&x=$lng&y=$lat&radius=5000';
        }

        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'KakaoAK $_kakaoApiKey'},
        );

        if (response.statusCode != 200) {
          final errorInfo = _extractKakaoError(response);
          if (!mounted) return;
          setState(() {
            _errorMessage = '검색 API 에러 (${response.statusCode})'
                '${errorInfo.isNotEmpty ? '\n$errorInfo' : ''}';
            _isLoading = false;
          });
          return;
        }

        final data = jsonDecode(response.body);
        final documents = (data['documents'] as List?) ?? [];
        for (final item in documents) {
          if (item is Map) {
            mergedDocuments.add(item.cast<String, dynamic>());
          }
        }
      }

      final uniqueById = <String, Map<String, dynamic>>{};
      for (final doc in mergedDocuments) {
        final id = doc['id']?.toString() ?? '';
        if (id.isEmpty || uniqueById.containsKey(id)) continue;
        uniqueById[id] = doc.cast<String, dynamic>();
      }

      if (!mounted) return;
      setState(() {
        _results = uniqueById.values.map((map) {
          return RestaurantModel(
            id: map['id']?.toString() ?? '',
            storeId: map['id']?.toString() ?? '',
            name: map['place_name']?.toString() ?? '',
            category: _parseCategory(map['category_name']?.toString() ?? ''),
            categoryName: map['category_name']?.toString(),
            categoryGroupCode: map['category_group_code']?.toString(),
            categoryGroupName: map['category_group_name']?.toString(),
            address: (map['road_address_name']?.toString().isNotEmpty == true
                        ? map['road_address_name']
                        : map['address_name'])
                    ?.toString() ??
                '',
            latitude: double.tryParse(map['y']?.toString() ?? '0') ?? 0,
            longitude: double.tryParse(map['x']?.toString() ?? '0') ?? 0,
            truthScore: _mockTruthScore(map['id']?.toString() ?? ''),
            distance: int.tryParse(map['distance']?.toString() ?? '0') ?? 0,
            phone: map['phone']?.toString(),
            placeUrl: map['place_url']?.toString(),
            addressName: map['address_name']?.toString(),
            roadAddressName: map['road_address_name']?.toString(),
            reviewSummary: map['place_name']?.toString() ?? '검색 결과',
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '네트워크 에러가 발생했습니다';
        _isLoading = false;
      });
    }
  }

  String _extractKakaoError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final code = body['code'];
        final msg = body['msg'];
        final message = body['message'];
        final errorType = body['errorType'];
        final errorDescription = body['error_description'];
        final docHint = _kakaoCodeHint(code);
        final validationHint = _extractKakaoValidationHint(body['details']);
        final serviceDisabledHint = _kakaoServiceHint(
          statusCode: response.statusCode,
          code: code,
          message: msg?.toString(),
          messageAlt: message?.toString(),
          errorType: errorType?.toString(),
          errorDescription: errorDescription?.toString(),
        );

        final serviceSuffix =
            serviceDisabledHint != null ? ' / $serviceDisabledHint' : '';
        final detailSuffix = validationHint != null ? ' / $validationHint' : '';

        if (code != null && msg != null) {
          final docSuffix = docHint != null ? ' / $docHint' : '';
          return 'code=$code msg=$msg$docSuffix$serviceSuffix$detailSuffix';
        }
        if (message != null) {
          final docSuffix = docHint != null ? ' / $docHint' : '';
          return '${message.toString()}$docSuffix$serviceSuffix$detailSuffix';
        }
        if (serviceDisabledHint != null) {
          return serviceDisabledHint;
        }
        if (body['errorType'] != null) {
          final typeText =
              '${body['errorType']} ${body['error_description'] ?? ''}';
          return '$typeText$serviceSuffix$detailSuffix';
        }
      }
    } catch (_) {}
    return response.reasonPhrase?.isNotEmpty == true
        ? '${response.reasonPhrase}${response.reasonPhrase?.toLowerCase().contains('forbidden') == true ? ' (FORBIDDEN)' : ''}'
        : '';
  }

  String? _extractKakaoValidationHint(dynamic details) {
    if (details == null) return null;
    final List<dynamic> list = details is List<dynamic> ? details : [details];

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;

      final parts = <String>[];

      final field = item['field'];
      final error = item['error'];
      final reason = item['reason'];
      final value = item['value'];

      if (field != null && field.toString().isNotEmpty) {
        parts.add('field=${field.toString()}');
      }
      if (error != null && error.toString().isNotEmpty) {
        parts.add('error=${error.toString()}');
      }
      if (reason != null && reason.toString().isNotEmpty) {
        parts.add('reason=${reason.toString()}');
      }
      if (value != null && value.toString().isNotEmpty) {
        parts.add('value=${value.toString()}');
      }

      if (parts.isNotEmpty) return parts.join(', ');
    }

    return null;
  }

  String? _kakaoCodeHint(dynamic code) {
    if (code == -3 || code == '-3') {
      return 'Local API 미승인 또는 사용 권한 확인 필요 / OPEN_MAP_AND_LOCAL service 비활성화 가능성';
    }
    if (code == -5 || code == '-5') {
      return '요청한 API 사용 권한이 없습니다';
    }
    if (code == -401 || code == '-401') {
      return 'Authentication error: check Kakao API key and permissions.';
    }
    return null;
  }

  String? _kakaoServiceHint({
    required int statusCode,
    required dynamic code,
    String? message,
    String? messageAlt,
    String? errorType,
    String? errorDescription,
  }) {
    if (statusCode != 403) return null;

    final lowerCode = code?.toString();
    final fields = <String>[
      if (errorType != null) errorType,
      if (message != null) message,
      if (messageAlt != null) messageAlt,
      if (errorDescription != null) errorDescription,
    ];

    final lowerText = fields.join(' ').toLowerCase();
    if (lowerCode == '-3' || lowerCode == '-5') {
      return 'OPEN_MAP_AND_LOCAL service가 앱에서 비활성화되어 있습니다. '
          '카카오 디벨로퍼스 앱 설정에서 카카오맵(Local) API 사용을 확인하세요.';
    }

    if (lowerText.contains('open_map_and_local') ||
        lowerText.contains('open map and local') ||
        lowerText.contains('disabled') ||
        lowerText.contains('not authorized') ||
        lowerText.contains('notauthorizederror')) {
      return 'OPEN_MAP_AND_LOCAL service가 앱에서 비활성화되어 있습니다. '
          '카카오 디벨로퍼스 앱 설정에서 카카오맵(Local) API 사용을 확인하세요.';
    }

    return null;
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Please enter a search keyword.';
      });
      return;
    }
    _search(query);
  }

  String _parseCategory(String category) {
    final parts = category.split(' > ');
    if (parts.length >= 2) return parts[1];
    return parts.first;
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
      case 'trust_score':
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  size: 16, color: AppColors.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submitSearch,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search restaurants or cafes',
                    hintStyle: TextStyle(color: AppColors.textHint),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded,
                    size: 16, color: AppColors.primary500),
                onPressed: () => _submitSearch(_queryController.text),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Search',
              ),
            ],
          ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 52, color: AppColors.textHint),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '"$_query" ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary500,
                      ),
                    ),
                    TextSpan(
                      text: '${results.length} results',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppColors.textHint),
                  items: _sortOptions
                      .map((o) => DropdownMenuItem<String>(
                            value: o,
                            child: Text(o),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _sortBy = val);
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
                  itemBuilder: (_, i) => _RestaurantCard(
                    restaurant: results[i],
                    onTap: () {
                      widget.onViewPlace(results[i]);
                      Navigator.pop(context);
                    },
                  ),
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
          const Icon(Icons.search_off_rounded,
              size: 52, color: AppColors.textHint),
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
            '다른 키워드로 다시 시도해보세요',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;
  const _RestaurantCard({required this.restaurant, required this.onTap});

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
    return GestureDetector(
      onTap: onTap,
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
              child: const Icon(Icons.restaurant_rounded,
                  size: 28, color: Color(0xFFCCBBAA)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${restaurant.category} · ${restaurant.address}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.textHint),
                      const SizedBox(width: 2),
                      Text(
                        restaurant.distance > 0
                            ? '${restaurant.distance}m'
                            : restaurant.address,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _trustBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${restaurant.truthScore}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _trustColor,
                    ),
                  ),
                  Text(
                    'TRUTH',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: _trustColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatefulWidget {
  const _CardSkeleton();

  @override
  State<_CardSkeleton> createState() => _CardSkeletonState();
}

class _CardSkeletonState extends State<_CardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: const Color(0xFFE4E4EC),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          _box(64, 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(120, 14),
                const SizedBox(height: 6),
                _box(180, 11),
                const SizedBox(height: 6),
                _box(80, 11),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _box(48, 48),
        ],
      ),
    );
  }
}
