import 'package:flutter/material.dart';

import '../../../core/design_system/widgets/widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../1-3_restaurant_detail/providers/blog_review.dart';

class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DsAppLogo();
  }
}

class StatusBadge extends StatelessWidget {
  final ReviewStatus status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      ReviewStatus.real => ('진성', DsTone.real),
      ReviewStatus.suspicious => ('의심', DsTone.suspicious),
      ReviewStatus.ad => ('광고', DsTone.ad),
    };
    return DsBadge(label: label, tone: tone);
  }
}

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
          Text(
            '$score',
            style: AppText.subtitle().copyWith(
              color: _textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'TRUST',
            style: AppText.label().copyWith(fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class StatProgressBar extends StatelessWidget {
  final String label;
  final int value;
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
            Text(
              '$value%',
              style: AppText.caption().copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x1),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
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

class BlogCard extends StatelessWidget {
  final BlogReview blog;
  final VoidCallback onTap;

  const BlogCard({
    super.key,
    required this.blog,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DsCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  blog.title,
                  style: AppText.body().copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              StatusBadge(blog.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            blog.preview,
            style: AppText.caption().copyWith(height: 1.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(blog.author, style: AppText.caption()),
              Text(
                blog.date,
                style: AppText.caption().copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdWarningBanner extends StatelessWidget {
  final BlogReview blog;

  const AdWarningBanner(this.blog, {super.key});

  @override
  Widget build(BuildContext context) {
    final isAd = blog.status == ReviewStatus.ad;
    final tone = isAd ? DsTone.ad : DsTone.suspicious;

    return DsCard(
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: dsToneForeground(tone),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppText.caption().copyWith(
                  color: dsToneForeground(tone),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: '이 포스팅은 '),
                  TextSpan(
                    text: '광고 확률 ${blog.adProbability}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: isAd
                        ? '로 분석되었습니다.\n협찬·원고료 패턴이 감지되었어요.'
                        : '로 분석되었습니다.\n일부 홍보성 표현이 감지되었어요.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Text(
        text.toUpperCase(),
        style: AppText.label().copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
