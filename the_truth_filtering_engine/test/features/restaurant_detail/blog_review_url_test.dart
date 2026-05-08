import 'package:flutter_test/flutter_test.dart';
import 'package:truth_mouth/features/1-3_restaurant_detail/utils/blog_review_url.dart';

void main() {
  test('converts desktop Naver blog post URLs to mobile URLs', () {
    final uri = mobileBlogReviewUri(
      'https://blog.naver.com/hopeeveryk/222909098196',
    );

    expect(uri.toString(), 'https://m.blog.naver.com/hopeeveryk/222909098196');
  });

  test('converts Naver PostView URLs to mobile post URLs', () {
    final uri = mobileBlogReviewUri(
      'https://blog.naver.com/PostView.naver?blogId=hopeeveryk&logNo=222909098196',
    );

    expect(uri.toString(), 'https://m.blog.naver.com/hopeeveryk/222909098196');
  });

  test('leaves non-Naver blog URLs unchanged', () {
    final uri = mobileBlogReviewUri('https://example.com/reviews/1');

    expect(uri.toString(), 'https://example.com/reviews/1');
  });
}
