import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/widgets/widgets.dart';
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
    return DsBottomSheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          0,
          AppSpacing.x5,
          AppSpacing.x6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                const SizedBox(width: AppSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: AppTextStyles.restaurantName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.x1),
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
            const SizedBox(height: AppSpacing.x5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionItem(
                  icon: Icons.phone_outlined,
                  label: 'Call',
                  onTap: onCallTap,
                ),
                _ActionItem(
                  icon: isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  label: 'Save',
                  onTap: onBookmarkTap,
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
            const SizedBox(height: AppSpacing.x5),
            DsButton(
              label: detailButtonLabel,
              size: DsButtonSize.lg,
              onPressed: onDetailTap,
              leftIcon: const Icon(Icons.info_outline, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary500),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              label,
              style: AppText.caption().copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
