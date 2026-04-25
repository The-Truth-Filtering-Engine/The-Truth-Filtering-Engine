import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/blog_review.dart';

class ReviewItem extends StatelessWidget {
  final BlogReview blog;
  final VoidCallback onTap;

  const ReviewItem({
    super.key,
    required this.blog,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(blog.title, style: AppText.title()),
      subtitle: Text(
        blog.preview.isNotEmpty ? blog.preview : '요약 없음',
        style: AppText.caption(),
      ),
      onTap: onTap,
    );
  }
}
