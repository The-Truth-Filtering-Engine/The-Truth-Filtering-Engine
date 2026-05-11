import 'package:flutter/material.dart';

import 'package:truth_mouth/models/blog_review_model.dart';
import '../../../core/theme/app_colors.dart';

class ReviewGradeBadge extends StatelessWidget {
  final ReviewStatus status;

  const ReviewGradeBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      ReviewStatus.real => (AppColors.successBg, AppColors.success),
      ReviewStatus.suspicious => (AppColors.warningBg, AppColors.warning),
      ReviewStatus.ad => (AppColors.dangerBg, AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        _labelOf(status),
        style: TextStyle(
          color: colors.$2,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _labelOf(ReviewStatus status) {
    return switch (status) {
      ReviewStatus.real => '리얼',
      ReviewStatus.suspicious => '의심',
      ReviewStatus.ad => '광고',
    };
  }
}

