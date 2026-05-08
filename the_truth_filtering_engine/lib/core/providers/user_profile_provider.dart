import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import '../config/supabase_config.dart';

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>(
  (ref) => UserProfileNotifier(),
);

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  UserProfileNotifier() : super(const AsyncValue.data(null));

  String? get accessToken {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  bool get hasGoogleSession => accessToken != null;

  Future<UserProfile?> loadIfPossible({bool force = false}) async {
    final token = accessToken;
    if (token == null) {
      state = const AsyncValue.data(null);
      return null;
    }

    final current = state.asData?.value;
    if (!force && current != null) return current;

    state = const AsyncValue.loading();

    try {
      final profile = await _requestProfile(token);
      state = AsyncValue.data(profile);
      return profile;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  Future<UserProfile> setPremium(bool premium) {
    return _mutateProfile(
      method: 'PATCH',
      path: '/user/me/premium',
      body: {'premium': premium},
    );
  }

  Future<UserProfile> chargeCoins(int amount) {
    return _mutateProfile(
      method: 'POST',
      path: '/user/me/coins',
      body: {'amount': amount},
    );
  }

  Future<UserProfile> _mutateProfile({
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) async {
    final token = accessToken;
    if (token == null) {
      throw Exception('Google 로그인 정보가 없습니다');
    }

    final profile = await _requestProfile(
      token,
      method: method,
      path: path,
      body: body,
    );
    state = AsyncValue.data(profile);
    return profile;
  }

  Future<UserProfile> _requestProfile(
    String token, {
    String method = 'GET',
    String path = '/user/me',
    Map<String, Object?>? body,
  }) async {
    final uri = BackendConfig.apiUri(path);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final response = switch (method) {
      'PATCH' => await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
      'POST' => await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
      _ => await http.get(uri, headers: headers),
    };

    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['detail']?.toString() ?? '요청 실패: ${response.statusCode}'
          : '요청 실패: ${response.statusCode}';
      throw Exception(message);
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('사용자 응답 형식이 올바르지 않습니다');
    }

    return UserProfile.fromJson(decoded);
  }
}

class UserProfile {
  const UserProfile({
    required this.email,
    required this.premium,
    required this.coin,
    required this.freecount,
    required this.premiumcount,
    this.store,
    this.bookmark,
  });

  static const int analysisCoinCost = 100;

  final String email;
  final int premium;
  final int coin;
  final int freecount;
  final int premiumcount;
  final Object? store;
  final Object? bookmark;

  bool get isPremium => premium == 1;

  bool get hasCountAnalysis => freecount > 0 || premiumcount > 0;

  bool get hasCoinAnalysis => coin >= analysisCoinCost;

  bool hasRecentAnalysisFor(String storeId) {
    final dateText = storeDateFor(storeId);
    if (dateText == null) return false;

    final lastDate = _parseStoreDate(dateText);
    if (lastDate == null) return false;

    final today = _todayKstDate();
    return today.difference(lastDate).inDays < 2;
  }

  String? storeDateFor(String storeId) {
    final normalizedStoreId = storeId.trim();
    if (normalizedStoreId.isEmpty || store is! Map) return null;

    final storeMap = store as Map;
    final value = storeMap[normalizedStoreId];
    return value?.toString();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email']?.toString() ?? '',
      premium: _intFromJson(json['premium']),
      coin: _intFromJson(json['coin']),
      freecount: _intFromJson(json['freecount']),
      premiumcount: _intFromJson(json['premiumcount']),
      store: json['store'],
      bookmark: json['bookmark'],
    );
  }

  static int _intFromJson(Object? value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime _todayKstDate() {
    final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime.utc(nowKst.year, nowKst.month, nowKst.day);
  }

  static DateTime? _parseStoreDate(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(normalized)) return null;

    final year = int.tryParse(normalized.substring(0, 4));
    final month = int.tryParse(normalized.substring(4, 6));
    final day = int.tryParse(normalized.substring(6, 8));
    if (year == null || month == null || day == null) return null;

    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }
}
