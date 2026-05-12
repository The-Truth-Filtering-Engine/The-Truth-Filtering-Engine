import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import '../config/supabase_config.dart';
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
        title: row['review_title']?.toString() ?? '',
        description: row['review_description']?.toString() ?? '',
        restaurantName: row['name']?.toString() ?? '',
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
    final currentUserId = userId;
    if (currentUserId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      Object? directLoadError;
      StackTrace? directLoadStackTrace;
      var liked = <LikedReview>[];

      try {
        liked = await _loadFromReviewLikes(currentUserId);
      } catch (error, stackTrace) {
        directLoadError = error;
        directLoadStackTrace = stackTrace;
      }

      final accountLikedIds = await _loadAccountLikedReviewIds();
      if (accountLikedIds.isNotEmpty) {
        final loadedIds = liked.map((review) => review.id).toSet();
        final missingIds = accountLikedIds.difference(loadedIds).toList();
        liked = [
          ...liked,
          ...await _loadReviewsByIds(missingIds, currentUserId),
        ];
      }

      if (liked.isEmpty && directLoadError != null && accountLikedIds.isEmpty) {
        Error.throwWithStackTrace(
          directLoadError,
          directLoadStackTrace ?? StackTrace.current,
        );
      }

      state = AsyncValue.data(liked);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<List<LikedReview>> _loadFromReviewLikes(int currentUserId) async {
    final likeFilter = jsonEncode([
      {'user_id': currentUserId},
    ]);

    final rows = await Supabase.instance.client
        .from('reviews')
        .select('id, review_title, review_description, name, likes')
        .contains('likes', likeFilter)
        .limit(200);

    return (rows as List<dynamic>)
        .map((row) => LikedReview.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<LikedReview>> _loadReviewsByIds(
    List<String> reviewIds,
    int currentUserId,
  ) async {
    if (reviewIds.isEmpty) return const [];

    final rows = await Supabase.instance.client
        .from('reviews')
        .select('id, review_title, review_description, name, likes')
        .inFilter('id', reviewIds)
        .limit(200);

    return (rows as List<dynamic>)
        .whereType<Map>()
        .where((row) => _rowHasUserLike(row, currentUserId))
        .map((row) => LikedReview.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  bool _rowHasUserLike(Map row, int currentUserId) {
    final likes = row['likes'];
    if (likes is! List) return false;

    return likes.any((entry) {
      if (entry is Map) {
        return int.tryParse(entry['user_id']?.toString() ?? '') ==
            currentUserId;
      }
      return int.tryParse(entry.toString()) == currentUserId;
    });
  }

  Future<Set<String>> _loadAccountLikedReviewIds() async {
    final token = _accessToken;
    if (token == null) return {};

    try {
      final response = await http.get(
        BackendConfig.apiUri('/user/me/review-reactions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {};
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return {};

      final reviewLikes = decoded['review_likes'];
      if (reviewLikes is! Map) return {};

      return reviewLikes.keys
          .map((key) => key.toString().trim())
          .where((key) => key.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  String? get _accessToken {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }
}
