import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/recent_visit_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../1-1_map/models/restaurant_model.dart';

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
          onTap: () => onTapRestaurant?.call(r),
          onRemove: () =>
              ref.read(recentVisitProvider.notifier).remove(r.effectiveStoreId),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.store, color: Color(0xFF2B54E8), size: 22),
            ),
            const SizedBox(width: 12),
            // 식당 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: AppText.subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${restaurant.category} · ${restaurant.address}',
                    style: AppText.caption()
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 삭제 버튼
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Color(0xFFA0A0C0)),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
