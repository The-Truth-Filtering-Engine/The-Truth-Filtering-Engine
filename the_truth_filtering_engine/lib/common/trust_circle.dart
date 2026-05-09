import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class TrustCircle extends StatelessWidget {
  final int score;

  const TrustCircle(this.score, {super.key});

  Color getColor() {
    if (score >= 80) return AppColors.success400;
    if (score >= 40) return AppColors.warning400;
    return AppColors.danger400;
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
