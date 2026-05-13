import 'package:flutter_test/flutter_test.dart';
import 'package:truth_mouth/core/providers/analysis_mode_provider.dart';
import 'package:truth_mouth/features/map/restaurant_detail/providers/blog_review.dart';

void main() {
  test('preserves Supabase UUID review id for review actions', () {
    const reviewId = '9c9f9a41-8e2f-4b62-9e3d-a4de65fdc6ef';

    final review = BlogReview.fromApiWithMode(
      {
        'id': reviewId,
        'review_title': 'title',
        'review_description': 'description',
        'review_bloggername': 'author',
        'review_postdate': '20260512',
        'review_url': 'https://example.com/review',
        'is_ad_llm_pred': 0.1,
      },
      AnalysisMode.llm,
    );

    expect(review.effectiveReviewId, reviewId);
    expect(review.id, isNot(0));
  });
}
