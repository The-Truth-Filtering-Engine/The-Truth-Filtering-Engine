import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/restaurant_model.dart';

class TruthScoreMarker extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onTap;

  const TruthScoreMarker({
    super.key,
    required this.restaurant,
    this.onTap,
  });

  Color get _bgColor {
    switch (restaurant.markerType) {
      case MarkerType.high:
        return AppColors.markerHigh;
      case MarkerType.mid:
        return AppColors.markerHigh;
      case MarkerType.low:
        return AppColors.markerHigh;
    }
  }

  String get _markerEmoji {
    final category = restaurant.category;
    final normalized = category.toLowerCase();
    if (category.contains('카페') ||
        normalized.contains('cafe') ||
        normalized.contains('coffee') ||
        normalized.contains('☕')) {
      return '☕';
    }
    return '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(_markerEmoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
