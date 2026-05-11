import 'package:flutter/material.dart';

import '../../../core/design_system/widgets/widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/blog_review.dart';
import 'review_action_buttons.dart';

class ReviewItem extends StatelessWidget {
  final BlogReview blog;
  final VoidCallback onTap;
  final VoidCallback? onReportSubmitted;

  const ReviewItem({
    super.key,
    required this.blog,
    required this.onTap,
    this.onReportSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final grade = blog.adGrade;
    final bgColor = grade?.bgColor ?? AppColors.surface;
    final borderColor = grade?.color.withOpacity(0.35) ?? AppColors.border;

    return _HoverCard(
      bgColor: bgColor,
      borderColor: borderColor,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 108),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 뱃지 + 제목 ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (grade != null) ...[
                        _AdGradeBadge(grade: grade),
                        const SizedBox(width: 7),
                      ],
                      Expanded(
                        child: Text(
                          blog.title,
                          style: AppText.title(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── 미리보기 ──
                  Text(
                    blog.preview.isNotEmpty ? blog.preview : '요약 없음',
                    style: AppText.caption(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // ── 작성자 · 날짜 ──
                  Row(
                    children: [
                      Text(
                        blog.author,
                        style: AppText.caption().copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '·',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        blog.date,
                        style: AppText.caption().copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: ReviewActionButtons(
                  reviewId: blog.id.toString(),
                  onReportSubmitted: onReportSubmitted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hover 카드 ────────────────────────────────────────────────────────────────

class _HoverCard extends StatefulWidget {
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;
  final Widget child;

  const _HoverCard({
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
    required this.child,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // hover 시 배경·테두리를 약간 진하게
    final bg = _hovered
        ? Color.alphaBlend(
            const Color.fromARGB(255, 255, 255, 255).withOpacity(0.3),
            widget.bgColor)
        : widget.bgColor;
    final border = _hovered
        ? widget.borderColor
            .withOpacity((widget.borderColor.opacity + 0.3).clamp(0.0, 1.0))
        : widget.borderColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.borderColor.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── 광고 등급 뱃지 ─────────────────────────────────────────────────────────────

class _AdGradeBadge extends StatelessWidget {
  final AdGrade grade;

  const _AdGradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    final tone = switch (grade) {
      AdGrade.low => DsTone.real,
      AdGrade.mid => DsTone.suspicious,
      AdGrade.high => DsTone.ad,
    };
    return DsBadge(label: grade.label, tone: tone);
  }
}
