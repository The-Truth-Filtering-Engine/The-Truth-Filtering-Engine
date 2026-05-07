import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:truth_mouth/models/blog_review_model.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/review_item.dart';

// ?€?€ ?¤ì¼ˆ?ˆí†¤ shimmer ?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€

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

// ?€?€ ë¦¬ë·° ë¦¬ìŠ¤???¹ì…˜ ?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€?€

class ReviewListSection extends StatefulWidget {
  final ShopInfo shopInfo;
  final List<BlogReviewModel> blogs;

  const ReviewListSection({
    super.key,
    required this.shopInfo,
    required this.blogs,
  });

  @override
  State<ReviewListSection> createState() => _ReviewListSectionState();
}

class _ReviewListSectionState extends State<ReviewListSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // ???„í™˜ ??ë¦¬ìŠ¤???¤ì‹œ ê·¸ë¦¬ê¸?
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BlogReviewModel> get _sortedByReal => [...widget.blogs]
    ..sort((a, b) => a.adProbability.compareTo(b.adProbability));

  List<BlogReviewModel> get _sortedByDate =>
      [...widget.blogs]..sort((a, b) => b.date.compareTo(a.date));

  Future<void> _openUrl(BlogReviewModel blog) async {
    String finalUrl = blog.url;
    if (finalUrl.contains('blog.naver.com') &&
        !finalUrl.contains('m.blog.naver.com')) {
      finalUrl = finalUrl.replaceFirst('blog.naver.com', 'm.blog.naver.com');
    }

    final uri = Uri.parse(finalUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $finalUrl: $e');
    }
  }

  List<BlogReviewModel> get _currentBlogs =>
      _tabController.index == 0 ? _sortedByReal : _sortedByDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ?€?€ ??°” ?€?€
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
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
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  labelColor: AppColors.primary500,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppText.caption().copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary500,
                  ),
                  unselectedLabelStyle: AppText.caption(),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '?? ì§„ì„±??),
                    Tab(text: '?•  ìµœì‹ ??),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),

        const Divider(height: 1),

        // ?€?€ ë¦¬ìŠ¤??(shrinkWrap ???¸ë? CustomScrollView???¤í¬ë¡??„ìž„) ?€?€
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _currentBlogs.length,
          itemBuilder: (_, i) => ReviewItem(
            blog: _currentBlogs[i],
            onTap: () => _openUrl(_currentBlogs[i]),
          ),
        ),
      ],
    );
  }
}

