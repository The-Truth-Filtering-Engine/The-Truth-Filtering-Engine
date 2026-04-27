import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/blog_review.dart';
import '../../../core/theme/app_theme.dart';
import '../../../common/app_bar_logo.dart';
import '../../../common/stat_progress_bar.dart';
import '../../../common/trust_circle.dart';
import '../widgets/review_item.dart';

// ───────────────────────────────────────────
// 스켈레톤 shimmer 위젯
// ───────────────────────────────────────────
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  const _SkeletonBox(
      {required this.width, required this.height, this.borderRadius});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE4E4EC),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _BlogCardSkeleton extends StatelessWidget {
  const _BlogCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: double.infinity, height: 13),
                    const SizedBox(height: 5),
                    _SkeletonBox(width: 180, height: 13),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SkeletonBox(
                  width: 36,
                  height: 22,
                  borderRadius: BorderRadius.circular(5)),
            ],
          ),
          const SizedBox(height: 10),
          _SkeletonBox(width: double.infinity, height: 11),
          const SizedBox(height: 5),
          _SkeletonBox(width: 240, height: 11),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SkeletonBox(width: 80, height: 10),
              _SkeletonBox(width: 60, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 4,
      itemBuilder: (_, __) => const _BlogCardSkeleton(),
    );
  }
}

// ───────────────────────────────────────────
// 블로그 리뷰 리스트 화면
// ───────────────────────────────────────────
class BlogListScreen extends StatefulWidget {
  final ShopInfo shopInfo;
  final List<BlogReview> blogs;
  const BlogListScreen(
      {super.key, required this.shopInfo, required this.blogs});

  @override
  State<BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends State<BlogListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // bool _isLoading = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // _simulateLoading();
  }

  // 실제 API 연동 시 이 부분을 API 호출로 교체하세요
  // Future<void> _simulateLoading() async {
  //   await Future.delayed(const Duration(milliseconds: 1800));
  //   if (mounted) setState(() => _isLoading = false);
  // }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BlogReview> get _sortedByReal => [...widget.blogs]
    ..sort((a, b) => a.adProbability.compareTo(b.adProbability));

  List<BlogReview> get _sortedByDate =>
      [...widget.blogs]..sort((a, b) => b.date.compareTo(a.date));

  Future<void> _openWebview(BlogReview blog) async {
    final uri = Uri.parse(blog.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shopInfo;
    return Scaffold(
      appBar: AppBar(
        title: const AppBarLogo(),
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
                  value: shop.adRatio.toDouble(),
                  color: AppColors.danger400,
                ),
                const SizedBox(height: 8),
                StatProgressBar(
                  label: '진성 리뷰',
                  value: shop.realRatio.toDouble(),
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
                            blurRadius: 4,
                            offset: const Offset(0, 1)),
                      ],
                    ),
                    labelColor: AppColors.primary500,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: AppText.caption().copyWith(
                        fontWeight: FontWeight.w500,
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

          // ── 리뷰 리스트 or 스켈레톤 ──
          Expanded(
            child: _isLoading
                ? const _SkeletonList()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _BlogList(blogs: _sortedByReal, onTap: _openWebview),
                      _BlogList(blogs: _sortedByDate, onTap: _openWebview),
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
          ReviewItem(blog: blogs[i], onTap: () => onTap(blogs[i])),
    );
  }
}
