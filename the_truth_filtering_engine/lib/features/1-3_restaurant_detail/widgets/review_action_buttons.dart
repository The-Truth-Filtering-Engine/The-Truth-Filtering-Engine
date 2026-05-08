import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/review_like_model.dart';
import '../providers/review_like_provider.dart';
import 'report_button.dart';

/// 👍 / 👎 / 🚩 세로 버튼 묶음
///
/// 사용:
/// ```dart
/// ReviewActionButtons(reviewId: review.id)
/// ```
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
    final isLoggedIn = email != null && email.isNotEmpty;
    final state = isLoggedIn ? ref.watch(reviewLikeProvider(reviewId)) : null;
    final ls = state?.likeState ?? const ReviewLikeState();

    void onTap(LikeType type) {
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
      ref.read(reviewLikeProvider(reviewId).notifier).toggle(type);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 좋아요 ──────────────────────────
        _ActionButton(
          icon: Icons.thumb_up_rounded,
          count: ls.likeCount,
          isActive: ls.isLiked,
          activeColor: AppColors.primary500,
          isLoading: state?.isLoading ?? false,
          onTap: () => onTap(LikeType.like),
        ),
        const SizedBox(height: 6),

        // ── 싫어요 ──────────────────────────
        _ActionButton(
          icon: Icons.thumb_down_rounded,
          count: ls.dislikeCount,
          isActive: ls.isDisliked,
          activeColor: AppColors.danger400,
          isLoading: state?.isLoading ?? false,
          onTap: () => onTap(LikeType.dislike),
        ),
        const SizedBox(height: 6),

        // ── 신고 (아이콘만) ──────────────────
        ReportButton(
          reviewId: reviewId,
          iconOnly: true,
          onReportSubmitted: onReportSubmitted,
        ),
      ],
    );
  }
}

// ── 개별 버튼 ─────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              icon,
              key: ValueKey(isActive),
              size: 18,
              color: isActive ? activeColor : AppColors.textHint,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: AppText.caption().copyWith(
              color: isActive ? activeColor : AppColors.textHint,
              fontSize: 10,
              height: 1.1,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
