import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import '../config/test_account_auth_config.dart';
import '../../data/models/review_like_model.dart';
import '../../features/map/models/restaurant_model.dart';
import 'current_user_provider.dart';
import 'user_profile_provider.dart';

const _likedReviewSelectColumns =
    'id, review_title, review_description, review_url, name, likes, '
    'store_id, category_name, category_group_code, category_group_name, '
    'phone, address_name, road_address_name, place_url';

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

    return LikedReviewsNotifier(
      userId: userId,
      isTestAccountLogin: authState.isTestAccountLogin,
    );
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
    final reviewId = row['id']?.toString() ?? '';
    final title = row['review_title']?.toString() ?? '';
    final description = row['review_description']?.toString() ?? '';
    final reviewUrl = row['review_url']?.toString() ?? '';
    final restaurantName = row['name']?.toString() ?? '';
    final storeId = row['store_id']?.toString() ?? '';
    final categoryName = row['category_name']?.toString() ?? '';
    final addressName = row['address_name']?.toString() ?? '';
    final roadAddressName = row['road_address_name']?.toString() ?? '';
    final address = roadAddressName.isNotEmpty ? roadAddressName : addressName;

    return LikedReview(
      id: reviewId,
      title: title,
      description: description,
      reviewUrl: reviewUrl,
      restaurantName: restaurantName,
      restaurant: RestaurantModel(
        id: storeId.isNotEmpty ? storeId : restaurantName,
        storeId: storeId.isEmpty ? null : storeId,
        reviewId: reviewId,
        name: restaurantName,
        address: address,
        category: categoryName.isEmpty ? '음식점' : categoryName,
        categoryName: categoryName.isEmpty ? null : categoryName,
        categoryGroupCode: row['category_group_code']?.toString(),
        categoryGroupName: row['category_group_name']?.toString(),
        truthScore: 0,
        reviewSummary: description,
        reviewUrl: reviewUrl,
        reviewTitle: title,
        reviewDescription: description,
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
  final bool isTestAccountLogin;
  final _locallyUnlikedReviewIds = <String>{};

  LikedReviewsNotifier({
    required this.userId,
    required this.isTestAccountLogin,
  })
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
      if (accountLikedIds != null) {
        final activeAccountLikedIds = accountLikedIds
            .where((id) => !_locallyUnlikedReviewIds.contains(id))
            .toList();
        if (activeAccountLikedIds.isNotEmpty) {
          final accountLiked = await _loadReviewsByIds(
            activeAccountLikedIds,
            currentUserId,
            ensureReviewLikes: true,
          );
          liked = _mergeLikedReviews(liked, accountLiked);
        } else if (liked.isNotEmpty) {
          await _backfillAccountLikes(liked);
        }
      }

      if (liked.isEmpty &&
          directLoadError != null &&
          (accountLikedIds == null || accountLikedIds.isEmpty)) {
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
    final likeFilter = [
      {'user_id': currentUserId},
    ];

    try {
      final rows = await Supabase.instance.client
          .from('reviews')
          .select(_likedReviewSelectColumns)
          .contains('likes', likeFilter)
          .limit(200);

      final directlyMatched = (rows as List<dynamic>)
          .map((row) => LikedReview.fromRow(row as Map<String, dynamic>))
          .toList();

      if (directlyMatched.isNotEmpty) return directlyMatched;
    } catch (_) {}

    return _loadFromNonEmptyReviewLikes(currentUserId);
  }

  Future<List<LikedReview>> _loadFromNonEmptyReviewLikes(
    int currentUserId,
  ) async {
    final rows = await Supabase.instance.client
        .from('reviews')
        .select(_likedReviewSelectColumns)
        .neq('likes', const []).limit(1000);

    return (rows as List<dynamic>)
        .whereType<Map>()
        .where((row) => _rowHasUserLike(row, currentUserId))
        .map((row) => LikedReview.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<LikedReview>> _loadReviewsByIds(
    List<String> reviewIds,
    int currentUserId, {
    bool ensureReviewLikes = false,
  }) async {
    if (reviewIds.isEmpty) return const [];

    final rows = await Supabase.instance.client
        .from('reviews')
        .select(_likedReviewSelectColumns)
        .inFilter('id', reviewIds)
        .limit(200);

    final maps = (rows as List<dynamic>)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    if (ensureReviewLikes) {
      for (final row in maps) {
        await _ensureReviewLike(row, currentUserId);
      }
    }

    return maps.map(LikedReview.fromRow).toList();
  }

  List<LikedReview> _mergeLikedReviews(
    List<LikedReview> directReviews,
    List<LikedReview> accountReviews,
  ) {
    final byId = <String, LikedReview>{};
    for (final review in [...directReviews, ...accountReviews]) {
      if (review.id.trim().isEmpty) continue;
      byId[review.id] = review;
    }
    return byId.values.toList();
  }

  bool _rowHasUserLike(Map row, int currentUserId) {
    return parseUserIdEntryList(row['likes']).any(
      (entry) => entry['user_id'] == currentUserId,
    );
  }

  Future<void> _backfillAccountLikes(List<LikedReview> reviews) async {
    for (final review in reviews) {
      try {
        await _syncAccountReaction(review.id, 'like');
      } catch (_) {}
    }
  }

  Future<void> _ensureReviewLike(
    Map<String, dynamic> row,
    int currentUserId,
  ) async {
    if (_rowHasUserLike(row, currentUserId)) return;

    final reviewId = row['id']?.toString().trim() ?? '';
    if (reviewId.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final likes = parseUserIdEntryList(row['likes'])
      ..removeWhere((entry) => entry['user_id'] == currentUserId)
      ..add(<String, dynamic>{
        'user_id': currentUserId,
        'likedAt': now,
        'updatedAt': now,
      });

    try {
      await Supabase.instance.client.from('reviews').update({
        'likes': likes,
      }).eq('id', reviewId);
    } catch (_) {}
  }

  Future<void> remove(String reviewId) async {
    final currentUserId = userId;
    final normalizedReviewId = reviewId.trim();
    if (currentUserId == null || normalizedReviewId.isEmpty) return;

    _locallyUnlikedReviewIds.add(normalizedReviewId);

    final previous = state.valueOrNull ?? const <LikedReview>[];
    state = AsyncValue.data(
      previous.where((review) => review.id != normalizedReviewId).toList(),
    );

    try {
      final row = await Supabase.instance.client
          .from('reviews')
          .select('likes')
          .eq('id', normalizedReviewId)
          .single();

      final likes = parseUserIdEntryList(row['likes'])
        ..removeWhere((entry) => entry['user_id'] == currentUserId);

      await Supabase.instance.client
          .from('reviews')
          .update({'likes': likes}).eq('id', normalizedReviewId);

      await _syncAccountReaction(normalizedReviewId, null);
    } catch (error, stackTrace) {
      state = AsyncValue.data(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> syncReviewLikeState({
    required String reviewId,
    required bool isLiked,
  }) async {
    final normalizedReviewId = reviewId.trim();
    if (normalizedReviewId.isEmpty) return;

    if (isLiked) {
      _locallyUnlikedReviewIds.remove(normalizedReviewId);
      await load();
      await _ensureLoadedReviewIsVisible(normalizedReviewId);
      return;
    }

    _locallyUnlikedReviewIds.add(normalizedReviewId);
    final previous = state.valueOrNull;
    if (previous == null) return;

    state = AsyncValue.data(
      previous.where((review) => review.id != normalizedReviewId).toList(),
    );
  }

  Future<void> _ensureLoadedReviewIsVisible(String reviewId) async {
    final currentUserId = userId;
    if (currentUserId == null) return;

    final current = state.valueOrNull ?? const <LikedReview>[];
    if (current.any((review) => review.id == reviewId)) return;

    try {
      final loaded = await _loadReviewsByIds(
        [reviewId],
        currentUserId,
        ensureReviewLikes: true,
      );
      if (loaded.isEmpty) return;

      state = AsyncValue.data(_mergeLikedReviews(current, loaded));
    } catch (_) {
      // The next screen refresh can recover if the immediate backfill fails.
    }
  }

  Future<Set<String>?> _loadAccountLikedReviewIds() async {
    final headers = _authHeaders;
    if (headers == null) return null;

    try {
      final response = await http.get(
        BackendConfig.apiUri('/user/me/review-reactions'),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
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
      return null;
    }
  }

  Future<void> _syncAccountReaction(String reviewId, String? reaction) async {
    final headers = _authHeaders;
    if (headers == null) return;

    final response = await http.put(
      BackendConfig.apiUri('/user/me/review-reactions'),
      headers: {
        ...headers,
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

  Map<String, String>? get _authHeaders {
    final headers = TestAccountAuthConfig.headers(
      isTestAccountLogin: isTestAccountLogin,
    );
    return headers.isEmpty ? null : headers;
  }
}
