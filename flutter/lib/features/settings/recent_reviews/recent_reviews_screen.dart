part of '../settings_screen.dart';

class _RecentReviewsSettingsScreen extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;

  const _RecentReviewsSettingsScreen({this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('최근 기록')),
      bottomNavigationBar: _SettingsFlowBottomNavigationBar(
        onTap: (index) => _selectMainTab(context, onSelectTab, index),
      ),
      body: const _RecentReviewsSettingsList(),
    );
  }
}

class _RecentReviewsSettingsList extends ConsumerWidget {
  const _RecentReviewsSettingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentRestaurants = ref.watch(recentVisitProvider);

    if (recentRestaurants.isEmpty) {
      return const _SettingsListMessage(
        icon: Icons.history,
        message: '최근 기록이 없습니다.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: recentRestaurants.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final restaurant = recentRestaurants[index];

        return _RecentReviewSettingsTile(
          restaurant: restaurant,
          onTap: () => _openReviewSource(context, restaurant.reviewUrl ?? ''),
          onRemove: () => ref
              .read(recentVisitProvider.notifier)
              .remove(restaurant.effectiveReviewId),
        );
      },
    );
  }
}

class _RecentReviewSettingsTile extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _RecentReviewSettingsTile({
    required this.restaurant,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      restaurant.category,
      restaurant.address,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    final textTheme = Theme.of(context).textTheme;
    final title = restaurant.reviewTitle?.trim() ?? '';
    final description = restaurant.reviewDescription?.trim().isNotEmpty == true
        ? restaurant.reviewDescription!.trim()
        : restaurant.reviewSummary.trim().isNotEmpty
            ? restaurant.reviewSummary.trim()
            : subtitle;

    return ListTile(
      leading: IconButton(
        tooltip: '최근 기록 삭제',
        icon: Icon(
          Icons.close_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: onRemove,
      ),
      title: Text(
        title.isEmpty ? '제목 없는 리뷰' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (restaurant.name.isNotEmpty)
            Text(
              restaurant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (description.isNotEmpty)
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
