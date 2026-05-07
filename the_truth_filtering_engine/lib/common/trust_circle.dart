import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class TrustCircle extends StatelessWidget {
  final int score;

  const TrustCircle(this.score, {super.key});

  Color getColor() {
    if (score >= 80) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: getColor(), width: 6),
      ),
      child: Center(
        child: Text('$score'),
      ),
    );
  }
}
