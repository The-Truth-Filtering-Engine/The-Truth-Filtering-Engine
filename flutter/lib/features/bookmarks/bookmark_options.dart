import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkTopicOption {
  final String id;
  final String label;
  final String colorKey;

  const BookmarkTopicOption(
    this.id,
    this.label, {
    this.colorKey = BookmarkColors.defaultColorKey,
  });

  factory BookmarkTopicOption.fromJson(Map<String, dynamic> json) {
    return BookmarkTopicOption(
      json['id']?.toString() ?? '',
      json['label']?.toString() ?? '',
      colorKey: BookmarkColors.byKey(
        (json['colorKey'] ?? json['color_key'])?.toString(),
      ).key,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'colorKey': colorKey,
      };
}

class BookmarkTopics {
  static const legacyDefaultTopicId = 'bookmark';
  static const defaultTopicId = 'favorite';
  static const _customStorageKey = 'bookmark_custom_topics';
  static const _hiddenStorageKey = 'bookmark_hidden_topic_ids';

  static const items = [
    BookmarkTopicOption(defaultTopicId, '즐겨찾기', colorKey: 'sky'),
    BookmarkTopicOption('date_place', '데이트 장소', colorKey: 'pink'),
    BookmarkTopicOption('sns_like', 'SNS 좋아요', colorKey: 'lavender'),
    BookmarkTopicOption('nature_trip', '산수유람 맛집', colorKey: 'mint'),
    BookmarkTopicOption('pretty_cafe', '예쁜 카페', colorKey: 'peach'),
    BookmarkTopicOption('unique_place', '이색 맛집', colorKey: 'coral'),
    BookmarkTopicOption(
      'local_traditional_food',
      '지역 전통 음식',
      colorKey: 'olive',
    ),
    BookmarkTopicOption('premium_restaurant', '격식있는 모임', colorKey: 'graphite'),
    BookmarkTopicOption(
      'tv_featured_place',
      'TV 출연 화제의 식당',
      colorKey: 'ocean',
    ),
    BookmarkTopicOption('old_local_place', '동네 오래된 맛집', colorKey: 'yellow'),
  ];

  static List<BookmarkTopicOption> all([
    List<BookmarkTopicOption> customTopics = const [],
    Set<String> hiddenTopicIds = const {},
  ]) {
    final hiddenIds = hiddenTopicIds.map(_visibleTopicId).toSet();
    final seen = <String>{};
    return [...items, ...customTopics]
        .where((topic) => topic.id.isNotEmpty && topic.label.isNotEmpty)
        .where((topic) => !hiddenIds.contains(_visibleTopicId(topic.id)))
        .where((topic) => seen.add(topic.id))
        .toList();
  }

  static List<String> labelsFor(
    List<String> ids, {
    List<BookmarkTopicOption> customTopics = const [],
    Set<String> hiddenTopicIds = const {},
  }) {
    final source = ids.isEmpty ? const [defaultTopicId] : ids;
    final hiddenIds = hiddenTopicIds.map(_visibleTopicId).toSet();
    final topicOptions = all(customTopics, hiddenIds);
    final labels = <String>[];
    final seen = <String>{};

    for (final rawId in source) {
      final id = _visibleTopicId(rawId);
      if (hiddenIds.contains(id)) continue;
      final topic = topicOptions.firstWhere(
        (item) => item.id == id,
        orElse: () => BookmarkTopicOption(id, id),
      );
      if (topic.label.isEmpty || !seen.add(topic.label)) continue;
      labels.add(topic.label);
    }

    return labels;
  }

  static String colorKeyForTopicIds(
    List<String> ids, {
    List<BookmarkTopicOption> customTopics = const [],
    Set<String> hiddenTopicIds = const {},
    String? fallbackColorKey,
  }) {
    final source = ids.isEmpty ? const [defaultTopicId] : ids;
    final hiddenIds = hiddenTopicIds.map(_visibleTopicId).toSet();
    final topicOptions = all(customTopics, hiddenIds);

    for (final rawId in source.toList().reversed) {
      final id = _visibleTopicId(rawId);
      if (hiddenIds.contains(id)) continue;
      final matches = topicOptions.where((topic) => topic.id == id);
      if (matches.isNotEmpty) {
        return BookmarkColors.byKey(matches.first.colorKey).key;
      }
    }

    return BookmarkColors.byKey(fallbackColorKey).key;
  }

  static String visibleTopicId(String id) => _visibleTopicId(id);

  static bool isDefaultTopic(String id) {
    final visibleId = _visibleTopicId(id);
    return items.any((topic) => topic.id == visibleId);
  }

  static bool canDeleteTopic(String id) {
    return _visibleTopicId(id) != defaultTopicId;
  }

  static String _visibleTopicId(String id) {
    return id == legacyDefaultTopicId ? defaultTopicId : id;
  }

  static Future<List<BookmarkTopicOption>> loadCustomTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customStorageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => BookmarkTopicOption.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((topic) => topic.id.isNotEmpty && topic.label.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveCustomTopics(
    List<BookmarkTopicOption> topics,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customStorageKey,
      jsonEncode(topics.map((topic) => topic.toJson()).toList()),
    );
  }

  static Future<Set<String>> loadHiddenTopicIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hiddenStorageKey);
    if (raw == null || raw.isEmpty) return const {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const {};
      return decoded
          .map((item) => _visibleTopicId(item.toString()))
          .where((id) => id.isNotEmpty && id != defaultTopicId)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  static Future<void> saveHiddenTopicIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedIds = ids
        .map(_visibleTopicId)
        .where((id) => id.isNotEmpty && id != defaultTopicId)
        .toSet()
        .toList()
      ..sort();
    await prefs.setString(_hiddenStorageKey, jsonEncode(normalizedIds));
  }
}

