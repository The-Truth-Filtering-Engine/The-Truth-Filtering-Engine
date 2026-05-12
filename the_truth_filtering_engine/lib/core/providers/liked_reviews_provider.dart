import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import '../config/supabase_config.dart';
import '../../data/models/review_like_model.dart';
import '../../features/1-1_map/models/restaurant_model.dart';
import 'current_user_provider.dart';
import 'user_profile_provider.dart';

const _likedReviewSelectColumns =
    'id, review_title, review_description, review_url, name, likes, store_id, '
    'category_name, category_group_code, category_group_name, phone, '
    'address_name, road_address_name, place_url';

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
  final String reviewUrl;
  final String restaurantName;
  final RestaurantModel restaurant;

  const LikedReview({
    required this.id,
    required this.title,
    required this.description,
    required this.reviewUrl,
    required this.restaurantName,
    required this.restaurant,
  });

  factory LikedReview.fromRow(Map<String, dynamic> row) {
    final restaurantName = row['name']?.toString() ?? '';
    final storeId = row['store_id']?.toString() ?? '';
    final categoryName = row['category_name']?.toString() ?? '';
    final addressName = row['address_name']?.toString() ?? '';
    final roadAddressName = row['road_address_name']?.toString() ?? '';
    final address = roadAddressName.isNotEmpty ? roadAddressName : addressName;

    return LikedReview(
      id: row['id']?.toString() ?? '',
      title: row['review_title']?.toString() ?? '',
      description: row['review_description']?.toString() ?? '',
      reviewUrl: row['review_url']?.toString() ?? '',
      restaurantName: restaurantName,
      restaurant: RestaurantModel(
        id: storeId.isNotEmpty ? storeId : restaurantName,
        storeId: storeId.isEmpty ? null : storeId,
        name: restaurantName,
        address: address,
        category: categoryName.isEmpty ? '음식점' : categoryName,
        categoryName: categoryName.isEmpty ? null : categoryName,
        categoryGroupCode: row['category_group_code']?.toString(),
        categoryGroupName: row['category_group_name']?.toString(),
        truthScore: 0,
        reviewSummary: '',
        phone: row['phone']?.toString(),
        placeUrl: row['place_url']?.toString(),
        addressName: addressName.isEmpty ? null : addressName,
        roadAddressName: roadAddressName.isEmpty ? null : roadAddressName,
        latitude: 0,
        longitude: 0,
      ),
    );
  }
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
        .select(_likedReviewSelectColumns)
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
        .select(_likedReviewSelectColumns)
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

  Future<void> remove(String reviewId) async {
    final currentUserId = userId;
    if (currentUserId == null || reviewId.trim().isEmpty) return;

    final previous = state.valueOrNull ?? const <LikedReview>[];
    state = AsyncValue.data(
      previous.where((review) => review.id != reviewId).toList(),
    );

    try {
      final row = await Supabase.instance.client
          .from('reviews')
          .select('likes')
          .eq('id', reviewId)
          .single();

      final likes = parseUserIdEntryList(row['likes'])
        ..removeWhere((entry) => entry['user_id'] == currentUserId);

      await Supabase.instance.client
          .from('reviews')
          .update({'likes': likes}).eq('id', reviewId);

      await _syncAccountReaction(reviewId, null);
    } catch (error, stackTrace) {
      state = AsyncValue.data(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
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

  Future<void> _syncAccountReaction(String reviewId, String? reaction) async {
    final token = _accessToken;
    if (token == null) return;

    final response = await http.put(
      BackendConfig.apiUri('/user/me/review-reactions'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reviewId': reviewId,
        'reaction': reaction,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('review reaction sync failed: ${response.statusCode}');
    }
  }

  String? get _accessToken {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }
}
