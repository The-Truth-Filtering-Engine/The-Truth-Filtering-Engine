import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class NoDataCard extends StatelessWidget {
  final bool isAnalyzing;
  final VoidCallback onAnalyzeTap;

  const NoDataCard({
    super.key,
    required this.isAnalyzing,
    required this.onAnalyzeTap,
  });

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
        children: [
          // ── 아이콘 ──
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 28,
              color: Color(0xFF2B54E8),
            ),
          ),
          const SizedBox(height: 14),

          // ── 안내 문구 ──
          const Text(
            '현재 데이터가 없습니다',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E2E4E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '분석을 원하시면 아래 분석하기 버튼을 눌러주세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF9090A8)),
          ),
          const SizedBox(height: 20),

          // ── 분석하기 버튼 ──
          GestureDetector(
            onTap: isAnalyzing ? null : onAnalyzeTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isAnalyzing
                    ? AppColors.primary.withOpacity(0.6)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: isAnalyzing
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text('분석하기', style: AppTextStyles.primaryButton),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
