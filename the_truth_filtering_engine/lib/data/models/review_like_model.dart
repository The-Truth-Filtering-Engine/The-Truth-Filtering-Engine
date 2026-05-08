// ─────────────────────────────────────────────
// reviews 테이블 컬럼 구조
//   likes    : jsonb  → [{"user_email": "a@gmail.com"}, ...]
//   dislikes : jsonb  → [{"user_email": "b@gmail.com"}, ...]
// ─────────────────────────────────────────────

enum LikeType { like, dislike }

class ReviewLikeState {
  final int likeCount;
  final int dislikeCount;
  final bool isLiked;      // 내가 좋아요 눌렀는지
  final bool isDisliked;   // 내가 싫어요 눌렀는지

  const ReviewLikeState({
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.isLiked = false,
    this.isDisliked = false,
  });

  /// Supabase row 에서 파싱
  factory ReviewLikeState.fromRow(Map<String, dynamic> row, String userEmail) {
    final likes = _parseEmails(row['likes']);
    final dislikes = _parseEmails(row['dislikes']);

    return ReviewLikeState(
      likeCount: likes.length,
      dislikeCount: dislikes.length,
      isLiked: likes.contains(userEmail),
      isDisliked: dislikes.contains(userEmail),
    );
  }

  static Set<String> _parseEmails(dynamic json) {
    if (json == null) return {};
    return (json as List)
        .map((e) => (e as Map)['user_email']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
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