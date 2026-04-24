import 'package:flutter/material.dart';
import '../models/blog_review.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'blog_webview_screen.dart';

class BlogListScreen extends StatefulWidget {
  final ShopInfo shopInfo;
  final List<BlogReview> blogs;
  const BlogListScreen({
    super.key, required this.shopInfo, required this.blogs});
  @override
  State<BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends State<BlogListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BlogReview> get _sortedByReal =>
    [...widget.blogs]..sort((a, b) => a.adProbability.compareTo(b.adProbability));

  List<BlogReview> get _sortedByDate =>
    [...widget.blogs]..sort((a, b) => b.date.compareTo(a.date));

  void _openWebview(BlogReview blog) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BlogWebviewScreen(blog: blog),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shopInfo;
    return Scaffold(
      appBar: AppBar(
        title: AppBarLogo(),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── 가게 요약 카드 ──
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name, style: AppText.title()),
                          const SizedBox(height: 3),
                          Text(
                            '${shop.category} · 블로그 리뷰 ${shop.totalReviews}개',
                            style: AppText.caption()),
                        ],
                      ),
                    ),
                    TrustCircle(shop.trustScore),
                  ],
                ),
                const SizedBox(height: 14),
                StatProgressBar(
                  label: '광고 비율',
                  value: shop.adRatio,
                  color: AppColors.danger400,
                ),
                const SizedBox(height: 8),
                StatProgressBar(
                  label: '진성 리뷰',
                  value: shop.realRatio,
                  color: AppColors.success400,
                ),
                const SizedBox(height: 14),

                // ── 탭바 ──
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.06),
                          blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    labelColor: AppColors.primary500,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: AppText.caption()
                      .copyWith(fontWeight: FontWeight.w500,
                        color: AppColors.primary500),
                    unselectedLabelStyle: AppText.caption(),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '✅  진성순'),
                      Tab(text: '🕐  최신순'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const Divider(),

          // ── 리뷰 리스트 ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BlogList(blogs: _sortedByReal,  onTap: _openWebview),
                _BlogList(blogs: _sortedByDate,  onTap: _openWebview),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogList extends StatelessWidget {
  final List<BlogReview> blogs;
  final void Function(BlogReview) onTap;
  const _BlogList({required this.blogs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: blogs.length,
      itemBuilder: (_, i) =>
        BlogCard(blog: blogs[i], onTap: () => onTap(blogs[i])),
    );
  }
}
