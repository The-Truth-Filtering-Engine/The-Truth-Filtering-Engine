import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/backend_config.dart';
import '../models/review_like_model.dart';

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

  Future<void> syncUserReaction({
    required String accessToken,
    required String reviewId,
    required LikeType? reaction,
  }) async {
    if (accessToken.isEmpty) return;

    final response = await http.put(
      BackendConfig.apiUri('/user/me/review-reactions'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reviewId': reviewId,
        'reaction': reaction?.name,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('review reaction sync failed: ${response.statusCode}');
    }
  }
}
