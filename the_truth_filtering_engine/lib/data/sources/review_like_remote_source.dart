import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewLikeRemoteSource {
  final SupabaseClient _client;
  static const _table = 'reviews';

  ReviewLikeRemoteSource(this._client);

  // ── 현재 likes/dislikes 조회 ───────────────
  Future<Map<String, dynamic>> fetchLikes(String reviewId) async {
    final res = await _client
        .from(_table)
        .select('likes, dislikes')
        .eq('id', reviewId)
        .single();
    return res;
  }

  // ── likes/dislikes 동시 업데이트 ──────────
  Future<void> updateLikes({
    required String reviewId,
    required List<Map<String, dynamic>> likes,
    required List<Map<String, dynamic>> dislikes,
  }) async {
    await _client.from(_table).update({
      'likes': likes,
      'dislikes': dislikes,
    }).eq('id', reviewId);
  }
}
