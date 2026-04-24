import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'truth_score_badge.dart';
import '../models/restaurant_model.dart';

class RestaurantBottomSheet extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onDetailTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onShareTap;

  const RestaurantBottomSheet({
    super.key,
    required this.restaurant,
    this.onDetailTap,
    this.onBookmarkTap,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.sheetDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 본문 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 이미지 + 정보 + 뱃지
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFD4A96A),
                        child: restaurant.imageUrl != null
                            ? Image.network(
                                restaurant.imageUrl!,
                                fit: BoxFit.cover,
                              )
                            : const _PlaceholderImage(),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // 이름 + 주소 + 카테고리
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: AppTextStyles.restaurantName,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.sheetSubtext,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${restaurant.address} · ${restaurant.category}',
                                style: AppTextStyles.restaurantMeta,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),
                    // TRUTH 뱃지
                    TruthScoreBadge(score: restaurant.truthScore),
                  ],
                ),

                const SizedBox(height: 14),

                // 리뷰 요약 인용
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.sheetQuoteBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '"${restaurant.reviewSummary}"',
                    style: AppTextStyles.reviewQuote,
                  ),
                ),

                const SizedBox(height: 16),

                // 버튼 영역
                Row(
                  children: [
                    // 상세보기 버튼
                    Expanded(
                      child: GestureDetector(
                        onTap: onDetailTap,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '상세 보기',
                                style: AppTextStyles.primaryButton,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 북마크 버튼
                    _IconActionButton(
                      icon: Icons.bookmark_border,
                      onTap: onBookmarkTap,
                    ),
                    const SizedBox(width: 10),

                    // 공유 버튼
                    _IconActionButton(
                      icon: Icons.ios_share,
                      onTap: onShareTap,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.sheetQuoteBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: AppColors.primary),
      ),
    );
  }
}

// 이미지 없을 때 플레이스홀더 (목재 질감 느낌)
class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFFD4A96A)),
        Positioned.fill(
          child: CustomPaint(painter: _WoodGrainPainter()),
        ),
      ],
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBF8C50).withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (double y = 0; y < size.height; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 5), paint);
    }
  }

  @override
  bool shouldRepaint(_WoodGrainPainter oldDelegate) => false;
}
