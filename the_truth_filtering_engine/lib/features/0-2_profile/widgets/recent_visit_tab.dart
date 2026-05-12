import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/recent_visit_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../../1-3_restaurant_detail/utils/blog_review_url.dart';

class RecentVisitTab extends ConsumerWidget {
  final ValueChanged<RestaurantModel>? onTapRestaurant;

  const RecentVisitTab({super.key, this.onTapRestaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(recentVisitProvider);

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              '최근 본 식당이 없습니다.',
              style: AppText.body().copyWith(color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFE4E4EC)),
      itemBuilder: (ctx, i) {
        final r = list[i];
        return _RecentVisitTile(
          restaurant: r,
          onTap: () async {
            if (onTapRestaurant != null) {
              onTapRestaurant!(r);
              return;
            }

            final uri = mobileBlogReviewUri(r.reviewUrl ?? '');
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          onRemove: () => ref
              .read(recentVisitProvider.notifier)
              .remove(r.effectiveReviewId),
        );
      },
    );
  }
}

class _RecentVisitTile extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentVisitTile({
    required this.restaurant,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = restaurant.reviewTitle?.trim() ?? '';
    final description = _firstText([
      restaurant.reviewDescription,
      restaurant.reviewSummary,
    ]);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              tooltip: '최근 기록 삭제',
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFFA0A0C0),
                size: 18,
              ),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (restaurant.name.isNotEmpty)
                    Text(
                      restaurant.name,
                      style: AppText.caption()
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    title.isEmpty ? '제목 없는 리뷰' : title,
                    style: AppText.subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppText.body()
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _firstText(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }
}
