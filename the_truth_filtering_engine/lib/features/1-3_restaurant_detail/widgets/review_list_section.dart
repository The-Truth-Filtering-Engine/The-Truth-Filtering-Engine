import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/blog_review.dart';
import '../utils/blog_review_url.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/review_item.dart';

// ── 스켈레톤 shimmer ──────────────────────────────────────────────────────────

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
  const _BlogCardSkeleton({super.key});

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

// ── 리뷰 리스트 섹션 ──────────────────────────────────────────────────────────

typedef ReviewOpenGuard = Future<bool> Function(BlogReview review);

class ReviewListSection extends StatefulWidget {
  final ShopInfo shopInfo;
  final List<BlogReview> blogs;
  final bool hasMoreReviews;
  final bool isLoadingReviewBatch;
  final ValueChanged<int>? onRequestReviewBatch;
  final ReviewOpenGuard? onReviewTap;

  const ReviewListSection({
    super.key,
    required this.shopInfo,
    required this.blogs,
    this.hasMoreReviews = false,
    this.isLoadingReviewBatch = false,
    this.onRequestReviewBatch,
    this.onReviewTap,
  });

  @override
  State<ReviewListSection> createState() => _ReviewListSectionState();
}

class _ReviewListSectionState extends State<ReviewListSection>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 10;
  static const int _maxReviewCount = 300;

  late TabController _tabController;
  int _currentTabIndex = 0;
  int _currentPage = 0;
  final Set<int> _hiddenReviewIds = <int>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didUpdateWidget(covariant ReviewListSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final shopChanged = oldWidget.shopInfo.name != widget.shopInfo.name;
    final blogsChanged = !identical(oldWidget.blogs, widget.blogs) ||
        oldWidget.blogs.length != widget.blogs.length;

    if (shopChanged) {
      _hiddenReviewIds.clear();
      _currentPage = 0;
    } else if (blogsChanged ||
        oldWidget.hasMoreReviews != widget.hasMoreReviews) {
      _clampCurrentPage();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  List<BlogReview> get _displayBlogs => _hiddenReviewIds.isEmpty
      ? widget.blogs
      : widget.blogs
          .where((blog) => !_hiddenReviewIds.contains(blog.id))
          .toList();

  List<BlogReview> get _sortedByRecommended =>
      [..._displayBlogs]..sort(_compareRecommended);

  List<BlogReview> get _sortedByTrust => [..._displayBlogs]
    ..sort((a, b) => a.adProbability.compareTo(b.adProbability));

  List<BlogReview> get _sortedByDate =>
      [..._displayBlogs]..sort((a, b) => b.date.compareTo(a.date));

  int _compareRecommended(BlogReview a, BlogReview b) {
    final likeCompare = b.likeCount.compareTo(a.likeCount);
    if (likeCompare != 0) return likeCompare;

    final trustCompare = a.adProbability.compareTo(b.adProbability);
    if (trustCompare != 0) return trustCompare;

    return b.date.compareTo(a.date);
  }

  Future<void> _openUrl(BlogReview blog) async {
    final canOpen = await widget.onReviewTap?.call(blog) ?? true;
    if (!canOpen) return;

    final uri = mobileBlogReviewUri(blog.url);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch ${blog.url}: $e');
    }
  }

  List<BlogReview> get _currentBlogs => switch (_tabController.index) {
        0 => _sortedByRecommended,
        1 => _sortedByTrust,
        _ => _sortedByDate,
      };

  int get _totalPages {
    if (_currentBlogs.isEmpty) return 0;
    final loadedPages = (_currentBlogs.length / _pageSize).ceil();
    if (!widget.hasMoreReviews) return loadedPages;

    final maxPages = (_maxReviewCount / _pageSize).ceil();
    return loadedPages < maxPages ? maxPages : loadedPages;
  }

  int get _lastPageIndex => _totalPages == 0 ? 0 : _totalPages - 1;

  bool get _shouldShowPagination =>
      _currentBlogs.length > _pageSize || widget.hasMoreReviews;

  bool get _canGoPrevious => _currentPage > 0 && !widget.isLoadingReviewBatch;

  bool get _canGoNext =>
      _currentPage < _lastPageIndex && !widget.isLoadingReviewBatch;

  bool get _isCurrentPageLoaded => _currentPageStart < _currentBlogs.length;

  bool get _shouldShowPageSkeleton =>
      widget.isLoadingReviewBatch && !_isCurrentPageLoaded;

  int get _currentPageStart => _currentPage * _pageSize;

  List<BlogReview> get _visibleBlogs {
    final blogs = _currentBlogs;
    final start = _currentPageStart;
    if (start >= blogs.length) return const [];

    final requestedEnd = start + _pageSize;
    final end = requestedEnd > blogs.length ? blogs.length : requestedEnd;
    return blogs.sublist(start, end);
  }

  void _handleTabChange() {
    if (_currentTabIndex == _tabController.index) return;

    setState(() {
      _currentTabIndex = _tabController.index;
      _currentPage = 0;
    });
  }

  void _clampCurrentPage() {
    if (_currentPage > _lastPageIndex) {
      _currentPage = _lastPageIndex;
    }
  }

  void _goToPreviousPage() {
    if (!_canGoPrevious) return;
    final nextPage = _currentPage - 1;
    setState(() => _currentPage = nextPage);
    _requestBatchIfNeeded(nextPage);
  }

  void _goToNextPage() {
    if (!_canGoNext) return;
    final nextPage = _currentPage + 1;
    setState(() => _currentPage = nextPage);
    _requestBatchIfNeeded(nextPage);
  }

  void _requestBatchIfNeeded(int page) {
    final pageStart = page * _pageSize;
    if (pageStart < _currentBlogs.length) return;
    if (!widget.hasMoreReviews || widget.isLoadingReviewBatch) return;

    widget.onRequestReviewBatch?.call(page);
  }

  void _hideReportedReview(BlogReview blog) {
    if (_hiddenReviewIds.contains(blog.id)) return;

    setState(() {
      _hiddenReviewIds.add(blog.id);
      _clampCurrentPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentBlogs = _currentBlogs;
    final visibleBlogs = _visibleBlogs;
    final showSkeleton = _shouldShowPageSkeleton;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 탭바 ──
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
                        color: Colors.black.withValues(alpha: .06),
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
                    Tab(text: '추천순'),
                    Tab(text: '신뢰순'),
                    Tab(text: '최신순'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),

        const Divider(height: 1),

        if (currentBlogs.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Text(
              '표시할 블로그 리뷰가 없습니다.',
              textAlign: TextAlign.center,
              style: AppText.caption().copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                if (showSkeleton)
                  for (var i = 0; i < _pageSize; i++)
                    _BlogCardSkeleton(key: ValueKey('review-page-skeleton-$i'))
                else
                  for (final blog in visibleBlogs)
                    ReviewItem(
                      blog: blog,
                      onTap: () => _openUrl(blog),
                      onReportSubmitted: () => _hideReportedReview(blog),
                    ),
                _PaginationControls(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  show: _shouldShowPagination,
                  canGoPrevious: _canGoPrevious,
                  canGoNext: _canGoNext,
                  onPrevious: _goToPreviousPage,
                  onNext: _goToNextPage,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool show;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.show,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              label: const Text('이전'),
              style: _buttonStyle(),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 74,
            child: Text(
              '${currentPage + 1} / $totalPages',
              textAlign: TextAlign.center,
              style: AppText.caption().copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: const Text('다음'),
              style: _buttonStyle(),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary500,
      disabledForegroundColor: AppColors.textHint,
      side: const BorderSide(color: AppColors.border, width: 0.8),
      padding: const EdgeInsets.symmetric(vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: AppText.caption().copyWith(fontWeight: FontWeight.w600),
    );
  }
}
