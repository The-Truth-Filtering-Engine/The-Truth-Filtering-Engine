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

class _RecentReviewsSettingsList extends ConsumerStatefulWidget {
  const _RecentReviewsSettingsList();

  @override
  ConsumerState<_RecentReviewsSettingsList> createState() =>
      _RecentReviewsSettingsListState();
}

class _RecentReviewsSettingsListState
    extends ConsumerState<_RecentReviewsSettingsList> {
  final Map<String, RestaurantModel> _pendingRemovalRestaurants = {};

  @override
  void dispose() {
    _flushPendingRemovals();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        final removalKey = restaurant.effectiveReviewId;

        return _RecentReviewSettingsTile(
          restaurant: restaurant,
          isPendingRemoval: _pendingRemovalRestaurants.containsKey(removalKey),
          onTap: () => _openReviewSource(context, restaurant.reviewUrl ?? ''),
          onRemove: () => _togglePendingRemoval(restaurant),
        );
      },
    );
  }

  void _togglePendingRemoval(RestaurantModel restaurant) {
    final key = restaurant.effectiveReviewId;
    setState(() {
      if (_pendingRemovalRestaurants.containsKey(key)) {
        _pendingRemovalRestaurants.remove(key);
      } else {
        _pendingRemovalRestaurants[key] = restaurant;
      }
    });
  }

  void _flushPendingRemovals() {
    if (_pendingRemovalRestaurants.isEmpty) return;
    final restaurants = List<RestaurantModel>.of(
      _pendingRemovalRestaurants.values,
    );
    _pendingRemovalRestaurants.clear();

    final notifier = ref.read(recentVisitProvider.notifier);
    for (final restaurant in restaurants) {
      unawaited(notifier.remove(restaurant.effectiveReviewId));
    }
  }
}

class _RecentReviewSettingsTile extends StatelessWidget {
  final RestaurantModel restaurant;
  final bool isPendingRemoval;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _RecentReviewSettingsTile({
    required this.restaurant,
    required this.isPendingRemoval,
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
        tooltip: isPendingRemoval ? '삭제 예정 취소' : '최근 기록 삭제',
        icon: Icon(
          Icons.close_rounded,
          color: isPendingRemoval
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.primary,
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
