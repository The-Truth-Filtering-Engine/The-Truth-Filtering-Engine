import 'package:flutter/material.dart';

enum ReviewStatus { real, suspicious, ad }

enum AdGrade { low, mid, high }

extension AdGradeX on AdGrade {
  String get label => switch (this) {
        AdGrade.low => '상',
        AdGrade.mid => '중',
        AdGrade.high => '하',
      };

  Color get color => switch (this) {
        AdGrade.low => const Color(0xFF34A853),
        AdGrade.mid => const Color(0xFFF9A825),
        AdGrade.high => const Color(0xFFE53935),
      };

  Color get bgColor => switch (this) {
        AdGrade.low => const Color(0xFFE8F5E9),
        AdGrade.mid => const Color(0xFFFFFDE7),
        AdGrade.high => const Color(0xFFFFEBEE),
      };
}

class BlogReviewModel {
  final int id;
  final String title;
  final String author;
  final String date;
  final String preview;
  final String content;
  final String url;
  final ReviewStatus status;
  final int adProbability;
  final bool isSponsored;
  final double? adScore;

  const BlogReviewModel({
    required this.id,
    required this.title,
    required this.author,
    required this.date,
    required this.preview,
    required this.content,
    required this.url,
    required this.status,
    required this.adProbability,
    required this.isSponsored,
    this.adScore,
  });

  AdGrade? get adGrade => adScore != null ? _adGradeFromScore(adScore!) : null;

  static AdGrade _adGradeFromScore(double score) {
    if (score >= 0.6) return AdGrade.high;
    if (score >= 0.3) return AdGrade.mid;
    return AdGrade.low;
  }

  factory BlogReviewModel.fromJson(Map<String, dynamic> json) {
    final double? adScore = (json['adScore'] ?? json['is_ad_llm_pred'] ?? json['is_ad_finetuned_pred'] as num?)?.toDouble();
    
    ReviewStatus status = ReviewStatus.suspicious;
    if (adScore != null) {
      if (adScore >= 0.6) status = ReviewStatus.ad;
      else if (adScore < 0.3) status = ReviewStatus.real;
    } else if (json['is_ad_electra_pred'] == 1) {
      status = ReviewStatus.ad;
    } else if (json['is_ad_electra_pred'] == 0) {
      status = ReviewStatus.real;
    }

    final int adProb = adScore != null ? (adScore * 100).round() : 50;
    final String description = _clean(json['review_description'] ?? json['preview'] ?? '');

    return BlogReviewModel(
      id: (json['id'] ?? 0) as int,
      title: _clean(json['review_title'] ?? json['title'] ?? ''),
      author: _clean(json['review_bloggername'] ?? json['author'] ?? ''),
      date: _formatDate((json['review_postdate'] ?? json['date'] ?? '').toString()),
      preview: description.length > 80 ? '"${description.substring(0, 80)}..."' : '"$description"',
      content: description,
      url: (json['review_url'] ?? json['url'] ?? '').toString(),
      status: status,
      adProbability: adProb,
      isSponsored: status == ReviewStatus.ad,
      adScore: adScore,
    );
  }

  static String _clean(dynamic value) {
    return (value ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  static String _formatDate(String raw) {
    if (raw.length == 8) {
      return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
    }
    return raw;
  }
}

class ShopInfo {
  final String name;
  final String category;
  final int trustScore;
  final int adRatio;
  final int realRatio;
  final int totalReviews;

  const ShopInfo({
    required this.name,
    required this.category,
    required this.trustScore,
    required this.adRatio,
    required this.realRatio,
    required this.totalReviews,
  });

  factory ShopInfo.fromReviews({
    required String name,
    required String category,
    required List<BlogReviewModel> reviews,
  }) {
    final total = reviews.length;
    final adCount = reviews.where((r) => r.status == ReviewStatus.ad).length;
    final realCount = total - adCount;

    final int adRatio = total == 0 ? 0 : (adCount / total * 100).round();
    final int realRatio = total == 0 ? 0 : (realCount / total * 100).round();

    return ShopInfo(
      name: name,
      category: category,
      trustScore: realRatio,
      adRatio: adRatio,
      realRatio: realRatio,
      totalReviews: total,
    );
  }
}
