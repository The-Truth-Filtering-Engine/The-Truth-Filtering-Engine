import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'package:truth_mouth/models/blog_review_model.dart';

class ReviewItem extends StatelessWidget {
  final BlogReviewModel blog;
  final VoidCallback onTap;

  const ReviewItem({
    super.key,
    required this.blog,
    required this.onTap,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ?Ä?Ä Î±ÉÏ? + ?úÎ™© ?Ä?Ä
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

          // ?Ä?Ä ÎØ∏Î¶¨Î≥¥Í∏∞ ?Ä?Ä
          Text(
            blog.preview.isNotEmpty ? blog.preview : '?îÏïΩ ?ÜÏùå',
            style: AppText.caption(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // ?Ä?Ä ?ëÏÑ±??¬∑ ?†Ïßú ?Ä?Ä
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
                '¬∑',
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
    );
  }
}

// ?Ä?Ä Hover Ïπ¥Îìú ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

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
    // hover ??Î∞∞Í≤Ω¬∑?åÎëêÎ¶¨Î? ?ΩÍ∞Ñ ÏßÑÌïòÍ≤?
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

// ?Ä?Ä Í¥ëÍ≥† ?±Í∏â Î±ÉÏ? ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

class _AdGradeBadge extends StatelessWidget {
  final AdGrade grade;

  const _AdGradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: grade.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        grade.label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

