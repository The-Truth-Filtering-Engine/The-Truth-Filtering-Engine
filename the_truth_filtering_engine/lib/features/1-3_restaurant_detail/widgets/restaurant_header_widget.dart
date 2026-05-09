import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../../1-1_map/widgets/truth_score_badge.dart';

class RestaurantHeaderWidget extends StatelessWidget {
  final RestaurantModel restaurant;
  final bool isBookmarked;
  final VoidCallback? onCallTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onRouteTap;
  final VoidCallback? onShareTap;

  const RestaurantHeaderWidget({
    super.key,
    required this.restaurant,
    this.isBookmarked = false,
    this.onCallTap,
    this.onBookmarkTap,
    this.onRouteTap,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 이미지 영역 ──
        SizedBox(
          height: 220,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 카테고리 이미지 (imageUrl 있으면 우선, 없으면 카테고리 이미지)
              r.imageUrl != null
                  ? Image.network(
                      r.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        r.categoryImagePath,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      r.categoryImagePath,
                      fit: BoxFit.cover,
                    ),
              // 하단 그라데이션
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
              // Veritas 배지
              // Positioned(
              //   top: 14,
              //   left: 14,
              //   child: Container(
              //     padding:
              //         const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              //     decoration: BoxDecoration(
              //       color: const Color(0xFF1D9E75),
              //       borderRadius: BorderRadius.circular(20),
              //     ),
              //     child: Text(
              //       '${r.truthScore}% Veritas Verified',
              //       style: const TextStyle(
              //         color: Colors.white,
              //         fontSize: 11,
              //         fontWeight: FontWeight.w500,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),

        // ── 가게 기본 정보 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: AppTextStyles.restaurantName),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 13, color: Color(0xFF888888)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${r.address} · ${r.category}',
                                style: AppTextStyles.restaurantMeta,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // TruthScoreBadge(score: r.truthScore),
                ],
              ),
              const SizedBox(height: 14),

              // ── 액션 버튼 ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ActionItem(
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    onTap: onCallTap,
                  ),
                  _ActionItem(
                    icon:
                        isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    label: 'Save',
                    onTap: onBookmarkTap,
                  ),
                  _ActionItem(
                    icon: Icons.near_me_outlined,
                    label: 'Route',
                    onTap: onRouteTap,
                  ),
                  _ActionItem(
                    icon: Icons.ios_share_outlined,
                    label: 'Share',
                    onTap: onShareTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 액션 아이템 ───────────────────────────────────────────────────────────────

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF2B54E8)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6060A0))),
        ],
      ),
    );
  }
}
// _WoodGrainPainter 삭제됨