class BookmarkColorOption {
  final String key;
  final String label;
  final Color background;
  final Color border;
  final Color foreground;

  const BookmarkColorOption({
    required this.key,
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });
}

class BookmarkColors {
  static const defaultColorKey = 'sky';

  static const items = [
    BookmarkColorOption(
      key: defaultColorKey,
      label: '하늘',
      background: Color(0xFFDDF4FF),
      border: Color(0xFF99DDF7),
      foreground: Color(0xFF087EA4),
    ),
    BookmarkColorOption(
      key: 'yellow',
      label: '노랑',
      background: Color(0xFFFFF6C7),
      border: Color(0xFFFFDE68),
      foreground: Color(0xFF926B00),
    ),
    BookmarkColorOption(
      key: 'pink',
      label: '핑크',
      background: Color(0xFFFFE2EE),
      border: Color(0xFFFFA8C8),
      foreground: Color(0xFFC0265B),
    ),
    BookmarkColorOption(
      key: 'mint',
      label: '민트',
      background: Color(0xFFDDFBEA),
      border: Color(0xFF94E4B7),
      foreground: Color(0xFF167A46),
    ),
    BookmarkColorOption(
      key: 'lavender',
      label: '보라',
      background: Color(0xFFEDE5FF),
      border: Color(0xFFC9B4FF),
      foreground: Color(0xFF6541B7),
    ),
    BookmarkColorOption(
      key: 'peach',
      label: '살구',
      background: Color(0xFFFFEAD7),
      border: Color(0xFFFFC99A),
      foreground: Color(0xFFB45309),
    ),
    BookmarkColorOption(
      key: 'coral',
      label: '코랄',
      background: Color(0xFFFFE1DC),
      border: Color(0xFFFFAFA6),
      foreground: Color(0xFFB9382A),
    ),
    BookmarkColorOption(
      key: 'olive',
      label: '올리브',
      background: Color(0xFFF0F8D8),
      border: Color(0xFFCFEA84),
      foreground: Color(0xFF587A14),
    ),
    BookmarkColorOption(
      key: 'ocean',
      label: '바다',
      background: Color(0xFFDDF7F7),
      border: Color(0xFF8ADCDC),
      foreground: Color(0xFF0F766E),
    ),
    BookmarkColorOption(
      key: 'graphite',
      label: '먹색',
      background: Color(0xFFEFF1F5),
      border: Color(0xFFC7CEDA),
      foreground: Color(0xFF475569),
    ),
  ];

  static BookmarkColorOption byKey(String? key) {
    return items.firstWhere(
      (item) => item.key == key,
      orElse: () => items.first,
    );
  }

  static String markerHex(String? key) {
    final color = byKey(key).foreground;
    return '#${color.r.toInt().toRadixString(16).padLeft(2, '0')}'
        '${color.g.toInt().toRadixString(16).padLeft(2, '0')}'
        '${color.b.toInt().toRadixString(16).padLeft(2, '0')}';
  }
}
