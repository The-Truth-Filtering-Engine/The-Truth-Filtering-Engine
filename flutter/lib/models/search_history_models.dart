enum SearchClickType {
  menu,
  restaurant,
  issue,
  quickPreview;

  String get apiValue {
    switch (this) {
      case SearchClickType.menu:
        return 'menu';
      case SearchClickType.restaurant:
        return 'restaurant';
      case SearchClickType.issue:
        return 'issue';
      case SearchClickType.quickPreview:
        return 'quick_preview';
    }
  }

  static SearchClickType fromApiValue(Object? value) {
    switch (value?.toString()) {
      case 'menu':
        return SearchClickType.menu;
      case 'restaurant':
        return SearchClickType.restaurant;
      case 'issue':
        return SearchClickType.issue;
      case 'quick_preview':
        return SearchClickType.quickPreview;
      default:
        return SearchClickType.restaurant;
    }
  }
}

class SearchRecentHistoryRequest {
  const SearchRecentHistoryRequest({
    required this.query,
    required this.clickedType,
    this.clickedId,
    this.clickedLabel,
    this.restaurantId,
    this.menuId,
  });

  final String query;
  final SearchClickType clickedType;
  final String? clickedId;
  final String? clickedLabel;
  final String? restaurantId;
  final String? menuId;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'clickedType': clickedType.apiValue,
      if (clickedId != null) 'clickedId': clickedId,
      if (clickedLabel != null) 'clickedLabel': clickedLabel,
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (menuId != null) 'menuId': menuId,
    };
  }
}

class SearchRecentHistoryResponse {
  const SearchRecentHistoryResponse({
    required this.items,
  });

  final List<SearchRecentHistoryItem> items;

  factory SearchRecentHistoryResponse.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return SearchRecentHistoryResponse(
      items: items is List
          ? items
              .whereType<Map>()
              .map(
                (item) => SearchRecentHistoryItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class SearchRecentHistoryItem {
  const SearchRecentHistoryItem({
    required this.id,
    required this.query,
    required this.clickedType,
    required this.clickedLabel,
    required this.createdAt,
    this.clickedId,
    this.restaurantId,
    this.menuId,
  });

  final String id;
  final String query;
  final SearchClickType clickedType;
  final String clickedLabel;
  final DateTime? createdAt;
  final String? clickedId;
  final String? restaurantId;
  final String? menuId;

  factory SearchRecentHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchRecentHistoryItem(
      id: json['id']?.toString() ?? '',
      query: json['query']?.toString() ?? '',
      clickedType: SearchClickType.fromApiValue(json['clickedType']),
      clickedLabel: json['clickedLabel']?.toString() ?? '',
      clickedId: _asNullableString(json['clickedId']),
      restaurantId: _asNullableString(json['restaurantId']),
      menuId: _asNullableString(json['menuId']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
