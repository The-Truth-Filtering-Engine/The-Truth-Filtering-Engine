import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class TruthScoreBadge extends StatelessWidget {
  final int score;

  const TruthScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.truthBadgeBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('TRUTH', style: AppTextStyles.truthLabel),
          const SizedBox(height: 2),
          Text('$score', style: AppTextStyles.truthScore),
        ],
      ),
    );
  }
}
