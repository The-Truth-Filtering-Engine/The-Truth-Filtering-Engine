import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class MapSearchBar extends StatelessWidget {
  final VoidCallback? onTap;

  const MapSearchBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: AppColors.searchBarIcon,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              '맛집 또는 지역 검색',
              style: AppTextStyles.searchHint,
            ),
          ],
        ),
      ),
    );
  }
}
