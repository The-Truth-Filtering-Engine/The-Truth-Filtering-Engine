import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/restaurant_model.dart';
import '../providers/map_provider.dart';

class BookmarkScreen extends ConsumerWidget {
  final ValueChanged<RestaurantModel> onViewPlace;

  const BookmarkScreen({
    super.key,
    required this.onViewPlace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkRestaurantsProvider);

    if (bookmarks.isEmpty) {
      return const Center(
        child: Text('아직 북마크한 가게가 없습니다'),
      );
    }

    return ListView.separated(
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final restaurant = bookmarks[index];
        return ListTile(
          title: Text(restaurant.name),
          subtitle: Text('${restaurant.category} · ${restaurant.address}'),
          leading: IconButton(
            icon: const Icon(Icons.bookmark, color: AppColors.primary),
            onPressed: () {
              ref.read(bookmarkRestaurantsProvider.notifier).remove(restaurant);
            },
          ),
          onTap: () {
            onViewPlace(restaurant);
          },
        );
      },
    );
  }
}
