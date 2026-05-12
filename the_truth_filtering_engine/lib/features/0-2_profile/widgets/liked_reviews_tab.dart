import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/liked_reviews_provider.dart';
import '../../../core/theme/app_theme.dart';

class LikedReviewsTab extends ConsumerWidget {
  const LikedReviewsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedReviewsProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2B54E8)),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE85C5C), size: 40),
            const SizedBox(height: 10),
            Text('불러오기 실패', style: AppText.body()),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.read(likedReviewsProvider.notifier).load(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border, size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(
                  '하트를 누른 리뷰가 없습니다.',
                  style: AppText.body().copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reviews.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFE4E4EC)),
          itemBuilder: (ctx, i) => _LikedReviewTile(review: reviews[i]),
        );
      },
    );
  }
}

class _LikedReviewTile extends StatelessWidget {
  final LikedReview review;

  const _LikedReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 하트 아이콘
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.favorite, color: Color(0xFFE85C5C), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (review.restaurantName.isNotEmpty)
                  Text(
                    review.restaurantName,
                    style: AppText.caption()
                        .copyWith(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 2),
                Text(
                  review.title,
                  style: AppText.subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  review.description,
                  style: AppText.body().copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
