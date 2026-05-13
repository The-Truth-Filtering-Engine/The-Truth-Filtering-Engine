import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/providers/liked_reviews_provider.dart';
import '../../../../core/providers/user_profile_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/review_like_provider.dart';
import 'report_button.dart';

class ReviewActionButtons extends ConsumerWidget {
  final String reviewId;
  final VoidCallback? onReportSubmitted;

  const ReviewActionButtons({
    super.key,
    required this.reviewId,
    this.onReportSubmitted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(currentUserEmailProvider);
    final userId = ref.watch(currentUserIdProvider);
    final isLoggedIn = email != null && email.isNotEmpty;
    final likeKey = userId == null
        ? null
        : ReviewLikeProviderKey(reviewId: reviewId, userId: userId);
    final state =
        likeKey == null ? null : ref.watch(reviewLikeProvider(likeKey));
    final likeState = state?.likeState;
    final isLiked = likeState?.isLiked ?? false;
    final likeCount = likeState?.likeCount ?? 0;

    Future<void> onTapHeart() async {
      if (!isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '로그인이 필요합니다.',
              style: AppText.body().copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.warning400,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (likeKey == null) {
        ref.read(userProfileProvider.notifier).loadIfPossible(force: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '사용자 정보를 불러오는 중입니다.',
              style: AppText.body().copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.warning400,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      final likeState =
          await ref.read(reviewLikeProvider(likeKey).notifier).toggleHeart();
      if (!context.mounted) return;
      await ref.read(likedReviewsProvider.notifier).syncReviewLikeState(
            reviewId: likeKey.reviewId,
            isLiked: likeState.isLiked,
          );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeartButton(
          count: likeCount,
          isActive: isLiked,
          onTap: onTapHeart,
        ),
        const SizedBox(height: 8),
        ReportButton(
          reviewId: reviewId,
          iconOnly: true,
          onReportSubmitted: onReportSubmitted,
        ),
      ],
    );
  }
}

class _HeartButton extends StatelessWidget {
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _HeartButton({
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.danger400 : AppColors.textHint;

    return Tooltip(
      message: isActive ? '하트 취소' : '하트',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isActive
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(isActive),
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: AppText.caption().copyWith(
                  color: color,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
