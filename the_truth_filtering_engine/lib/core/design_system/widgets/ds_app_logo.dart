import 'package:flutter/material.dart';

import '../app_tokens.dart';

class DsAppLogo extends StatelessWidget {
  final bool showTitle;
  final double size;
  final String title;

  const DsAppLogo({
    super.key,
    this.showTitle = true,
    this.size = 32,
    this.title = '진실의 입',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.14),
          decoration: BoxDecoration(
            color: DsColors.logoSurface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: DsColors.logoInk.withValues(alpha: 0.22)),
          ),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
        if (showTitle) ...[
          const SizedBox(width: AppSpacing.x2),
          Text(
            title,
            style: AppText.subtitle().copyWith(
              color: AppColors.primary900,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
