enum LikeType { like }

class ReviewLikeState {
  final int likeCount;
  final bool isLiked;

  const ReviewLikeState({
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory ReviewLikeState.fromRow(Map<String, dynamic> row, int userId) {
    final likes = parseUserIdEntries(row['likes']);

    return ReviewLikeState(
      likeCount: likes.length,
      isLiked: likes.contains(userId),
    );
  }

  ReviewLikeState copyWith({
    int? likeCount,
    bool? isLiked,
  }) =>
      ReviewLikeState(
        likeCount: likeCount ?? this.likeCount,
        isLiked: isLiked ?? this.isLiked,
      );
}

Set<int> parseUserIdEntries(dynamic json) {
  if (json is! List) return {};

  return json
      .map((entry) {
        if (entry is Map) {
          return int.tryParse(entry['user_id']?.toString() ?? '');
        }
        return int.tryParse(entry.toString());
      })
      .whereType<int>()
      .toSet();
}

List<Map<String, dynamic>> parseUserIdEntryList(dynamic json) {
  return parseUserIdEntries(json)
      .map((userId) => <String, dynamic>{'user_id': userId})
      .toList();
}
