import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/map_provider.dart';
import '../../1-3_restaurant_detail/screens/restaurant_detail_screen.dart';

class BookmarkScreen extends ConsumerWidget {
  const BookmarkScreen({super.key});

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
          trailing: IconButton(
            icon: const Icon(Icons.bookmark, color: AppColors.primary),
            onPressed: () {
              ref.read(bookmarkRestaurantsProvider.notifier).remove(restaurant);
            },
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RestaurantDetailScreen(
                  restaurant: restaurant,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
