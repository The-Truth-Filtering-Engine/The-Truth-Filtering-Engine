import 'package:flutter/material.dart';
import '../../1-2_restaurant_detail/providers/blog_review.dart';
import '../../../core/theme/app_theme.dart';

// ── 앱바 로고 ─────────────────────────────────
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary900,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
          ),
        ),
        const SizedBox(width: 7),
        Text('진실의 입',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.primary900,
            )),
      ],
    );
  }
}

// ── 신뢰도 배지 ───────────────────────────────
class StatusBadge extends StatelessWidget {
  final ReviewStatus status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ReviewStatus.real => ('진성', AppColors.success50, AppColors.success700),
      ReviewStatus.suspicious => (
          '의심',
          AppColors.warning50,
          AppColors.warning700
        ),
      ReviewStatus.ad => ('광고', AppColors.danger50, AppColors.danger700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

// ── Trust 원형 점수 ───────────────────────────
class TrustCircle extends StatelessWidget {
  final int score;
  const TrustCircle(this.score, {super.key});

  Color get _color {
    if (score >= 70) return AppColors.success400;
    if (score >= 40) return AppColors.warning400;
    return AppColors.danger400;
  }

  Color get _textColor {
    if (score >= 70) return AppColors.success700;
    if (score >= 40) return AppColors.warning700;
    return AppColors.danger700;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _color, width: 5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$score',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _textColor)),
          Text('TRUST',
              style: TextStyle(fontSize: 8, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

// ── 진행 바 ───────────────────────────────────
class StatProgressBar extends StatelessWidget {
  final String label;
  final int value; // 0~100
  final Color color;
  const StatProgressBar({
    super.key,
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
            Text(label, style: AppText.caption()),
            Text('$value%',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: AppColors.bg,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

// ── 블로그 카드 ───────────────────────────────
class BlogCard extends StatelessWidget {
  final BlogReview blog;
  final VoidCallback onTap;
  const BlogCard({super.key, required this.blog, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(blog.title,
                      style:
                          AppText.body().copyWith(fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                StatusBadge(blog.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(blog.preview,
                style: AppText.caption().copyWith(height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(blog.author, style: AppText.caption()),
                Text(blog.date,
                    style:
                        AppText.caption().copyWith(color: AppColors.textHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 광고 경고 배너 ────────────────────────────
class AdWarningBanner extends StatelessWidget {
  final BlogReview blog;
  const AdWarningBanner(this.blog, {super.key});

  @override
  Widget build(BuildContext context) {
    final isAd = blog.status == ReviewStatus.ad;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAd ? AppColors.danger50 : AppColors.warning50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAd
              ? AppColors.danger400.withOpacity(.4)
              : AppColors.warning400.withOpacity(.4),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18,
              color: isAd ? AppColors.danger700 : AppColors.warning700),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 11,
                    color: isAd ? AppColors.danger700 : AppColors.warning700,
                    height: 1.5),
                children: [
                  const TextSpan(text: '이 포스팅은 '),
                  TextSpan(
                      text: '광고 확률 ${blog.adProbability}%',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                      text: isAd
                          ? '로 분석되었습니다.\n협찬·원고료 패턴이 감지되었어요.'
                          : '로 분석되었습니다.\n일부 홍보성 표현이 감지되었어요.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 섹션 타이틀 ───────────────────────────────
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textHint,
              letterSpacing: .5)),
    );
  }
}
