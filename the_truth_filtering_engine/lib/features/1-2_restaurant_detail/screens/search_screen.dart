import 'package:flutter/material.dart';
import '../../1-2_restaurant_detail/providers/blog_review.dart';
import '../../../core/theme/app_theme.dart';
import '../../1-1_map/widgets/common_widgets.dart';
import 'blog_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  void _goToList(String query) {
    if (query.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('가게명 또는 링크를 입력해 주세요.')));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BlogListScreen(shopInfo: dummyShop, blogs: dummyBlogs),
        ));
  }

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),

            // ── 히어로 ──
            Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 0.5),
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

            // ── 검색창 ──
            TextField(
              controller: _controller,
              style: AppText.body(),
              onSubmitted: _goToList,
              decoration: const InputDecoration(
                hintText: '예: 오모테나시 스시 / https://map.naver.com/...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textHint, size: 20),
              ),
            ),

            const SizedBox(height: 12),

            // ── 분석 시작 버튼 ──
            ElevatedButton(
              onPressed: () => _goToList(_controller.text),
              child: const Text('🔍  분석 시작'),
            ),

            const SizedBox(height: 28),
            const SectionTitle('최근 검색'),

            // ── 최근 검색 칩 ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches.asMap().entries.map((e) {
                final isFirst = e.key == 0;
                return GestureDetector(
                  onTap: () => _goToList(e.value),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFirst ? AppColors.primary50 : AppColors.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              isFirst ? AppColors.primary200 : AppColors.border,
                          width: 0.5),
                    ),
                    child: Text(e.value,
                        style: AppText.caption().copyWith(
                          color: isFirst
                              ? AppColors.primary500
                              : AppColors.textSecondary,
                          fontWeight:
                              isFirst ? FontWeight.w500 : FontWeight.w400,
                        )),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),
            const SectionTitle('최근 분석 결과'),

            // ── 최근 분석 결과 카드 ──
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BlogListScreen(shopInfo: dummyShop, blogs: dummyBlogs),
                  )),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('🍣', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dummyShop.name, style: AppText.subtitle()),
                            const SizedBox(height: 2),
                            Text('${dummyShop.category} · 분석 완료',
                                style: AppText.caption()),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('TRUTH ${dummyShop.trustScore}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.success700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
