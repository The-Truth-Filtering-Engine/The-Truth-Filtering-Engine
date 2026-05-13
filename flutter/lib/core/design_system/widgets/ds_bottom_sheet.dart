import 'package:flutter/material.dart';

import '../app_tokens.dart';

class DsBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool showHandle;

  const DsBottomSheet({
    super.key,
    required this.child,
    this.padding,
    this.showHandle = true,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (_) => DsBottomSheet(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sheetBackground,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: AppShadows.sheet,
      ),
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            const SizedBox(height: AppSpacing.x3),
            Container(
              width: AppSpacing.x10,
              height: AppSpacing.x1,
              decoration: BoxDecoration(
                color: AppColors.sheetDivider,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
          ],
          child,
        ],
      ),
    );
  }
}
