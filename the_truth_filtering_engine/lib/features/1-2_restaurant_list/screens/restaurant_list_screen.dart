import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_colors.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../../1-3_restaurant_detail/screens/restaurant_detail_screen.dart';

// ── 카카오 로컬 API 키 ────────────────────────────
const _kakaoApiKey = '038c8ee8e4d135f7d056fea43c9d7e23';

class RestaurantListScreen extends StatefulWidget {
  final String query;
  const RestaurantListScreen({super.key, required this.query});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<RestaurantModel> _results = [];
  String _sortBy = '신뢰도순';
  final List<String> _sortOptions = ['신뢰도순', '거리순'];

  @override
  void initState() {
    super.initState();
    _search();
  }

  // ── 카카오 로컬 API 호출 ──────────────────────────
  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
        'https://dapi.kakao.com/v2/local/search/keyword.json'
        '?query=${Uri.encodeComponent(widget.query)}'
        '&category_group_code=FD6,CE7' // FD6: 음식점, CE7: 카페
        '&size=15',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'KakaoAK $_kakaoApiKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final documents = data['documents'] as List;

        setState(() {
          _results = documents.map((doc) {
            return RestaurantModel(
              id: doc['id'] ?? '',
              name: doc['place_name'] ?? '',
              category: _parseCategory(doc['category_name'] ?? ''),
              address: doc['road_address_name'] ?? doc['address_name'] ?? '',
              latitude: double.tryParse(doc['y'] ?? '0') ?? 0,
              longitude: double.tryParse(doc['x'] ?? '0') ?? 0,
              truthScore: _mockTruthScore(doc['id'] ?? ''), // 추후 AI 연동
              distance: int.tryParse(doc['distance'] ?? '0') ?? 0,
              phone: doc['phone'] ?? '',
              placeUrl: doc['place_url'] ?? '',
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '검색에 실패했어요. (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 오류가 발생했어요.';
        _isLoading = false;
      });
    }
  }

  // 카카오 카테고리 파싱 (예: "음식점 > 한식 > 삼겹살" → "한식")
  String _parseCategory(String category) {
    final parts = category.split(' > ');
    if (parts.length >= 2) return parts[1];
    return parts.first;
  }

  // 임시 Trust 점수 (추후 AI 분석 연동)
  int _mockTruthScore(String id) {
    final hash = id.hashCode.abs() % 40;
    return 60 + hash; // 60~99 사이 임시값
  }

  List<RestaurantModel> get _sortedResults {
    final list = [..._results];
    switch (_sortBy) {
      case '신뢰도순':
        list.sort((a, b) => b.truthScore.compareTo(a.truthScore));
      case '거리순':
        list.sort((a, b) => a.distance.compareTo(b.distance));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(widget.query,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  // ── 스켈레톤 ────────────────────────────────────
  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => const _CardSkeleton(),
    );
  }

  // ── 에러 ─────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 52, color: AppColors.textHint),
          const SizedBox(height: 14),
          Text(_errorMessage!,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _search,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  // ── 결과 본문 ────────────────────────────────────
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 결과 수 + 정렬
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '"${widget.query}" ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary500,
                      ),
                    ),
                    TextSpan(
                      text: '검색 결과 ${_sortedResults.length}개',
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
                      .map((o) =>
                          DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _sortBy = val);
                  },
                ),
              ),
            ],
          ),
        ),

        // 가게 목록
        Expanded(
          child: _sortedResults.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _sortedResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RestaurantCard(
                    restaurant: _sortedResults[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(
                          restaurant: _sortedResults[i],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── 결과 없음 ────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 52, color: AppColors.textHint),
          const SizedBox(height: 14),
          Text('"${widget.query}" 검색 결과가 없어요',
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          const Text('다른 검색어로 시도해보세요',
              style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

// ── 가게 카드 ──────────────────────────────────────
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
            // 이미지 플레이스홀더
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_rounded,
                  size: 28, color: Color(0xFFCCBBAA)),
            ),
            const SizedBox(width: 12),

            // 가게 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    '${restaurant.category} · ${restaurant.address}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
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

            // Trust 점수
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _trustBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('${restaurant.truthScore}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _trustColor,
                      )),
                  Text('TRUTH',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: _trustColor,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 스켈레톤 카드 ──────────────────────────────────
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
            width: w, height: h,
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