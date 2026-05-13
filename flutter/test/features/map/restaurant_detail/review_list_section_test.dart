import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truth_mouth/core/providers/current_user_provider.dart';
import 'package:truth_mouth/core/theme/app_theme.dart';
import 'package:truth_mouth/features/map/restaurant_detail/providers/blog_review.dart';
import 'package:truth_mouth/features/map/restaurant_detail/widgets/review_list_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpReviewList(
    WidgetTester tester,
    List<BlogReview> blogs, {
    bool hasMoreReviews = false,
    bool isLoadingReviewBatch = false,
    ValueChanged<int>? onRequestReviewBatch,
    ReviewOpenGuard? onReviewTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserEmailProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReviewListSection(
                shopInfo: ShopInfo(
                  name: '테스트 가게',
                  category: '테스트 카테고리',
                  trustScore: 80,
                  adRatio: 20,
                  realRatio: 80,
                  totalReviews: blogs.length,
                ),
                blogs: blogs,
                hasMoreReviews: hasMoreReviews,
                isLoadingReviewBatch: isLoadingReviewBatch,
                onRequestReviewBatch: onRequestReviewBatch,
                onReviewTap: onReviewTap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<BlogReview> buildReviews(int count) {
    return List.generate(count, (index) {
      final number = index + 1;
      final padded = number.toString().padLeft(2, '0');

      return BlogReview(
        id: number,
        title: '리뷰 $padded',
        author: '작성자 $padded',
        date: '2024.05.$padded',
        preview: '리뷰 $padded 미리보기',
        content: '리뷰 $padded 본문',
        url: 'https://example.com/reviews/$number',
        status: ReviewStatus.real,
        adProbability: number,
        isSponsored: false,
        adScore: 0.1,
      );
    });
  }

  BlogReview buildReview({
    required int id,
    required String title,
    required int likeCount,
    required int adProbability,
    required String date,
  }) {
    return BlogReview(
      id: id,
      title: title,
      author: '작성자 $id',
      date: date,
      preview: '$title 미리보기',
      content: '$title 본문',
      url: 'https://example.com/reviews/$id',
      status: ReviewStatus.real,
      adProbability: adProbability,
      isSponsored: false,
      likeCount: likeCount,
      adScore: adProbability / 100,
    );
  }

  testWidgets('sorts recommended reviews by heart count first', (tester) async {
    await pumpReviewList(
      tester,
      [
        buildReview(
          id: 1,
          title: '하트 1개 리뷰',
          likeCount: 1,
          adProbability: 1,
          date: '2024.05.03',
        ),
        buildReview(
          id: 2,
          title: '하트 5개 리뷰',
          likeCount: 5,
          adProbability: 80,
          date: '2024.05.01',
        ),
        buildReview(
          id: 3,
          title: '하트 3개 리뷰',
          likeCount: 3,
          adProbability: 20,
          date: '2024.05.02',
        ),
      ],
    );

    expect(find.text('추천순'), findsOneWidget);
    expect(find.text('신뢰순'), findsOneWidget);
    expect(find.text('최신순'), findsOneWidget);

    final topRecommended = tester.getTopLeft(find.text('하트 5개 리뷰')).dy;
    final middleRecommended = tester.getTopLeft(find.text('하트 3개 리뷰')).dy;
    final bottomRecommended = tester.getTopLeft(find.text('하트 1개 리뷰')).dy;

    expect(topRecommended, lessThan(middleRecommended));
    expect(middleRecommended, lessThan(bottomRecommended));
  });

  testWidgets('shows 10 reviews per page and moves to the next page',
      (tester) async {
    await pumpReviewList(tester, buildReviews(11));

    expect(find.text('리뷰 01'), findsOneWidget);
    expect(find.text('리뷰 10'), findsOneWidget);
    expect(find.text('리뷰 11'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '다음'));
    await tester.tap(find.widgetWithText(OutlinedButton, '다음'));
    await tester.pumpAndSettle();

    expect(find.text('리뷰 01'), findsNothing);
    expect(find.text('리뷰 11'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    final nextButton = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '다음'));
    final previousButton = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '이전'));

    expect(nextButton.onPressed, isNull);
    expect(previousButton.onPressed, isNotNull);
  });

  testWidgets('calls review tap guard before opening a review', (tester) async {
    BlogReview? tappedReview;

    await pumpReviewList(
      tester,
      buildReviews(1),
      onReviewTap: (review) async {
        tappedReview = review;
        return false;
      },
    );

    await tester.tap(find.text('리뷰 01'));
    await tester.pump();

    expect(tappedReview?.id, 1);
  });

  testWidgets('resets to the first page when changing sort tabs',
      (tester) async {
    await pumpReviewList(tester, buildReviews(11));

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '다음'));
    await tester.tap(find.widgetWithText(OutlinedButton, '다음'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('최신순'));
    await tester.tap(find.textContaining('최신순'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('리뷰 11'), findsOneWidget);
    expect(find.text('리뷰 01'), findsNothing);
  });

  testWidgets('hides pagination controls when reviews fit on one page',
      (tester) async {
    await pumpReviewList(tester, buildReviews(10));

    expect(find.text('리뷰 01'), findsOneWidget);
    expect(find.text('리뷰 10'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '이전'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '다음'), findsNothing);
  });

  testWidgets('shows skeletons when moving to an unloaded batch page',
      (tester) async {
    int? requestedPage;
    final reviews = buildReviews(100);

    await pumpReviewList(
      tester,
      reviews,
      hasMoreReviews: true,
      onRequestReviewBatch: (page) => requestedPage = page,
    );

    for (var i = 0; i < 10; i++) {
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, '다음'));
      await tester.tap(find.widgetWithText(OutlinedButton, '다음'));
      await tester.pumpAndSettle();
    }

    expect(requestedPage, 10);

    await pumpReviewList(
      tester,
      reviews,
      hasMoreReviews: true,
      isLoadingReviewBatch: true,
    );

    expect(
        find.byKey(const ValueKey('review-page-skeleton-0')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('review-page-skeleton-9')), findsOneWidget);
    expect(find.text('리뷰 100'), findsNothing);
    expect(find.text('11 / 30'), findsOneWidget);
  });
}
