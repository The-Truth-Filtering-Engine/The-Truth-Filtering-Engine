// ─────────────────────────────────────────────
// reviews 테이블 컬럼 구조
//   likes    : jsonb  → [{"user_id": 1}, ...]
//   dislikes : jsonb  → [{"user_id": 2}, ...]
// ─────────────────────────────────────────────

enum LikeType { like, dislike }

class ReviewLikeState {
  final int likeCount;
  final int dislikeCount;
  final bool isLiked; // 내가 좋아요 눌렀는지
  final bool isDisliked; // 내가 싫어요 눌렀는지

  const ReviewLikeState({
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.isLiked = false,
    this.isDisliked = false,
  });

  /// Supabase row 에서 파싱
  factory ReviewLikeState.fromRow(Map<String, dynamic> row, int userId) {
    final likes = _parseUserIds(row['likes']);
    final dislikes = _parseUserIds(row['dislikes']);

    return ReviewLikeState(
      likeCount: likes.length,
      dislikeCount: dislikes.length,
      isLiked: likes.contains(userId),
      isDisliked: dislikes.contains(userId),
    );
  }

  static Set<int> _parseUserIds(dynamic json) {
    if (json == null) return {};
    return (json as List)
        .map((e) => int.tryParse((e as Map)['user_id']?.toString() ?? ''))
        .whereType<int>()
        .toSet();
  }

  ReviewLikeState copyWith({
    int? likeCount,
    int? dislikeCount,
    bool? isLiked,
    bool? isDisliked,
  }) =>
      ReviewLikeState(
        likeCount: likeCount ?? this.likeCount,
        dislikeCount: dislikeCount ?? this.dislikeCount,
        isLiked: isLiked ?? this.isLiked,
        isDisliked: isDisliked ?? this.isDisliked,
      );
}
