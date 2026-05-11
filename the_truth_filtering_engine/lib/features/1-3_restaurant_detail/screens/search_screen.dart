import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../1-3_restaurant_detail/providers/blog_review.dart';
import '../../../core/providers/search_history_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../1-1_map/widgets/common_widgets.dart';
import 'blog_list_screen.dart';
import '../../../services/api_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _showHistory = false; // 포커스 시 기록 드롭다운 표시

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _showHistory = _focusNode.hasFocus);
    });
  }

  Future<void> _goToList(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('가게명 또는 링크를 입력해 주세요.')));
      return;
    }

    // 검색어 저장
    await ref.read(searchHistoryProvider.notifier).add(q);

    _focusNode.unfocus();
    setState(() {
      _isLoading = true;
      _showHistory = false;
    });

    try {
      final result = await _apiService.search(q);

      final blogs = result.reviews.map((r) {
        final adProb = (r.isAdLlmPred == 1) ? 90 : 10;
        final status =
            (r.isAdLlmPred == 1) ? ReviewStatus.ad : ReviewStatus.real;

        return BlogReview(
          id: r.id,
          title: r.reviewTitle ?? '',
          author: r.reviewBloggername ?? '',
          date: r.reviewPostdate ?? '',
          preview: r.reviewDescription ?? '',
          content: r.reviewDescription ?? '',
          url: r.reviewUrl ?? '',
          status: status,
          adProbability: adProb,
          isSponsored: r.isAdLlmPred == 1,
        );
      }).toList();

      final shopInfo = ShopInfo(
        name: q,
        category: '블로그 리뷰 분석',
        trustScore: result.total > 0
            ? ((result.realCount / result.total) * 100).round()
            : 0,
        adRatio: result.total > 0
            ? ((result.adCount / result.total) * 100).round()
            : 0,
        realRatio: result.total > 0
            ? ((result.realCount / result.total) * 100).round()
            : 0,
        totalReviews: result.total,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlogListScreen(shopInfo: shopInfo, blogs: blogs),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류가 발생했습니다: \$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillAndSearch(String query) {
    _controller.text = query;
    _goToList(query);
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(searchHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarLogo(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: const Center(
                          child: Text('🏛️', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('맛집 분석하기', style: AppText.display()),
                      const SizedBox(height: 6),
                      Text(
                        '네이버 지도 링크 또는 가게명을 입력하면\nAI가 블로그 리뷰의 광고 여부를 분석해드려요',
                        textAlign: TextAlign.center,
                        style: AppText.caption().copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── 검색창 + 드롭다운 ───────────────────────
                _SearchFieldWithHistory(
                  controller: _controller,
                  focusNode: _focusNode,
                  history: history,
                  showHistory: _showHistory && history.isNotEmpty,
                  onSubmitted: _goToList,
                  onHistoryTap: _fillAndSearch,
                  onHistoryRemove: (q) =>
                      ref.read(searchHistoryProvider.notifier).remove(q),
                  onHistoryClear: () =>
                      ref.read(searchHistoryProvider.notifier).clear(),
                ),

                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed:
                      _isLoading ? null : () => _goToList(_controller.text),
                  child: const Text('🔍  분석 시작'),
                ),

                // ── 최근 검색 칩 (하단 고정 목록) ────────────
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionTitle('최근 검색'),
                      TextButton(
                        onPressed: () =>
                            ref.read(searchHistoryProvider.notifier).clear(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '전체 삭제',
                          style: AppText.caption()
                              .copyWith(color: AppColors.textHint),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: history.asMap().entries.map((e) {
                      final isFirst = e.key == 0;
                      return GestureDetector(
                        onTap: () => _fillAndSearch(e.value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                isFirst ? AppColors.primary50 : AppColors.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isFirst
                                  ? AppColors.primary200
                                  : AppColors.border,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            e.value,
                            style: AppText.caption().copyWith(
                              color: isFirst
                                  ? AppColors.primary500
                                  : AppColors.textSecondary,
                              fontWeight: isFirst
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),

          // 로딩 오버레이
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('AI가 리뷰를 분석 중이에요...',
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// ── 검색창 + 포커스 시 기록 드롭다운 ──────────────────────────
class _SearchFieldWithHistory extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> history;
  final bool showHistory;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onHistoryTap;
  final ValueChanged<String> onHistoryRemove;
  final VoidCallback onHistoryClear;

  const _SearchFieldWithHistory({
    required this.controller,
    required this.focusNode,
    required this.history,
    required this.showHistory,
    required this.onSubmitted,
    required this.onHistoryTap,
    required this.onHistoryRemove,
    required this.onHistoryClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: AppText.body(),
          onSubmitted: onSubmitted,
          decoration: const InputDecoration(
            hintText: '예: 오모테나시 스시 / https://map.naver.com/...',
            prefixIcon: Icon(Icons.search_rounded,
                color: AppColors.textHint, size: 20),
          ),
        ),
        if (showHistory)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('최근 검색',
                          style: AppText.caption()
                              .copyWith(color: AppColors.textHint)),
                      GestureDetector(
                        onTap: onHistoryClear,
                        child: Text('전체 삭제',
                            style: AppText.caption()
                                .copyWith(color: AppColors.textHint)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE4E4EC)),
                // 기록 목록
                ...history.take(5).map(
                      (q) => InkWell(
                        onTap: () => onHistoryTap(q),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              const Icon(Icons.history,
                                  size: 15, color: AppColors.textHint),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(q, style: AppText.body()),
                              ),
                              GestureDetector(
                                onTap: () => onHistoryRemove(q),
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.close,
                                      size: 14, color: AppColors.textHint),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}
