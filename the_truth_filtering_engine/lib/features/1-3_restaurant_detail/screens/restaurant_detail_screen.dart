import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../../1-1_map/widgets/truth_score_badge.dart';
import '../providers/blog_review.dart';
import 'blog_list_screen.dart';

// ── API 호출 ──────────────────────────────────────────────────────────────────

Future<List<BlogReview>> _fetchReviews(String restaurantName) async {
  final uri = Uri.parse('http://localhost:8000/api/search')
      .replace(queryParameters: {'query': restaurantName});

  final res = await http.get(uri).timeout(const Duration(seconds: 30));

  if (res.statusCode != 200) {
    throw Exception('서버 오류 (${res.statusCode})');
  }

  final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final reviewsJson = body['reviews'] as List<dynamic>? ?? [];

  return reviewsJson
      .map((e) => BlogReview.fromApi(e as Map<String, dynamic>))
      .toList();
}

// ── 화면 ─────────────────────────────────────────────────────────────────────

class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  // 버튼 탭 시 로딩 상태 관리 (화면 전체 로딩 X, 버튼만 표시)
  bool _isLoadingReviews = false;

  RestaurantModel get _r => widget.restaurant;

  Future<void> _onReviewButtonTap() async {
    setState(() => _isLoadingReviews = true);

    try {
      final reviews = await _fetchReviews(_r.name);

      final shopInfo = ShopInfo.fromApiResponse(
        name: _r.name,
        category: '${_r.category} · ${_r.address}',
        reviews: reviews,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlogListScreen(
            shopInfo: shopInfo,
            blogs: reviews,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('리뷰를 불러오지 못했어요: $e'),
          backgroundColor: const Color(0xFFE85C5C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        leadingWidth: 40,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.home_outlined,
                  size: 20, color: AppColors.primary),
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Center(
          child: Text(_r.name,
              style: AppTextStyles.restaurantName.copyWith(fontSize: 16)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                size: 20, color: AppColors.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded,
                size: 20, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 이미지 영역 ──
            Container(
              height: 220,
              width: double.infinity,
              color: const Color(0xFFD4A96A),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _WoodGrainPainter()),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D9E75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_r.truthScore}% Veritas Verified',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 가게 기본 정보 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_r.name, style: AppTextStyles.restaurantName),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 13, color: Color(0xFF888888)),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    '${_r.address} · ${_r.category}',
                                    style: AppTextStyles.restaurantMeta,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      TruthScoreBadge(score: _r.truthScore),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActionItem(icon: Icons.phone_outlined, label: 'Call'),
                      _ActionItem(icon: Icons.bookmark_outline, label: 'Save'),
                      _ActionItem(icon: Icons.near_me_outlined, label: 'Route'),
                      _ActionItem(
                          icon: Icons.ios_share_outlined, label: 'Share'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // ── AI 진실 분석 카드 ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE4E4EC), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 15, color: Color(0xFF2B54E8)),
                        const SizedBox(width: 6),
                        const Text('AI 진실 분석',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E2E4E))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('실제 방문자 리뷰 기반의 신뢰도',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF9090A8))),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _trustColor(_r.truthScore), width: 5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${_r.truthScore}%',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _trustTextColor(_r.truthScore))),
                              const Text('TRUST',
                                  style: TextStyle(
                                      fontSize: 7, color: Color(0xFFA0A0C0))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _StatBar(
                                label: '광고 의심 게재',
                                value: 100 - _r.truthScore,
                                color: const Color(0xFFE85C5C),
                              ),
                              const SizedBox(height: 8),
                              _StatBar(
                                label: '진성 리뷰 비율',
                                value: _r.truthScore,
                                color: const Color(0xFF4CBB87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // ── 블로그 리뷰 보기 버튼 ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onTap: _isLoadingReviews ? null : _onReviewButtonTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _isLoadingReviews
                        ? AppColors.primary.withOpacity(0.6)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isLoadingReviews
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rate_review_outlined,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('블로그 리뷰 분석하기',
                                style: AppTextStyles.primaryButton),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _trustColor(int score) {
    if (score >= 80) return const Color(0xFF4CBB87);
    if (score >= 60) return const Color(0xFFF5A623);
    return const Color(0xFFE85C5C);
  }

  Color _trustTextColor(int score) {
    if (score >= 80) return const Color(0xFF1A7A4A);
    if (score >= 60) return const Color(0xFFA05800);
    return const Color(0xFFC0392B);
  }
}

// ── 하단 액션 아이템 ──────────────────────────────────────────────────────────

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF0FF),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF2B54E8)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6060A0))),
      ],
    );
  }
}

// ── 통계 진행 바 ──────────────────────────────────────────────────────────────

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9090A8))),
            Text('$value%',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: const Color(0xFFEEEEEE),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

// ── 이미지 플레이스홀더 패턴 ──────────────────────────────────────────────────

class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBF8C50).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (double y = 0; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 6), paint);
    }
  }

  @override
  bool shouldRepaint(_WoodGrainPainter old) => false;
}
