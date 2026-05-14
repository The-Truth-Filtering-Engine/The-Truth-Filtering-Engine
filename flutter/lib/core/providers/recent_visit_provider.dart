import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/backend_config.dart';
import '../config/test_account_auth_config.dart';
import 'current_user_provider.dart';
import '../../features/map/models/restaurant_model.dart';

/// Recently opened review list (local SharedPreferences + users.recent_visits).
final recentVisitProvider =
    StateNotifierProvider<RecentVisitNotifier, List<RestaurantModel>>(
  (ref) {
    final authState = ref.watch(appAuthProvider);

    return RecentVisitNotifier(
      enableRemoteSync: authState.isLoggedIn,
      isTestAccountLogin: authState.isTestAccountLogin,
    );
  },
);

class RecentVisitNotifier extends StateNotifier<List<RestaurantModel>> {
  static const _key = 'recent_visited_reviews';
  static const _maxCount = 30;

  final bool enableRemoteSync;
  final bool isTestAccountLogin;

  RecentVisitNotifier({
    required this.enableRemoteSync,
    required this.isTestAccountLogin,
  }) : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final localItems = await _loadLocal();
    state = localItems;

    if (!enableRemoteSync) return;

    final remoteItems = await _loadRemote();
    if (remoteItems == null) return;

    final merged = _mergeRecent(remoteItems, localItems);
    state = merged;
    await _saveLocal(merged);

