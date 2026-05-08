import '../models/review_like_model.dart';
import '../sources/review_like_remote_source.dart';

class ReviewLikeRepository {
  final ReviewLikeRemoteSource _source;

  ReviewLikeRepository(this._source);

  // ── 현재 상태 조회 ─────────────────────────
  Future<ReviewLikeState> fetchState({
    required String reviewId,
    required String userEmail,
  }) async {
    final row = await _source.fetchLikes(reviewId);
    return ReviewLikeState.fromRow(row, userEmail);
  }

  // ── 좋아요/싫어요 토글 ─────────────────────
  Future<ReviewLikeState> toggle({
    required String reviewId,
    required String userEmail,
    required LikeType type,
  }) async {
    final row = await _source.fetchLikes(reviewId);
    var likes = _parseList(row['likes']);
    var dislikes = _parseList(row['dislikes']);

    if (type == LikeType.like) {
      if (likes.any((e) => e['user_email'] == userEmail)) {
        // 이미 좋아요 → 취소
        likes.removeWhere((e) => e['user_email'] == userEmail);
      } else {
        // 좋아요 추가, 싫어요 제거
        likes.add({'user_email': userEmail});
        dislikes.removeWhere((e) => e['user_email'] == userEmail);
      }
    } else {
      if (dislikes.any((e) => e['user_email'] == userEmail)) {
        // 이미 싫어요 → 취소
        dislikes.removeWhere((e) => e['user_email'] == userEmail);
      } else {
        // 싫어요 추가, 좋아요 제거
        dislikes.add({'user_email': userEmail});
        likes.removeWhere((e) => e['user_email'] == userEmail);
      }
    }

    await _source.updateLikes(
      reviewId: reviewId,
      likes: likes,
      dislikes: dislikes,
    );

    return ReviewLikeState(
      likeCount: likes.length,
      dislikeCount: dislikes.length,
      isLiked: likes.any((e) => e['user_email'] == userEmail),
      isDisliked: dislikes.any((e) => e['user_email'] == userEmail),
    );
  }

  List<Map<String, dynamic>> _parseList(dynamic json) {
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(
      (json as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }
}