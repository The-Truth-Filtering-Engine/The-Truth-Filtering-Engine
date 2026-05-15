import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/search_repository.dart';
import '../../models/search_history_models.dart';
import '../../models/search_preview_models.dart';

enum SearchInputState {
  beforeInput,
  typing,
  submitted,
}

class SearchTrendingChip {
  const SearchTrendingChip({
    required this.label,
  });

  final String label;
}

const _defaultTrendingChips = <SearchTrendingChip>[
  SearchTrendingChip(label: '🔥 지금 뜨는 맛집'),
  SearchTrendingChip(label: '많이 찾는 맛집👍'),
  SearchTrendingChip(label: '✨ 신상 맛집 ✨'),
  SearchTrendingChip(label: '🕰️ 추억의 맛집'),
];

const _removedTrendingChipLabels = {
  '자연 속 맛집',
  '자연 뷰 맛집',
  '데이트 장소',
  'SNS 좋아요',
  '산수유람 맛집',
  '예쁜 카페',
  '이색 맛집',
  '지역 전통 음식',
  '고급 식당',
  'TV 출연 가게',
  '동네 오래된 맛집',
};

class SearchState {
  const SearchState({
    this.inputState = SearchInputState.beforeInput,
    this.query = '',
    this.preview,
    this.trendingChips = _defaultTrendingChips,
    this.recentHistory = const [],
    this.isLoadingPreview = false,
    this.isLoadingHistory = false,
    this.previewError,
    this.historyError,
  });

  final SearchInputState inputState;
  final String query;
  final SearchPreviewResponse? preview;
  final List<SearchTrendingChip> trendingChips;
  final List<SearchRecentHistoryItem> recentHistory;
  final bool isLoadingPreview;
  final bool isLoadingHistory;
  final String? previewError;
  final String? historyError;

  SearchState copyWith({
    SearchInputState? inputState,
    String? query,
    SearchPreviewResponse? preview,
    bool clearPreview = false,
    List<SearchTrendingChip>? trendingChips,
    List<SearchRecentHistoryItem>? recentHistory,
    bool? isLoadingPreview,
    bool? isLoadingHistory,
    String? previewError,
    bool clearPreviewError = false,
    String? historyError,
    bool clearHistoryError = false,
  }) {
    return SearchState(
      inputState: inputState ?? this.inputState,
      query: query ?? this.query,
      preview: clearPreview ? null : (preview ?? this.preview),
      trendingChips: trendingChips ?? this.trendingChips,
      recentHistory: recentHistory ?? this.recentHistory,
      isLoadingPreview: isLoadingPreview ?? this.isLoadingPreview,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      previewError:
          clearPreviewError ? null : (previewError ?? this.previewError),
      historyError:
          clearHistoryError ? null : (historyError ?? this.historyError),
    );
  }
}

final searchControllerProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return SearchController(repository);
});

class SearchController extends StateNotifier<SearchState> {
  SearchController(this._repository) : super(const SearchState());

