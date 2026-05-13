import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/backend_config.dart';
import '../models/review_like_model.dart';

class ReviewLikeRemoteSource {
  final SupabaseClient _client;
  static const _table = 'reviews';

  ReviewLikeRemoteSource(this._client);

  Future<Map<String, dynamic>> fetchLikes(String reviewId) async {
    final res = await _client
        .from(_table)
        .select('likes')
        .eq('id', reviewId)
        .single();
    return res;
  }

  Future<Set<String>?> fetchUserLikedReviewIds(
    Map<String, String>? authHeaders,
  ) async {
    if (authHeaders == null || authHeaders.isEmpty) return null;

    final response = await http.get(
      BackendConfig.apiUri('/user/me/review-reactions'),
      headers: authHeaders,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('review reaction load failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) return {};

    final reviewLikes = decoded['review_likes'];
    if (reviewLikes is! Map) return {};

    return reviewLikes.keys
        .map((key) => key.toString().trim())
        .where((key) => key.isNotEmpty)
        .toSet();
  }

  Future<void> updateLikes({
    required String reviewId,
    required List<Map<String, dynamic>> likes,
  }) async {
    await _client.from(_table).update({
      'likes': likes,
    }).eq('id', reviewId);
  }

  Future<void> syncUserReaction({
    required Map<String, String> authHeaders,
    required String reviewId,
    required LikeType? reaction,
  }) async {
    if (authHeaders.isEmpty) return;

    final response = await http.put(
      BackendConfig.apiUri('/user/me/review-reactions'),
      headers: {
        ...authHeaders,
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
