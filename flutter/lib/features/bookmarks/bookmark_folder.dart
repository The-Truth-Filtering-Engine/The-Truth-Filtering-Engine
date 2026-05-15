import 'package:flutter/material.dart';

import '../map/models/restaurant_model.dart';

class BookmarkFolder {
  final String category;
  final String label;
  final bool isDefault;
  final List<RestaurantModel> restaurants;
  final Color? color;

  const BookmarkFolder({
    required this.category,
    required this.label,
    required this.isDefault,
    required this.restaurants,
    this.color,
  });

  factory BookmarkFolder.fromJson(Map<String, dynamic> json) {
    final rawRestaurants = json['restaurants'];

    return BookmarkFolder(
      category: json['category']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      isDefault: json['isDefault'] == true || json['is_default'] == true,
      color: _parseColor(json['color'] ?? json['color_hex']),
      restaurants: rawRestaurants is List
          ? rawRestaurants
              .whereType<Map>()
              .map((restaurant) => RestaurantModel.fromJson(
                    Map<String, dynamic>.from(restaurant),
                  ))
              .where((restaurant) => restaurant.effectiveStoreId.isNotEmpty)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'label': label,
      'isDefault': isDefault,
      'color': color?.toARGB32(),
      'restaurants':
          restaurants.map((restaurant) => restaurant.toJson()).toList(),
    };
  }

  static Color? _parseColor(Object? value) {
    if (value is int) return Color(value);
    if (value is! String || value.trim().isEmpty) return null;

    final hex = value.trim().replaceFirst('#', '');
    final normalizedHex = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(normalizedHex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
