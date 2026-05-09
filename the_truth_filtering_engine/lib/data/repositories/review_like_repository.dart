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

  Future<ReviewLikeState> toggle({
    required String reviewId,
    required int userId,
    required LikeType type,
    String? accessToken,
  }) async {
    final row = await _source.fetchLikes(reviewId);
    var likes = _parseList(row['likes']);
    var dislikes = _parseList(row['dislikes']);

    if (type == LikeType.like) {
      if (likes.any((e) => e['user_id'] == userId)) {
        likes.removeWhere((e) => e['user_id'] == userId);
      } else {
        likes.add({'user_id': userId});
        dislikes.removeWhere((e) => e['user_id'] == userId);
      }
    } else {
      if (dislikes.any((e) => e['user_id'] == userId)) {
        dislikes.removeWhere((e) => e['user_id'] == userId);
      } else {
        dislikes.add({'user_id': userId});
        likes.removeWhere((e) => e['user_id'] == userId);
      }
    }

    await _source.updateLikes(
      reviewId: reviewId,
      likes: likes,
      dislikes: dislikes,
    );

    final nextState = ReviewLikeState(
      likeCount: likes.length,
      dislikeCount: dislikes.length,
      isLiked: likes.any((e) => e['user_id'] == userId),
      isDisliked: dislikes.any((e) => e['user_id'] == userId),
    );

    final token = accessToken?.trim() ?? '';
    if (token.isNotEmpty) {
      try {
        await _source.syncUserReaction(
          accessToken: token,
          reviewId: reviewId,
          reaction: nextState.isLiked
              ? LikeType.like
              : nextState.isDisliked
                  ? LikeType.dislike
                  : null,
        );
      } catch (_) {
        // 리뷰 카운트 반영은 유지하고, 계정 동기화 실패만 삼킨다.
      }
    }

    return nextState;
  }

  List<Map<String, dynamic>> _parseList(dynamic json) {
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(
      (json as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => int.tryParse(e['user_id']?.toString() ?? '') != null)
          .map((e) => {'user_id': int.parse(e['user_id'].toString())}),
    );
  }
}
