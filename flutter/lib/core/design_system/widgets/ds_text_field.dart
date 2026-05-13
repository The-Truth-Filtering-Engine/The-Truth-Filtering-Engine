import 'package:flutter/material.dart';

import '../app_tokens.dart';

class DsTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? error;
  final String? success;
  final bool readOnly;
  final bool disabled;
  final bool obscureText;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? leadingIcon;

  const DsTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.error,
    this.success,
    this.readOnly = false,
    this.disabled = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final message = error ?? success ?? helperText;
    final messageColor = error != null
        ? AppColors.danger700
        : success != null
            ? AppColors.success700
            : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!.toUpperCase(), style: AppText.label()),
          const SizedBox(height: AppSpacing.x2),
        ],
        TextField(
          controller: controller,
          enabled: !disabled,
          readOnly: readOnly,
          obscureText: obscureText,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          onTap: onTap,
          cursorColor: AppColors.primary500,
          style: AppText.body().copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: leadingIcon,
            prefixIconColor: AppColors.textSecondary,
            fillColor: disabled ? AppColors.bg : AppColors.surface,
            hintStyle: AppText.body().copyWith(color: AppColors.textHint),
            enabledBorder: _border(_borderColor),
            focusedBorder: _border(_focusColor, width: 1.5),
            disabledBorder: _border(AppColors.border),
            errorBorder: _border(AppColors.danger400, width: 1.5),
            focusedErrorBorder: _border(AppColors.danger400, width: 1.5),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            message,
            style: AppText.caption().copyWith(
              color: messageColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Color get _borderColor {
    if (error != null) return AppColors.danger400;
    if (success != null) return AppColors.success400;
    return AppColors.border;
  }

  Color get _focusColor {
    if (error != null) return AppColors.danger400;
    if (success != null) return AppColors.success400;
    return AppColors.primary500;
  }

  OutlineInputBorder _border(Color color, {double width = 0.5}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
