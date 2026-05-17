import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class UserActivityHistoryClient {
  static const reviewOpenedType = 'review_opened';
  static const analysisViewedType = 'analysis_viewed';

  const UserActivityHistoryClient._();

  static Future<Map<String, dynamic>?> load(String? accessToken) async {
    if (accessToken == null) return null;

    final response = await http.get(
      BackendConfig.apiUri('/user/me/activity-history'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    return _decodeResponse(response, fallbackError: 'activity history load');
  }

  static Future<void> recordReviewOpened({
    required String? accessToken,
    required String reviewId,
    required Map<String, dynamic> review,
  }) async {
    if (accessToken == null) return;

    final response = await http.post(
      BackendConfig.apiUri('/user/me/activity-history'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'type': reviewOpenedType,
        'id': reviewId,
        'payload': review,
      }),
    );

    _throwIfFailed(response, fallbackError: 'activity history record');
  }

  static Future<void> removeReviewOpened({
    required String? accessToken,
    required String reviewId,
  }) async {
    if (accessToken == null) return;

    final response = await http.delete(
      BackendConfig.apiUri(
        '/user/me/activity-history/$reviewOpenedType/${Uri.encodeComponent(reviewId)}',
      ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    _throwIfFailed(response, fallbackError: 'activity history remove');
  }

  static Future<void> removeAnalysisViewed({
    required String? accessToken,
    required String storeId,
  }) async {
    if (accessToken == null) return;

    final response = await http.delete(
      BackendConfig.apiUri(
        '/user/me/activity-history/$analysisViewedType/${Uri.encodeComponent(storeId)}',
      ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    _throwIfFailed(response, fallbackError: 'recent analysis remove');
  }

  static Future<void> clearReviewOpened(String? accessToken) async {
    if (accessToken == null) return;

    final response = await http.delete(
      BackendConfig.apiUri(
        '/user/me/activity-history',
        queryParameters: {'type': reviewOpenedType},
      ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    _throwIfFailed(response, fallbackError: 'activity history clear');
  }

  static Map<String, dynamic>? _decodeResponse(
    http.Response response, {
    required String fallbackError,
  }) {
    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail']?.toString() : null;
      throw StateError(
        '$fallbackError failed: ${response.statusCode}${detail == null ? '' : ' $detail'}',
      );
    }

    if (decoded == null) return null;
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw StateError('$fallbackError returned invalid response');
  }

  static void _throwIfFailed(
    http.Response response, {
    required String fallbackError,
  }) {
    try {
      _decodeResponse(response, fallbackError: fallbackError);
    } catch (error) {
      debugPrint('$fallbackError failed: $error');
      rethrow;
    }
  }
}
