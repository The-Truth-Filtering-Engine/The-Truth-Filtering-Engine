import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
        return AppColors.markerMid;
      case MarkerType.low:
        return AppColors.markerMid;
    }
  }

  TextStyle get _textStyle {
    switch (restaurant.markerType) {
      case MarkerType.high:
        return AppTextStyles.markerScore;
      case MarkerType.mid:
      case MarkerType.low:
        return AppTextStyles.markerScoreDark;
    }
  }

  bool get _showStar => restaurant.markerType != MarkerType.high;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 말풍선 본체
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_showStar) ...[
                  Icon(
                    Icons.verified,
                    color: AppColors.markerVerified,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  Icon(
                    Icons.star,
                    color: AppColors.markerMidText,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                ],
                Text('${restaurant.truthScore}', style: _textStyle),
              ],
            ),
          ),
          // 말풍선 꼬리
          CustomPaint(
            size: const Size(12, 6),
            painter: _MarkerTailPainter(color: _bgColor),
          ),
        ],
      ),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  final Color color;
  _MarkerTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkerTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
