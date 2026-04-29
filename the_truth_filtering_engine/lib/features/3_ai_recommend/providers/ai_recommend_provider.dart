import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/ai_recommend_item.dart';

class AiRecommendState {
  final List<AiRecommendItem> items;
  final int page;
  final bool hasNext;
  final bool isLoading;
  final String? errorMessage;

  const AiRecommendState({
    this.items = const [],
    this.page = 1,
    this.hasNext = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AiRecommendState copyWith({
    List<AiRecommendItem>? items,
    int? page,
    bool? hasNext,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiRecommendState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final aiRecommendProvider = StateNotifierProvider.autoDispose<
    AiRecommendNotifier, AiRecommendState>((ref) {
  return AiRecommendNotifier()..loadPage(1);
});

class AiRecommendNotifier extends StateNotifier<AiRecommendState> {
  AiRecommendNotifier() : super(const AiRecommendState(isLoading: true));

  static const _pageSize = 10;

  Future<void> refresh() => loadPage(1);

  Future<void> loadNextPage() {
    if (!state.hasNext || state.isLoading) return Future.value();
    return loadPage(state.page + 1);
  }

  Future<void> loadPreviousPage() {
    if (state.page <= 1 || state.isLoading) return Future.value();
    return loadPage(state.page - 1);
  }

  Future<void> loadPage(int page) async {
    state = state.copyWith(
      page: page,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _fetchPage(page);
      state = state.copyWith(
        items: result.items,
        page: result.page,
        hasNext: result.hasNext,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'AI 추천 API 오류: $error',
      );
    }
  }

  Future<_AiRecommendPage> _fetchPage(int page) async {
    final uri = Uri.parse('http://localhost:8000/api/ai-recommendations')
        .replace(queryParameters: {
      'threshold': '0.1',
      'page': page.toString(),
      'pageSize': _pageSize.toString(),
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('서버 응답 ${response.statusCode}');
    }

    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? [];

    return _AiRecommendPage(
      items: items
          .whereType<Map>()
          .map((item) => AiRecommendItem.fromJson(item.cast<String, dynamic>()))
          .where((item) => item.id != 0)
          .toList(),
      page: _asInt(body['page'], fallback: page),
      hasNext: body['hasNext'] == true,
    );
  }
}

class _AiRecommendPage {
  final List<AiRecommendItem> items;
  final int page;
  final bool hasNext;

  const _AiRecommendPage({
    required this.items,
    required this.page,
    required this.hasNext,
  });
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