    for (final restaurant in localItems) {
      final reviewId = restaurant.effectiveReviewId;
      if (reviewId.isEmpty) continue;
      if (remoteItems.any((item) => item.effectiveReviewId == reviewId)) {
        continue;
      }
      await _syncRemoteAdd(restaurant);
    }
  }

  Future<List<RestaurantModel>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final items = raw
        .map((e) {
          try {
            return RestaurantModel.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<RestaurantModel>()
        .where((restaurant) => restaurant.effectiveReviewId.isNotEmpty)
        .toList();
    return _sortRecent(items);
  }

  Future<void> addReview({
    required String reviewId,
    required String name,
    required String reviewUrl,
    required String reviewTitle,
    required String reviewDescription,
  }) async {
    final normalizedReviewId = _requireText(reviewId, 'reviewId');
    final normalizedReviewUrl = _requireText(reviewUrl, 'reviewUrl');
    final description = reviewDescription.trim();
    final now = DateTime.now();

    await add(
      RestaurantModel(
        id: normalizedReviewId,
        reviewId: normalizedReviewId,
        name: name.trim(),
        address: '',
        category: '',
        truthScore: 0,
        reviewSummary: description,
        reviewUrl: normalizedReviewUrl,
        reviewTitle: reviewTitle.trim(),
        reviewDescription: description,
        latitude: 0,
        longitude: 0,
        visitedAt: now,
      ),
    );
  }

  Future<void> add(RestaurantModel restaurant) async {
    final reviewId = _requireText(restaurant.effectiveReviewId, 'reviewId');
    final reviewUrl = _requireText(restaurant.reviewUrl, 'reviewUrl');
    final now = DateTime.now();
    final description = _firstText([
      restaurant.reviewDescription,
      restaurant.reviewSummary,
    ]);
    final visitedReview = RestaurantModel(
      id: reviewId,
      reviewId: reviewId,
      name: restaurant.name.trim(),
      address: '',
      category: '',
      truthScore: 0,
      reviewSummary: description,
      reviewUrl: reviewUrl,
      reviewTitle: restaurant.reviewTitle?.trim() ?? '',
      reviewDescription: description,
      latitude: 0,
      longitude: 0,
      visitedAt: now,
    );

    final updated = [
      visitedReview,
      ...state.where((r) => r.effectiveReviewId != reviewId),
    ].take(_maxCount).toList();

    state = updated;

    await _saveLocal(updated);
    await _syncRemoteAdd(visitedReview);
  }

  Future<void> remove(String reviewId) async {
    final normalizedReviewId = _requireText(reviewId, 'reviewId');
    state =
        state.where((r) => r.effectiveReviewId != normalizedReviewId).toList();
    await _saveLocal(state);
    await _syncRemoteRemove(normalizedReviewId);
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await _syncRemoteClear();
  }

  Future<void> _saveLocal(List<RestaurantModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Map<String, String>? get _authHeaders {
    if (!enableRemoteSync) return null;
    final headers = TestAccountAuthConfig.headers(
      isTestAccountLogin: isTestAccountLogin,
    );
    return headers.isEmpty ? null : headers;
  }

  Future<List<RestaurantModel>?> _loadRemote() async {
    final headers = _authHeaders;
    if (headers == null) return null;

    try {
      final response = await http.get(
        BackendConfig.apiUri('/user/me/recent-visits'),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Recent visits load failed: ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const [];

      final items = decoded['items'];
      if (items is List) {
        return _sortRecent(
          items
              .whereType<Map>()
              .map((item) => _restaurantFromRemoteItem(
                    Map<String, dynamic>.from(item),
                  ))
              .whereType<RestaurantModel>()
              .toList(),
        );
      }

      final recentVisits = decoded['recentVisits'];
      if (recentVisits is! Map) return const [];

      final values = <RestaurantModel>[];
      for (final entry in recentVisits.entries) {
        final reviewId = _text(entry.key);
        final item = entry.value;
        if (reviewId == null || item is! Map) continue;
        final restaurant = _restaurantFromRemoteItem({
          'id': reviewId,
          'reviewId': reviewId,
          ...Map<String, dynamic>.from(item),
        });
        if (restaurant != null) values.add(restaurant);
      }

      return _sortRecent(values);
    } catch (error) {
      debugPrint('Recent visits load failed: $error');
      return null;
    }
  }

  Future<void> _syncRemoteAdd(RestaurantModel restaurant) async {
    final headers = _authHeaders;
    if (headers == null) return;

    try {
      final response = await http.post(
        BackendConfig.apiUri('/user/me/recent-visits'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reviewId': _requireText(restaurant.effectiveReviewId, 'reviewId'),
          'review': {
            'name': restaurant.name.trim(),
            'review_url': _requireText(restaurant.reviewUrl, 'reviewUrl'),
            'review_title': restaurant.reviewTitle?.trim() ?? '',
            'review_description': _firstText([
              restaurant.reviewDescription,
              restaurant.reviewSummary,
            ]),
          },
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('recent visit add failed: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Recent visit remote add failed: $error');
    }
  }

  Future<void> _syncRemoteRemove(String reviewId) async {
    final headers = _authHeaders;
    if (headers == null) return;

    try {
      final response = await http.delete(
        BackendConfig.apiUri(
          '/user/me/recent-visits/${Uri.encodeComponent(reviewId)}',
        ),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('recent visit remove failed: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Recent visit remote remove failed: $error');
    }
  }

  Future<void> _syncRemoteClear() async {
    final headers = _authHeaders;
    if (headers == null) return;

    try {
      final response = await http.delete(
        BackendConfig.apiUri('/user/me/recent-visits'),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('recent visits clear failed: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Recent visits remote clear failed: $error');
    }
  }

  RestaurantModel? _restaurantFromRemoteItem(Map<String, dynamic> item) {
    final reviewId = _text(item['reviewId'] ?? item['review_id'] ?? item['id']);
    if (reviewId == null) return null;

    final reviewUrl = _text(item['review_url'] ?? item['reviewUrl']);
    if (reviewUrl == null) return null;

    return RestaurantModel.fromJson({
      'id': reviewId,
      'reviewId': reviewId,
      'name': item['name']?.toString() ?? '',
      'review_url': reviewUrl,
      'review_title': item['review_title'] ?? item['reviewTitle'],
      'review_description':
          item['review_description'] ?? item['reviewDescription'],
      'reviewSummary':
          item['review_description'] ?? item['reviewDescription'] ?? '',
      'visitedAt': item['visitedAt'] ?? item['visited_at'],
    });
  }

  List<RestaurantModel> _mergeRecent(
    List<RestaurantModel> remoteItems,
    List<RestaurantModel> localItems,
  ) {
    final byReviewId = <String, RestaurantModel>{};

    for (final restaurant in [...remoteItems, ...localItems]) {
      final reviewId = restaurant.effectiveReviewId;
      if (reviewId.isEmpty) continue;
      final existing = byReviewId[reviewId];
      if (existing == null ||
          _recentDate(restaurant).compareTo(_recentDate(existing)) > 0) {
        byReviewId[reviewId] = restaurant;
      }
    }

    return _sortRecent(byReviewId.values.toList()).take(_maxCount).toList();
  }

  List<RestaurantModel> _sortRecent(List<RestaurantModel> items) {
    return [...items]..sort((a, b) => _recentDate(b).compareTo(_recentDate(a)));
  }

  String _recentDate(RestaurantModel restaurant) {
    return restaurant.visitedAt?.toIso8601String() ??
        restaurant.updatedAt?.toIso8601String() ??
        '';
  }

  String _firstText(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }

  String _requireText(String? value, String field) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('$field is required');
    }
    return text;
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
