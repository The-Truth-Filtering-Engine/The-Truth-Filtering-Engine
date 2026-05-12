import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 검색어 기록 (로컬 SharedPreferences, 최대 10개)
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
  (ref) => SearchHistoryNotifier(),
);

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const _key = 'search_history';
  static const _maxCount = 10;

  SearchHistoryNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? [];
  }

  /// 검색 실행 시 호출 — 중복 제거 후 맨 앞에 삽입
  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    final updated = [
      q,
      ...state.where((s) => s != q),
    ].take(_maxCount).toList();

    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
  }

  /// 항목 하나 삭제
  Future<void> remove(String query) async {
    state = state.where((s) => s != query).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }

  /// 전체 삭제
  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
