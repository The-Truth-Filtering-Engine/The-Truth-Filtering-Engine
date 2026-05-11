import 'package:flutter/material.dart';

import '../app_tokens.dart';

class DsToast extends StatelessWidget {
  final String message;
  final DsTone tone;

  const DsToast({
    super.key,
    required this.message,
    this.tone = DsTone.info,
  });

  static void show(
    BuildContext context,
    String message, {
    DsTone tone = DsTone.info,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: dsToneAccent(tone),
        content: DsToast(message: message, tone: tone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppText.body().copyWith(
        color:
            tone == DsTone.warning ? AppColors.primary : AppColors.background,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class DsDialog extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final List<Widget>? actions;

  const DsDialog({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.actions,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? description,
    required Widget child,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => DsDialog(
        title: title,
        description: description,
        actions: actions,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(title, style: AppText.title()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            Text(description!, style: AppText.body()),
            const SizedBox(height: AppSpacing.x4),
          ],
          child,
        ],
      ),
      actions: actions,
    );
  }
}
