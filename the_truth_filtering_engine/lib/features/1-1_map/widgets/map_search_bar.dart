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
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.searchBarBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        onTap: onTap,
        cursorColor: AppColors.searchBarIcon,
        style: AppTextStyles.searchHint,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintStyle: AppTextStyles.searchHint,
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.searchBarIcon,
            size: 22,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 52,
          ),
          hintText: hintText,
        ),
      ),
    );
  }
}
