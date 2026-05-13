import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';
import '../../core/config/test_admin_auth_config.dart';
import '../../core/providers/current_user_provider.dart';
import '../map/models/restaurant_model.dart';

final recentAnalysesProvider =
    StateNotifierProvider<RecentAnalysesNotifier, AsyncValue<RecentAnalyses>>(
  (ref) {
    final authState = ref.watch(appAuthProvider);
    return RecentAnalysesNotifier(isAdmin: authState.isAdmin);
  },
);

class RecentAnalysesNotifier extends StateNotifier<AsyncValue<RecentAnalyses>> {
  RecentAnalysesNotifier({required this.isAdmin})
      : super(const AsyncValue.data(RecentAnalyses.empty));

  final bool isAdmin;

  Map<String, String> get _authHeaders =>
      TestAdminAuthConfig.headers(isAdmin: isAdmin);

  Future<void> load() async {
    final headers = _authHeaders;
    if (headers.isEmpty) {
      state = const AsyncValue.data(RecentAnalyses.empty);
      return;
    }

    state = const AsyncValue.loading();

    try {
      final uri = BackendConfig.apiUri('/user/me/recent-analyses');
      final response = await http.get(
        uri,
        headers: headers,
      );
      final text = utf8.decode(response.bodyBytes);
      final decoded = text.isEmpty ? null : jsonDecode(text);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map
            ? decoded['detail']?.toString() ?? '요청 실패: ${response.statusCode}'
            : '요청 실패: ${response.statusCode}';
        throw Exception(message);
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception('최근분석 응답 형식이 올바르지 않습니다');
      }

      state = AsyncValue.data(RecentAnalyses.fromJson(decoded));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

class RecentAnalyses {
  const RecentAnalyses({
    required this.today,
    required this.freeItems,
    required this.expiredItems,
  });

  static const empty = RecentAnalyses(
    today: '',
    freeItems: [],
    expiredItems: [],
  );

  final String today;
  final List<RecentAnalysisItem> freeItems;
  final List<RecentAnalysisItem> expiredItems;

  bool get isEmpty => freeItems.isEmpty && expiredItems.isEmpty;

  factory RecentAnalyses.fromJson(Map<String, dynamic> json) {
    return RecentAnalyses(
      today: json['today']?.toString() ?? '',
      freeItems: _parseItems(json['freeItems']),
      expiredItems: _parseItems(json['expiredItems']),
    );
  }

  static List<RecentAnalysisItem> _parseItems(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => RecentAnalysisItem.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.storeId.isNotEmpty)
        .toList();
  }
}

class RecentAnalysisItem {
  const RecentAnalysisItem({
    required this.storeId,
    required this.analyzedDate,
    required this.daysElapsed,
    required this.remainingFreeDays,
    required this.restaurant,
    required this.hasLocation,
  });

  final String storeId;
  final String analyzedDate;
  final int? daysElapsed;
  final int remainingFreeDays;
  final RestaurantModel restaurant;
  final bool hasLocation;

  factory RecentAnalysisItem.fromJson(Map<String, dynamic> json) {
    final storeId = json['storeId']?.toString() ?? '';
    final restaurantJson = json['restaurant'] is Map
        ? Map<String, dynamic>.from(json['restaurant'] as Map)
        : <String, dynamic>{};
    final latitude = _asDouble(
      restaurantJson['latitude'] ?? restaurantJson['lat'],
    );
    final longitude = _asDouble(
      restaurantJson['longitude'] ?? restaurantJson['lng'],
    );
    final placeUrl = restaurantJson['placeUrl']?.toString() ??
        restaurantJson['link']?.toString();

    return RecentAnalysisItem(
      storeId: storeId,
      analyzedDate: json['analyzedDate']?.toString() ?? '',
      daysElapsed: _asIntOrNull(json['daysElapsed']),
      remainingFreeDays: _asInt(json['remainingFreeDays']),
      hasLocation: latitude != null && longitude != null,
      restaurant: RestaurantModel(
        id: restaurantJson['id']?.toString() ?? storeId,
        storeId: restaurantJson['storeId']?.toString() ?? storeId,
        name: restaurantJson['name']?.toString() ?? storeId,
        address: restaurantJson['address']?.toString() ?? '',
        category: restaurantJson['category']?.toString() ?? '음식점',
        categoryName: restaurantJson['categoryName']?.toString(),
        categoryGroupCode: restaurantJson['categoryGroupCode']?.toString(),
        categoryGroupName: restaurantJson['categoryGroupName']?.toString(),
        truthScore: 0,
        distance: _asInt(restaurantJson['distance']),
        phone: restaurantJson['phone']?.toString(),
        placeUrl: placeUrl,
        addressName: restaurantJson['addressName']?.toString(),
        roadAddressName: restaurantJson['roadAddressName']?.toString(),
        reviewSummary: restaurantJson['name']?.toString() ?? '최근분석',
        latitude: latitude ?? 0,
        longitude: longitude ?? 0,
      ),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asIntOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
