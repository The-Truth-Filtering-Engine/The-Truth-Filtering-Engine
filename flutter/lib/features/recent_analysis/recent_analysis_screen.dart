import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../map/models/restaurant_model.dart';
import 'recent_analysis_provider.dart';

class RecentAnalysisScreen extends ConsumerStatefulWidget {
  const RecentAnalysisScreen({
    super.key,
    required this.onViewPlace,
  });

  final ValueChanged<RestaurantModel> onViewPlace;

  @override
  ConsumerState<RecentAnalysisScreen> createState() =>
      _RecentAnalysisScreenState();
}

class _RecentAnalysisScreenState extends ConsumerState<RecentAnalysisScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentAnalysesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recentAnalysesProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('최근분석을 불러오지 못했습니다'),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.read(recentAnalysesProvider.notifier).load(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final items = [...data.freeItems, ...data.expiredItems];

        if (items.isEmpty) {
          return const Center(
            child: Text('저장된 최근 분석이 없습니다.'),
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            final restaurant = item.restaurant;

            return ListTile(
              leading: _RecentAnalysisDateBadge(
                label: _recentAnalysisDateBadgeLabel(item),
              ),
              title: Text(restaurant.name),
              subtitle: Text(_recentAnalysisSubtitle(item)),
              trailing: Icon(
                item.hasLocation
                    ? Icons.chevron_right
                    : Icons.location_off_outlined,
                color: AppColors.primary,
              ),
              onTap: () => _openRecentItem(item),
            );
          },
        );
      },
    );
  }

  void _openRecentItem(RecentAnalysisItem item) {
    if (!item.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최근분석 위치 정보를 찾지 못했습니다')),
      );
      return;
    }

    widget.onViewPlace(item.restaurant);
  }
}

String _recentAnalysisSubtitle(RecentAnalysisItem item) {
  final restaurant = item.restaurant;
  final address = restaurant.address.isEmpty ? '주소 정보 없음' : restaurant.address;
  return '${restaurant.category} · $address';
}

String _recentAnalysisDateBadgeLabel(RecentAnalysisItem item) {
  if (item.daysElapsed == 0) return '오늘';
  if (item.daysElapsed == 1) return '어제';

  final date = DateTime.tryParse(item.analyzedDate);
  if (date != null) return '${date.month}/${date.day}';

  return item.analyzedDate;
}

class _RecentAnalysisDateBadge extends StatelessWidget {
  final String label;

  const _RecentAnalysisDateBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
