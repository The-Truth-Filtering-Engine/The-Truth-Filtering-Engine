import 'package:flutter/material.dart';

import '../app_tokens.dart';

class DsButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final bool loading;
  final bool fullWidth;
  final Widget? leftIcon;
  final Widget? rightIcon;

  const DsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.size = DsButtonSize.md,
    this.loading = false,
    this.fullWidth = true,
    this.leftIcon,
    this.rightIcon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = _ButtonContent(
      label: label,
      loading: loading,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      color: _contentColor,
    );
    final button = switch (variant) {
      DsButtonVariant.primary => ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: _baseStyle().copyWith(
            backgroundColor: const WidgetStatePropertyAll(AppColors.primary),
            foregroundColor: const WidgetStatePropertyAll(AppColors.background),
          ),
          child: child,
        ),
      DsButtonVariant.secondary => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: _baseStyle().copyWith(
            backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
            foregroundColor:
                const WidgetStatePropertyAll(AppColors.textPrimary),
            side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.border),
            ),
          ),
          child: child,
        ),
      DsButtonVariant.ghost => TextButton(
          onPressed: enabled ? onPressed : null,
          style: _baseStyle().copyWith(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            foregroundColor:
                const WidgetStatePropertyAll(AppColors.textSecondary),
          ),
          child: child,
        ),
      DsButtonVariant.danger => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: _baseStyle().copyWith(
            backgroundColor: const WidgetStatePropertyAll(AppColors.danger50),
            foregroundColor: const WidgetStatePropertyAll(AppColors.danger700),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0x2EB91C1C)),
            ),
          ),
          child: child,
        ),
    };

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _height,
      child: button,
    );
  }

  ButtonStyle _baseStyle() {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: _horizontalPadding),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        AppText.body().copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  double get _height => switch (size) {
        DsButtonSize.sm => 36,
        DsButtonSize.md => 42,
        DsButtonSize.lg => 50,
      };

  double get _horizontalPadding => switch (size) {
        DsButtonSize.sm => AppSpacing.x3,
        DsButtonSize.md => AppSpacing.x4,
        DsButtonSize.lg => AppSpacing.x5,
      };

  Color get _contentColor => switch (variant) {
        DsButtonVariant.primary => AppColors.background,
        DsButtonVariant.secondary => AppColors.textPrimary,
        DsButtonVariant.ghost => AppColors.textSecondary,
        DsButtonVariant.danger => AppColors.danger700,
      };
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final bool loading;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final Color color;

  const _ButtonContent({
    required this.label,
    required this.loading,
    required this.leftIcon,
    required this.rightIcon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          )
        else if (leftIcon != null)
          IconTheme(
            data: IconThemeData(color: color, size: 18),
            child: leftIcon!,
          ),
        if (loading || leftIcon != null) const SizedBox(width: AppSpacing.x2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (rightIcon != null) ...[
          const SizedBox(width: AppSpacing.x2),
          IconTheme(
            data: IconThemeData(color: color, size: 18),
            child: rightIcon!,
          ),
        ],
      ],
    );
  }
}
