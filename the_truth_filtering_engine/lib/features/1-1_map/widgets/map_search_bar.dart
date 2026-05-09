import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String hintText;

  const MapSearchBar({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.hintText = '음식점 또는 메뉴를 검색',
  });

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(14));
    final defaultBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide.none,
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(
        color: AppColors.markerVerified,
        width: 1.5,
      ),
    );

    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        onTap: onTap,
        cursorColor: AppColors.searchBarIcon,
        style: AppTextStyles.searchHint,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.searchBarBg,
          isDense: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: defaultBorder,
          enabledBorder: defaultBorder,
          focusedBorder: focusedBorder,
          hintStyle: AppTextStyles.searchHint,
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.searchBarIcon,
            size: 22,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 54,
            minHeight: 52,
          ),
          hintText: hintText,
        ),
      ),
    );
  }
}