  final SearchRepository _repository;

  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 300);
  static const _minimumQueryLength = 2;

  Future<void> onFocus() async {
    if (state.query.trim().isEmpty) {
      state = state.copyWith(inputState: SearchInputState.beforeInput);
      await Future.wait([
        _loadTrendingChips(),
        _loadRecentHistory(),
      ]);
    }
  }

  void onQueryChanged(String query, {double? lat, double? lng}) {
    final trimmed = query.trim();
    _debounce?.cancel();

    if (trimmed.length < _minimumQueryLength) {
      state = state.copyWith(
        query: query,
        inputState: SearchInputState.beforeInput,
        clearPreview: true,
        clearPreviewError: true,
        isLoadingPreview: false,
      );
      return;
    }

    state = state.copyWith(
      query: query,
      inputState: SearchInputState.typing,
      clearPreview: true,
      isLoadingPreview: false,
      clearPreviewError: true,
    );

    _debounce = Timer(_debounceDuration, () {
      _fetchPreview(trimmed, lat: lat, lng: lng);
    });
  }

  void onSubmit() {
    final trimmed = state.query.trim();
    if (trimmed.length < _minimumQueryLength) return;
    _debounce?.cancel();
    state = state.copyWith(
      query: trimmed,
      inputState: SearchInputState.submitted,
      isLoadingPreview: false,
    );
  }

  Future<void> onResultSelected(SearchRecentHistoryRequest request) async {
    try {
      await _repository.saveRecentHistory(request);
      await _loadRecentHistory();
    } catch (_) {
      // Search history should not block navigation after the user taps a result.
    }
  }

  Future<void> deleteHistoryItem(String historyId) async {
    try {
      await _repository.deleteRecentHistoryItem(historyId);
      state = state.copyWith(
        recentHistory:
            state.recentHistory.where((item) => item.id != historyId).toList(),
      );
    } catch (_) {
      // Keep the existing list if the remote delete fails.
    }
  }

  Future<void> deleteAllHistory() async {
    try {
      await _repository.deleteAllRecentHistory();
      state = state.copyWith(recentHistory: const []);
    } catch (_) {
      // Keep the existing list if the remote delete fails.
    }
  }

  void onRecentQueryTapped(String query, {double? lat, double? lng}) {
    onQueryChanged(query, lat: lat, lng: lng);
  }

  Future<void> _loadTrendingChips() async {
    try {
      final rows = await _repository.fetchTrendingChips();
      if (!mounted) return;
      if (rows.isEmpty) {
        state = state.copyWith(trendingChips: _defaultTrendingChips);
        return;
      }

      final chips = _trendingChipsFromRows(rows);
      if (chips.isEmpty) {
        state = state.copyWith(trendingChips: _defaultTrendingChips);
        return;
      }

      state = state.copyWith(trendingChips: chips);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(trendingChips: _defaultTrendingChips);
    }
  }

  List<SearchTrendingChip> _trendingChipsFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    final labels = <String>[];
    for (final row in rows) {
      final label = _normalizeTrendingChipLabel(
        row['label']?.toString().trim() ?? '',
      );
      if (label.isEmpty) continue;
      if (_removedTrendingChipLabels.contains(label)) continue;
      if (label == '힐링 맛집') {
        labels.add('산수유람 맛집');
      } else if (label == '자연 속 힐링 맛집') {
        labels.add('산수유람 맛집');
      } else {
        labels.add(label);
      }
    }

    labels.addAll(_defaultTrendingChips.map((chip) => chip.label));

    final seen = <String>{};
    return labels
        .where((label) => seen.add(label))
        .map((label) => SearchTrendingChip(label: label))
        .toList();
  }

  String _normalizeTrendingChipLabel(String label) {
    return switch (label) {
      '실시간 검색 맛집' => '🔥 지금 뜨는 맛집',
      '지금 뜨는 맛집' => '🔥 지금 뜨는 맛집',
      '신상 맛집' => '✨ 신상 맛집 ✨',
      '추억의 맛집' => '🕰️ 추억의 맛집',
      _ => label,
    };
  }

  Future<void> _loadRecentHistory() async {
    state = state.copyWith(isLoadingHistory: true, clearHistoryError: true);
    try {
      final response = await _repository.fetchRecentHistory();
      if (!mounted) return;
      state = state.copyWith(
        recentHistory: response.items,
        isLoadingHistory: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingHistory: false,
        historyError: '최근 검색 기록을 불러오지 못했습니다',
      );
    }
  }

  Future<void> _fetchPreview(
    String query, {
    double? lat,
    double? lng,
  }) async {
    if (!mounted || state.query.trim() != query) return;
    state = state.copyWith(
      isLoadingPreview: true,
      clearPreviewError: true,
    );

    try {
      final result = await _repository.fetchPreview(
        query: query,
        lat: lat,
        lng: lng,
      );
      if (!mounted || state.query.trim() != query) return;
      state = state.copyWith(
        preview: result,
        isLoadingPreview: false,
      );
    } catch (_) {
      if (!mounted || state.query.trim() != query) return;
      state = state.copyWith(
        isLoadingPreview: false,
        previewError: '검색 결과를 불러오지 못했습니다',
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
