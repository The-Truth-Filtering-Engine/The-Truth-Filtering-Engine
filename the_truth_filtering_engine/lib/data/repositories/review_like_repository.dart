import '../models/review_like_model.dart';
import '../sources/review_like_remote_source.dart';

class ReviewLikeRepository {
  final ReviewLikeRemoteSource _source;

  ReviewLikeRepository(this._source);

  Future<ReviewLikeState> fetchState({
    required String reviewId,
    required int userId,
  }) async {
    final row = await _source.fetchLikes(reviewId);
    return ReviewLikeState.fromRow(row, userId);
  }

  Future<ReviewLikeState> toggleHeart({
    required String reviewId,
    required int userId,
    String? accessToken,
  }) async {
    final row = await _source.fetchLikes(reviewId);
    final likes = parseUserIdEntryList(row['likes']);
    final dislikes = parseUserIdEntryList(row['dislikes']);
    final isAlreadyLiked = likes.any((entry) => entry['user_id'] == userId);

    if (isAlreadyLiked) {
      likes.removeWhere((entry) => entry['user_id'] == userId);
    } else {
      likes.add(<String, dynamic>{'user_id': userId});
      dislikes.removeWhere((entry) => entry['user_id'] == userId);
    }

    await _source.updateLikes(
      reviewId: reviewId,
      likes: likes,
      dislikes: dislikes,
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
}
