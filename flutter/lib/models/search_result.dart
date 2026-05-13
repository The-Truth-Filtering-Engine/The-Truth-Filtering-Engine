import 'review_item.dart';

class SearchResult {
  final String source;
  final List<ReviewItem> reviews;
  final String summary;

  SearchResult({
    required this.source,
    required this.reviews,
    required this.summary,
  });

  int get total => reviews.length;
  int get adCount => reviews.where((r) => r.isAdByLlm).length;
  int get realCount => reviews.where((r) => !r.isAdByLlm).length;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      source: json['source'] ?? '',
      summary: json['summary'] ?? '',
      reviews: (json['reviews'] as List? ?? [])
          .map((e) => ReviewItem.fromJson(e))
          .toList(),
    );
  }
}
