import '../models/review_like_model.dart';
import '../sources/review_like_remote_source.dart';

class ReviewLikeRepository {
  final ReviewLikeRemoteSource _source;

  ReviewLikeRepository(this._source);

  Future<ReviewLikeState> fetchState({
    required String reviewId,
    required int userId,
    String? accessToken,
  }) async {
    final row = await _source.fetchLikes(reviewId);
    final likes = parseUserIdEntryList(row['likes']);
    final isRowLiked = likes.any((entry) => entry['user_id'] == userId);
    final accountLikedIds = await _fetchAccountLikedIds(accessToken);
    final isLiked = _isLiked(
      accountLikedIds: accountLikedIds,
      reviewId: reviewId,
      isRowLiked: isRowLiked,
    );

    try {
      await _reconcileSources(
        reviewId: reviewId,
        userId: userId,
        accessToken: accessToken,
        likes: likes,
        accountLikedIds: accountLikedIds,
        isLiked: isLiked,
      );
    } catch (_) {
      // State reads should not fail just because source reconciliation failed.
    }

    return ReviewLikeState(
      likeCount: likes.length,
      isLiked: isLiked,
    );
  }

  Future<ReviewLikeState> toggleHeart({
    required String reviewId,
    required int userId,
    String? accessToken,
  }) async {
    final row = await _source.fetchLikes(reviewId);
    final likes = parseUserIdEntryList(row['likes']);
    final isRowLiked = likes.any((entry) => entry['user_id'] == userId);
    final accountLikedIds = await _fetchAccountLikedIds(accessToken);
    final isAlreadyLiked = _isLiked(
      accountLikedIds: accountLikedIds,
      reviewId: reviewId,
      isRowLiked: isRowLiked,
    );

    if (isAlreadyLiked) {
      likes.removeWhere((entry) => entry['user_id'] == userId);
    } else {
      final now = DateTime.now().toUtc().toIso8601String();
      likes
        ..removeWhere((entry) => entry['user_id'] == userId)
        ..add(<String, dynamic>{
          'user_id': userId,
          'likedAt': now,
          'updatedAt': now,
        });
    }

    await _source.updateLikes(
      reviewId: reviewId,
      likes: likes,
    );

    final nextState = ReviewLikeState(
      likeCount: likes.length,
      isLiked: likes.any((entry) => entry['user_id'] == userId),
    );

    final token = accessToken?.trim() ?? '';
    if (token.isNotEmpty) {
      try {
        await _source.syncUserReaction(
          accessToken: token,
          reviewId: reviewId,
          reaction: nextState.isLiked ? LikeType.like : null,
        );
      } catch (_) {
        // Review count is already updated; account sync can recover later.
      }
    }

    return nextState;
  }

  Future<Set<String>?> _fetchAccountLikedIds(String? accessToken) async {
    try {
      return await _source.fetchUserLikedReviewIds(accessToken);
    } catch (_) {
      return null;
    }
  }

  bool _isLiked({
    required Set<String>? accountLikedIds,
    required String reviewId,
    required bool isRowLiked,
  }) {
    if (accountLikedIds == null) return isRowLiked;
    if (accountLikedIds.contains(reviewId)) return true;
    if (accountLikedIds.isEmpty && isRowLiked) return true;
    return false;
  }

  Future<void> _reconcileSources({
    required String reviewId,
    required int userId,
    required String? accessToken,
    required List<Map<String, dynamic>> likes,
    required Set<String>? accountLikedIds,
    required bool isLiked,
  }) async {
    if (accountLikedIds == null) return;

    final isRowLiked = likes.any((entry) => entry['user_id'] == userId);
    final token = accessToken?.trim() ?? '';

    if (isLiked && !isRowLiked) {
      final now = DateTime.now().toUtc().toIso8601String();
      likes.add(<String, dynamic>{
        'user_id': userId,
        'likedAt': now,
        'updatedAt': now,
      });
      await _source.updateLikes(
        reviewId: reviewId,
        likes: likes,
      );
      return;
    }

    if (isLiked && token.isNotEmpty && !accountLikedIds.contains(reviewId)) {
      try {
        await _source.syncUserReaction(
          accessToken: token,
          reviewId: reviewId,
          reaction: LikeType.like,
        );
      } catch (_) {}
    }

    if (!isLiked && isRowLiked) {
      likes.removeWhere((entry) => entry['user_id'] == userId);
      await _source.updateLikes(
        reviewId: reviewId,
        likes: likes,
      );
    }
  }
}
