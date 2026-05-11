import 'package:flutter/material.dart';

import '../app_tokens.dart';

class DsBadge extends StatelessWidget {
  final String label;
  final DsTone tone;

  const DsBadge({
    super.key,
    required this.label,
    this.tone = DsTone.info,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: dsToneBackground(tone),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppText.caption().copyWith(
          color: dsToneForeground(tone),
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}
