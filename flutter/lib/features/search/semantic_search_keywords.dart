import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

const _maxSemanticQueries = 10;

const _situationKeywordMap = <String, List<String>>{
  '복날': ['삼계탕', '보양식', '추어탕', '냉면'],
  '더위': ['냉면', '콩국수', '삼계탕', '빙수'],
  '비': ['칼국수', '파전', '막걸리', '수제비'],
  '비오는날': ['칼국수', '파전', '막걸리'],
  '해장': ['해장국', '순대국밥', '콩나물국밥', '국밥'],
  '숙취': ['해장국', '콩나물국밥', '순대국밥'],
  '이사': ['국밥', '해장국', '갈비', '중식'],
  '기념일': ['오마카세', '스테이크', '파인다이닝', '갈비'],
  '생일': ['오마카세', '스테이크', '파스타', '갈비'],
  '추운날': ['국밥', '칼국수', '전골', '라멘'],
  '겨울': ['국밥', '전골', '칼국수', '라멘'],
  '혼밥': ['돈까스', '라멘', '국밥', '김밥'],
  '데이트': ['파스타', '오마카세', '브런치', '카페'],
  '모임': ['고기집', '갈비', '파스타', '중식'],
};

Future<List<String>> semanticRestaurantQueriesFor(String query) async {
  final localQueries = _localSemanticRestaurantQueriesFor(query);
  if (!SupabaseConfig.isConfigured) return localQueries;

  try {
    final rows = await _IssueKeywordCache.instance.load();
    final remoteQueries = _remoteSemanticRestaurantQueriesFor(query, rows);
    if (_isOnlyOriginalQuery(query, remoteQueries)) return localQueries;
    return _mergeSemanticQueries(
      remoteQueries,
      localQueries,
      query.trim(),
    );
  } catch (_) {
    return localQueries;
  }
}

List<String> _localSemanticRestaurantQueriesFor(String query) {
  final normalized = _normalizeSituationQuery(query);
  if (normalized.isEmpty) return const [];

  final matched = <String>[];
  for (final entry in _situationKeywordMap.entries) {
    if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
      matched.addAll(entry.value);
    }
  }

  if (matched.isEmpty) return [query.trim()];

  final seen = <String>{};
  return [
    ...matched.where((keyword) => seen.add(keyword)),
    if (seen.add(query.trim())) query.trim(),
  ];
}

List<String> _remoteSemanticRestaurantQueriesFor(
  String query,
  List<_IssueKeywordRow> rows,
) {
  final normalized = _normalizeSituationQuery(query);
  if (normalized.isEmpty) return const [];

  final matched = rows.where((row) => row.matches(normalized)).toList()
    ..sort((a, b) => b.baseScore.compareTo(a.baseScore));
  if (matched.isEmpty) return [query.trim()];

  final localQueries = _localSemanticRestaurantQueriesFor(query);
  return _mergeSemanticQueries(
    [
      for (final row in matched) ...row.aliases,
      ...localQueries,
      for (final row in matched) ...row.reviewKeywords,
      for (final row in matched) row.keyword,
    ],
    const [],
    query.trim(),
  );
}

List<String> _mergeSemanticQueries(
  Iterable<String> primary,
  Iterable<String> secondary,
  String originalQuery,
) {
  final seen = <String>{};
  final result = <String>[];

  void add(String value, {bool allowOriginal = false}) {
    final trimmed = value.trim();
    final normalized = _normalizeSituationQuery(trimmed);
    if (normalized.isEmpty) return;
    if (!allowOriginal &&
        normalized == _normalizeSituationQuery(originalQuery)) {
      return;
    }
    if (!allowOriginal && normalized.length < 2) return;
    if (!seen.add(normalized)) return;
    result.add(trimmed);
  }

  for (final keyword in primary) {
    if (result.length >= _maxSemanticQueries - 1) break;
    add(keyword);
  }
  for (final keyword in secondary) {
    if (result.length >= _maxSemanticQueries - 1) break;
    add(keyword);
  }
  add(originalQuery, allowOriginal: true);

  return result.isEmpty ? [originalQuery] : result;
}

bool _isOnlyOriginalQuery(String query, List<String> queries) {
  if (queries.length != 1) return false;
  return _normalizeSituationQuery(queries.first) ==
      _normalizeSituationQuery(query);
}

String _normalizeSituationQuery(String query) {
  return query
      .replaceAll(RegExp(r'[^0-9A-Za-z가-힣]'), '')
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase();
}

class _IssueKeywordCache {
  _IssueKeywordCache._();

  static final instance = _IssueKeywordCache._();

  DateTime? _loadedAt;
  List<_IssueKeywordRow>? _rows;

  Future<List<_IssueKeywordRow>> load() async {
    final loadedAt = _loadedAt;
    final rows = _rows;
    if (loadedAt != null &&
        rows != null &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 5)) {
      return rows;
    }

    final response = await Supabase.instance.client
        .from('search_issue_keywords')
        .select('id,label,keyword,aliases,review_keywords,base_score')
        .eq('is_active', true)
        .order('base_score', ascending: false)
        .limit(100);

    final loadedRows = response
        .whereType<Map>()
        .map((row) => _IssueKeywordRow.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    _loadedAt = DateTime.now();
    _rows = loadedRows;
    return loadedRows;
  }
}

class _IssueKeywordRow {
  const _IssueKeywordRow({
    required this.label,
    required this.keyword,
    required this.aliases,
    required this.reviewKeywords,
    required this.baseScore,
  });

  final String label;
  final String keyword;
  final List<String> aliases;
  final List<String> reviewKeywords;
  final int baseScore;

  factory _IssueKeywordRow.fromJson(Map<String, dynamic> json) {
    return _IssueKeywordRow(
      label: json['label']?.toString() ?? '',
      keyword: json['keyword']?.toString() ?? '',
      aliases: _stringList(json['aliases']),
      reviewKeywords: _stringList(json['review_keywords']),
      baseScore: int.tryParse(json['base_score']?.toString() ?? '') ?? 0,
    );
  }

  bool matches(String normalizedQuery) {
    final candidates = [
      label,
      keyword,
      ...aliases,
      ...reviewKeywords,
    ];
    return candidates.any((candidate) {
      final normalizedCandidate = _normalizeSituationQuery(candidate);
      return normalizedCandidate.isNotEmpty &&
          (normalizedCandidate.contains(normalizedQuery) ||
              normalizedQuery.contains(normalizedCandidate));
    });
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}
