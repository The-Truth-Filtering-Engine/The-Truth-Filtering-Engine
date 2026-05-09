import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/restaurant_model.dart';

class RestaurantBottomSheet extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onDetailTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onCallTap;
  final VoidCallback? onRouteTap;
  final bool isBookmarked;
  final String detailButtonLabel;

  const RestaurantBottomSheet({
    super.key,
    required this.restaurant,
    this.onDetailTap,
    this.onBookmarkTap,
    this.onShareTap,
    this.onCallTap,
    this.onRouteTap,
    this.isBookmarked = false,
    this.detailButtonLabel = '상세 보기',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.sheetDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 본문 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 이미지 + 정보
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: restaurant.imageUrl != null
                            ? Image.network(
                                restaurant.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  restaurant.categoryThumbnailPath,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                restaurant.categoryThumbnailPath,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // 이름 + 주소 + 카테고리
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: AppTextStyles.restaurantName,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.sheetSubtext,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${restaurant.address} · ${restaurant.category}',
                                  style: AppTextStyles.restaurantMeta,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 액션 버튼 영역 (Call, Save, Route, Share)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionItem(
                      icon: Icons.phone_outlined,
                      label: 'Call',
                      onTap: onCallTap,
                    ),
                    _ActionItem(
                      icon: isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_outline,
                      label: 'Save',
                      onTap: onBookmarkTap,
                      iconColor: isBookmarked
                          ? const Color(0xFF2B54E8)
                          : const Color(0xFF2B54E8),
                    ),
                    _ActionItem(
                      icon: Icons.near_me_outlined,
                      label: 'Route',
                      onTap: onRouteTap,
                    ),
                    _ActionItem(
                      icon: Icons.ios_share_outlined,
                      label: 'Share',
                      onTap: onShareTap,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 버튼 영역 (상세보기)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onDetailTap,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  detailButtonLabel,
                                  style: AppTextStyles.primaryButton,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color iconColor;

  const _ActionItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor = const Color(0xFF2B54E8),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6060A0)),
          ),
        ],
      ),
    );
  }
}
