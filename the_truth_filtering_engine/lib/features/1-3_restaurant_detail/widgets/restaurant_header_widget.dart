import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../../1-1_map/widgets/truth_score_badge.dart';

class RestaurantHeaderWidget extends StatelessWidget {
  final RestaurantModel restaurant;

  const RestaurantHeaderWidget({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 이미지 영역 ──
        Container(
          height: 220,
          width: double.infinity,
          color: const Color(0xFFD4A96A),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _WoodGrainPainter()),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9E75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${r.truthScore}% Veritas Verified',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
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
                  TruthScoreBadge(score: r.truthScore),
                ],
              ),
              const SizedBox(height: 14),

              // ── 액션 버튼 ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _ActionItem(icon: Icons.phone_outlined, label: 'Call'),
                  _ActionItem(icon: Icons.bookmark_outline, label: 'Save'),
                  _ActionItem(icon: Icons.near_me_outlined, label: 'Route'),
                  _ActionItem(icon: Icons.ios_share_outlined, label: 'Share'),
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
  const _ActionItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

// ── 이미지 플레이스홀더 패턴 ──────────────────────────────────────────────────

class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBF8C50).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (double y = 0; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 6), paint);
    }
  }

  @override
  bool shouldRepaint(_WoodGrainPainter old) => false;
}
