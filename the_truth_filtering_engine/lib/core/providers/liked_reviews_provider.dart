import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/current_user_provider.dart';

/// 내가 하트 누른 리뷰 목록
final likedReviewsProvider =
    StateNotifierProvider<LikedReviewsNotifier, AsyncValue<List<LikedReview>>>(
  (ref) {
    final email = ref.watch(currentUserEmailProvider);
    return LikedReviewsNotifier(email: email);
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
  final String? email;

  LikedReviewsNotifier({required this.email})
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (email == null || email!.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      // reviews 테이블에서 likes 배열에 내 user_id가 포함된 행 조회
      // (user_id는 백엔드 users.id — Supabase RPC 없이 클라이언트에서 필터)
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id; // uuid
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // likes 배열에서 user_id 매칭은 contains 필터로
      final rows = await client
          .from('reviews')
          .select('id, title, review_description, restaurant_name, likes')
          .contains('likes', [{}]) // 전체 조회 후 클라이언트 필터
          .limit(200);

      // 내 이메일을 기준으로 클라이언트 사이드 필터
      // (user_id가 정수형인 경우 별도 처리 필요 — 여기선 이메일 기반)
      final liked = (rows as List<dynamic>)
          .where((row) {
            final likes = row['likes'];
            if (likes is! List) return false;
            return likes.any((e) => e is Map && e['user_email'] == email);
          })
          .map((e) => LikedReview.fromRow(e as Map<String, dynamic>))
          .toList();

      state = AsyncValue.data(liked);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
