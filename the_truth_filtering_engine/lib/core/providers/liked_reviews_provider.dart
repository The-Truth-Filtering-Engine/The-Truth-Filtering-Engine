import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'current_user_provider.dart';
import 'user_profile_provider.dart';

final likedReviewsProvider =
    StateNotifierProvider<LikedReviewsNotifier, AsyncValue<List<LikedReview>>>(
  (ref) {
    final authState = ref.watch(appAuthProvider);
    final profileState = ref.watch(userProfileProvider);
    final userId = ref.watch(currentUserIdProvider);

    if (authState.isLoggedIn && userId == null && !profileState.isLoading) {
      Future.microtask(
        () => ref.read(userProfileProvider.notifier).loadIfPossible(),
      );
    }

    return LikedReviewsNotifier(userId: userId);
  },
);

class LikedReview {
  final String id;
  final String title;
  final String description;
  final String restaurantName;

  const LikedReview({
    required this.id,
    required this.title,
    required this.description,
    required this.restaurantName,
  });

  factory LikedReview.fromRow(Map<String, dynamic> row) => LikedReview(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        description: row['review_description']?.toString() ?? '',
        restaurantName: row['restaurant_name']?.toString() ?? '',
      );
}

class LikedReviewsNotifier
    extends StateNotifier<AsyncValue<List<LikedReview>>> {
  final int? userId;

  LikedReviewsNotifier({required this.userId})
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (userId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final rows = await Supabase.instance.client
          .from('reviews')
          .select('id, title, review_description, restaurant_name, likes')
          .contains('likes', [
        {'user_id': userId}
      ]).limit(200);

      final liked = (rows as List<dynamic>)
          .map((row) => LikedReview.fromRow(row as Map<String, dynamic>))
          .toList();

      state = AsyncValue.data(liked);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
