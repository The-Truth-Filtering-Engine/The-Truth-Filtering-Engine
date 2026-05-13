class SearchPreviewResponse {
  const SearchPreviewResponse({
    required this.query,
    required this.issueChips,
    required this.suggestions,
    required this.quickPreviews,
  });

  final String query;
  final List<SearchIssueChip> issueChips;
  final SearchSuggestions suggestions;
  final List<SearchQuickPreview> quickPreviews;

  factory SearchPreviewResponse.fromJson(Map<String, dynamic> json) {
    return SearchPreviewResponse(
      query: json['query']?.toString() ?? '',
      issueChips: _parseList(
        json['issueChips'],
        SearchIssueChip.fromJson,
      ),
      suggestions: SearchSuggestions.fromJson(
        json['suggestions'] is Map
            ? Map<String, dynamic>.from(json['suggestions'] as Map)
            : const {},
      ),
      quickPreviews: _parseList(
        json['quickPreviews'],
        SearchQuickPreview.fromJson,
      ),
    );
  }
}

class SearchIssueChip {
  const SearchIssueChip({
    required this.id,
    required this.label,
    required this.keyword,
    required this.score,
  });

  final String id;
  final String label;
  final String keyword;
  final int score;

  factory SearchIssueChip.fromJson(Map<String, dynamic> json) {
    return SearchIssueChip(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      keyword: json['keyword']?.toString() ?? '',
      score: _asInt(json['score']),
    );
  }
}

class SearchSuggestions {
  const SearchSuggestions({
    required this.menus,
    required this.restaurants,
  });

  final List<SearchMenuSuggestion> menus;
  final List<SearchRestaurantSuggestion> restaurants;

  factory SearchSuggestions.fromJson(Map<String, dynamic> json) {
    return SearchSuggestions(
      menus: _parseList(json['menus'], SearchMenuSuggestion.fromJson),
      restaurants: _parseList(
        json['restaurants'],
        SearchRestaurantSuggestion.fromJson,
      ),
    );
  }
}

class SearchMenuSuggestion {
  const SearchMenuSuggestion({
    required this.id,
    required this.name,
    required this.matchedText,
    required this.score,
  });

  final String id;
  final String name;
  final String matchedText;
  final int score;

  factory SearchMenuSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchMenuSuggestion(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      matchedText: json['matchedText']?.toString() ?? '',
      score: _asInt(json['score']),
    );
  }
}

class SearchRestaurantSuggestion {
  const SearchRestaurantSuggestion({
    required this.id,
    required this.name,
    required this.score,
  });

  final String id;
  final String name;
  final int score;

  factory SearchRestaurantSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchRestaurantSuggestion(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      score: _asInt(json['score']),
    );
  }
}

class SearchQuickPreview {
  const SearchQuickPreview({
    required this.restaurantId,
    required this.restaurantName,
    required this.menuId,
    required this.menuName,
    required this.price,
    required this.priceLabel,
    required this.imageUrl,
    required this.score,
    required this.matchReason,
  });

  final String restaurantId;
  final String restaurantName;
  final String? menuId;
  final String? menuName;
  final int? price;
  final String priceLabel;
  final String? imageUrl;
  final int score;
  final String matchReason;

  factory SearchQuickPreview.fromJson(Map<String, dynamic> json) {
    return SearchQuickPreview(
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? '',
      menuId: _asNullableString(json['menuId']),
      menuName: _asNullableString(json['menuName']),
      price: _asNullableInt(json['price']),
      priceLabel: json['priceLabel']?.toString() ?? '가격 문의',
      imageUrl: _asNullableString(json['imageUrl']),
      score: _asInt(json['score']),
      matchReason: json['matchReason']?.toString() ?? '',
    );
  }
}

List<T> _parseList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
