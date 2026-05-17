part of '../settings_screen.dart';

class _LikedReviewsSettingsScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onSelectTab;

  const _LikedReviewsSettingsScreen({this.onSelectTab});

  @override
  ConsumerState<_LikedReviewsSettingsScreen> createState() =>
      _LikedReviewsSettingsScreenState();
}

class _LikedReviewsSettingsScreenState
    extends ConsumerState<_LikedReviewsSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(likedReviewsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 하트')),
      bottomNavigationBar: _SettingsFlowBottomNavigationBar(
        onTap: (index) => _selectMainTab(context, widget.onSelectTab, index),
      ),
      body: const _LikedReviewsSettingsList(),
    );
  }
}

class _LikedReviewsSettingsList extends ConsumerStatefulWidget {
  const _LikedReviewsSettingsList();

  @override
  ConsumerState<_LikedReviewsSettingsList> createState() =>
      _LikedReviewsSettingsListState();
}

class _LikedReviewsSettingsListState
    extends ConsumerState<_LikedReviewsSettingsList> {
  final Map<String, LikedReview> _pendingRemovalReviews = {};

  @override
  void dispose() {
    _flushPendingRemovals();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likedReviews = ref.watch(likedReviewsProvider);

    return likedReviews.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _SettingsListMessage(
        icon: Icons.error_outline,
        message: '내 하트 목록을 불러오지 못했습니다.',
        action: TextButton.icon(
          onPressed: () => ref.read(likedReviewsProvider.notifier).load(),
          icon: const Icon(Icons.refresh),
          label: const Text('다시 시도'),
        ),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const _SettingsListMessage(
            icon: Icons.favorite_border,
            message: '하트를 누른 리뷰가 없습니다.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final review = reviews[index];
            final isPendingRemoval =
                _pendingRemovalReviews.containsKey(review.id);

            return _LikedReviewSettingsTile(
              review: review,
              isPendingRemoval: isPendingRemoval,
              onTap: () => _recordRecentReviewAndOpen(
                context,
                ref,
                reviewId: review.id,
                name: review.restaurantName,
                reviewUrl: review.reviewUrl,
                reviewTitle: review.title,
                reviewDescription: review.description,
              ),
              onRemove: () => _togglePendingRemoval(review),
            );
          },
        );
      },
    );
  }

  void _togglePendingRemoval(LikedReview review) {
    setState(() {
      if (_pendingRemovalReviews.containsKey(review.id)) {
        _pendingRemovalReviews.remove(review.id);
      } else {
        _pendingRemovalReviews[review.id] = review;
      }
    });
  }

  void _flushPendingRemovals() {
    if (_pendingRemovalReviews.isEmpty) return;
    final reviews = List<LikedReview>.of(_pendingRemovalReviews.values);
    _pendingRemovalReviews.clear();

    final userId = ref.read(currentUserIdProvider);
    final likedReviewsNotifier = ref.read(likedReviewsProvider.notifier);
    for (final review in reviews) {
      if (userId != null) {
        ref
            .read(
              reviewLikeProvider(
                ReviewLikeProviderKey(
                  reviewId: review.id,
                  userId: userId,
                ),
              ).notifier,
            )
            .markUnliked();
      }
      unawaited(likedReviewsNotifier.remove(review.id));
    }
  }
}

class _LikedReviewSettingsTile extends StatelessWidget {
  final LikedReview review;
  final bool isPendingRemoval;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _LikedReviewSettingsTile({
    required this.review,
    required this.isPendingRemoval,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: IconButton(
        tooltip: isPendingRemoval ? '해제 예정 취소' : '내 하트 해제',
        icon: Icon(
          Icons.favorite,
          color: isPendingRemoval
              ? const Color(0xFFE85C5C).withValues(alpha: 0.3)
              : const Color(0xFFE85C5C),
        ),
        onPressed: onRemove,
      ),
      title: Text(
        review.title.isEmpty ? '제목 없는 리뷰' : review.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.restaurantName.isNotEmpty)
            Text(
              review.restaurantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (review.description.isNotEmpty)
            Text(
              review.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
