import 'package:flutter/material.dart';

class AiAnalysisCard extends StatelessWidget {
  final int truthScore;

  const AiAnalysisCard({super.key, required this.truthScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4EC), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 헤더 ──
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, size: 15, color: Color(0xFF2B54E8)),
                    SizedBox(width: 6),
                    Text(
                      'AI 진실 분석',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E2E4E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── 신뢰도 원형 (크기 조정) ──
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 75,
                height: 75,
                child: CircularProgressIndicator(
                  value: truthScore / 100,
                  strokeWidth: 6,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: AlwaysStoppedAnimation(_trustColor(truthScore)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$truthScore%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _trustTextColor(truthScore),
                    ),
                  ),
                  const Text(
                    'TRUST',
                    style: TextStyle(
                      fontSize: 7,
                      color: Color(0xFFA0A0C0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 상세 분석 바 (하단 배치) ──
          _StatBar(
            label: '광고 의심 게재',
            value: (100 - truthScore).clamp(0, 100),
            color: const Color(0xFFE85C5C),
          ),
          const SizedBox(height: 12),
          _StatBar(
            label: '진성 리뷰 비율',
            value: truthScore,
            color: const Color(0xFF4CBB87),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _trustColor(int score) {
    if (score >= 80) return const Color(0xFF4CBB87);
    if (score >= 60) return const Color(0xFFF5A623);
    return const Color(0xFFE85C5C);
  }

  Color _trustTextColor(int score) {
    if (score >= 80) return const Color(0xFF1A7A4A);
    if (score >= 60) return const Color(0xFFA05800);
    return const Color(0xFFC0392B);
  }
}

// ── 통계 진행 바 ──────────────────────────────────────────────────────────────

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9090A8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$value%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: const Color(0xFFEEEEEE),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
