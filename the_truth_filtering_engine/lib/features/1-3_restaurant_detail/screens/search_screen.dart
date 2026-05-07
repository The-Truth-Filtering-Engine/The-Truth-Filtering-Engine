import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truth_mouth/models/blog_review_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../1-1_map/widgets/common_widgets.dart';
import 'blog_list_screen.dart';
import '../../../services/api_service.dart';
// import '../../../models/review_item.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _goToList(String query) async {
    if (query.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('가게명 ?�는 링크�??�력??주세??')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.search(query.trim());

      // ReviewItem ??BlogReviewModel 변??
      final blogs = result.reviews.map((r) {
        final adProb = (r.isAdLlmPred == 1) ? 90 : 10;
        final status =
            (r.isAdLlmPred == 1) ? ReviewStatus.ad : ReviewStatus.real;

        return BlogReviewModel(
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

      // ShopInfo ?�성
      final shopInfo = ShopInfo(
        name: query.trim(),
        category: '블로�?리뷰 분석',
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
          .showSnackBar(SnackBar(content: Text('?�류가 발생?�습?�다: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                          child: Text('?���?, style: TextStyle(fontSize: 28)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('맛집 분석?�기', style: AppText.display()),
                      const SizedBox(height: 6),
                      Text(
                        '?�이�?지??링크 ?�는 가게명???�력?�면\nAI가 블로�?리뷰??광고 ?��?�?분석?�드?�요',
                        textAlign: TextAlign.center,
                        style: AppText.caption().copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _controller,
                  style: AppText.body(),
                  onSubmitted: _goToList,
                  decoration: const InputDecoration(
                    hintText: '?? ?�모?�나???�시 / https://map.naver.com/...',
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.textHint, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed:
                      _isLoading ? null : () => _goToList(_controller.text),
                  child: const Text('?��  분석 ?�작'),
                ),
                const SizedBox(height: 28),
                const SectionTitle('최근 검??),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recentSearches.asMap().entries.map((e) {
                    final isFirst = e.key == 0;
                    return GestureDetector(
                      onTap: () => _goToList(e.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFirst ? AppColors.primary50 : AppColors.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isFirst
                                  ? AppColors.primary200
                                  : AppColors.border,
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
                const SizedBox(height: 32),
              ],
            ),
          ),

          // 로딩 ?�버?�이
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('AI가 리뷰�?분석 중이?�요...',
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
    super.dispose();
  }
}

