import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/widgets/widgets.dart';
import '../../1-3_restaurant_detail/providers/blog_review.dart';

class ReviewGradeBadge extends StatelessWidget {
  final ReviewStatus status;

  const ReviewGradeBadge({super.key, required this.status});

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
