import 'package:flutter/material.dart';
import 'package:truth_mouth/core/providers/analysis_mode_provider.dart';

enum ReviewStatus { real, suspicious, ad }

/// 광고 확률 등급
/// 1에 가까울수록 광고 → 등급이 높을수록 광고성 강함
enum AdGrade {
  low, // < 0.778  → 상 (진성)
  // mid, //
  high, // > 0.778  → 하 (광고)
}

extension AdGradeX on AdGrade {
  String get label => switch (this) {
        AdGrade.low => '일반',
        // AdGrade.mid => '중',
        AdGrade.high => '의심',
      };

  Color get color {
    switch (this) {
      case AdGrade.low:
        return const Color(0xFF34A853);
      // case AdGrade.mid:
      //   return const Color(0xFFF9A825);
      case AdGrade.high:
        return const Color.fromARGB(255, 229, 144, 53);
    }
  }

  Color get bgColor {
    switch (this) {
      case AdGrade.low:
        return const Color.fromARGB(255, 240, 248, 240);
      // case AdGrade.mid:
      //   return const Color(0xFFFFFDE7);
      case AdGrade.high:
        return const Color.fromARGB(255, 255, 245, 235);
    }
  }
}

AdGrade adGradeFromScore(double score) {
  if (score >= 0.778) return AdGrade.high;
  // if (score >= 0.3) return AdGrade.mid;
  return AdGrade.low;
}

class BlogReview {
  final int id;
  final String? reviewId;
  final String title;
  final String author;
  final String date;
  final String preview;
  final String content;
  final String url;
  final ReviewStatus status;
  final int adProbability; // 0~100
  final bool isSponsored;
  final int likeCount;

  /// llm 또는 finetuned 확률값 (0.0~1.0, 없으면 null)
  final double? adScore;

  AdGrade? get adGrade => adScore != null ? adGradeFromScore(adScore!) : null;

  String get effectiveReviewId {
    final normalizedReviewId = reviewId?.trim();
    if (normalizedReviewId != null && normalizedReviewId.isNotEmpty) {
      return normalizedReviewId;
    }
    return id.toString();
  }

  const BlogReview({
    required this.id,
    this.reviewId,
    required this.title,
    required this.author,
    required this.date,
    required this.preview,
    required this.content,
    required this.url,
    required this.status,
    required this.adProbability,
    required this.isSponsored,
    this.likeCount = 0,
    this.adScore,
  });

  // ── FastAPI /search 응답 단건 파싱 ────────────────────────────────────
  factory BlogReview.fromApiWithMode(
    Map<String, dynamic> json,
    AnalysisMode mode,
  ) {
    // ── 1. pred (int) : electra 0/1, llm 모드는 float으로 별도 처리 ──
    final pred = switch (mode) {
      AnalysisMode.model => json['is_ad_electra_pred'] as int? ?? -1,
      AnalysisMode.llm => -1,
    };

    // ── 2. adScore (float) : 모드에 따라 다른 컬럼 사용 ──
    final double? adScore = switch (mode) {
      AnalysisMode.llm => (json['is_ad_llm_pred'] as num?)?.toDouble(),
      AnalysisMode.model => (json['is_ad_finetuned_pred'] as num?)?.toDouble(),
    };

    // ── 3. status ──
    final ReviewStatus status = switch (mode) {
      AnalysisMode.llm => adScore == null
          ? ReviewStatus.suspicious
          : adScore >= 0.6
              ? ReviewStatus.ad
              : adScore < 0.3
                  ? ReviewStatus.real
                  : ReviewStatus.suspicious,
      AnalysisMode.model => switch (pred) {
          1 => ReviewStatus.ad,
          0 => ReviewStatus.real,
          _ => ReviewStatus.suspicious,
        },
    };

    // ── 4. adProbability (0~100 int) ──
    final int adProb = switch (mode) {
      AnalysisMode.llm => adScore != null ? (adScore * 100).round() : 50,
      AnalysisMode.model => switch (pred) {
          1 => 90,
          0 => 10,
          _ => 50,
        },
    };

    final String description = json['review_description'] as String? ?? '';

    final rawId = json['id'];
    final reviewId = rawId?.toString() ?? '';

    return BlogReview(
      id: _intIdFromJson(rawId),
      reviewId: reviewId,
      title: json['review_title'] as String? ?? '(제목 없음)',
      author: json['review_bloggername'] as String? ?? '알 수 없음',
      date: _formatDate(json['review_postdate'] as String? ?? ''),
      preview: description.length > 80
          ? '"${description.substring(0, 80)}..."'
          : '"$description"',
      content: description,
      url: json['review_url'] as String? ?? '',
      status: status,
      adProbability: adProb,
      isSponsored: status == ReviewStatus.ad,
      likeCount: _likeCountFromJson(
        json['likes'] ?? json['like_count'] ?? json['likeCount'],
      ),
      adScore: adScore,
    );
  }
}

int _intIdFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return 0;

  return int.tryParse(text) ?? text.hashCode;
}

int _likeCountFromJson(Object? value) {
  if (value is List) return value.length;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// YYYYMMDD → YYYY.MM.DD 변환. 그 외 형식은 그대로 반환.
String _formatDate(String raw) {
  if (raw.length == 8) {
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }
  return raw;
}

// ── ShopInfo ──────────────────────────────────────────────────────────────

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

  factory ShopInfo.fromApiResponse({
    required String name,
    required String category,
    required List<BlogReview> reviews,
  }) {
    final total = reviews.length;
    // status 대신 adGrade 기준으로 통일
    final adCount = reviews.where((r) {
      if (r.adGrade != null) return r.adGrade == AdGrade.high;
      return r.status == ReviewStatus.ad; // adGrade 없을 때 fallback
    }).length;

    final realCount = reviews.where((r) {
      if (r.adGrade != null) return r.adGrade == AdGrade.low;
      return r.status == ReviewStatus.real;
    }).length;

    // suspicious/mid는 총계에는 포함되지만 양쪽 다 아님
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

// ── 더미 데이터 ──────────────────────────────────────────────────────────

final dummyShop = ShopInfo(
  name: '오모테나시 스시',
  category: '일식 · 서울 강남구',
  trustScore: 85,
  adRatio: 23,
  realRatio: 77,
  totalReviews: 4,
);

final dummyBlogs = <BlogReview>[
  BlogReview(
    id: 1,
    title: '강남 오마카세 솔직 후기, 진짜 갔다왔어요',
    author: '내돈내산 먹방러',
    date: '2024.05.14',
    preview: '"예약 3개월 기다렸는데 정말 가치있었어요. 생선 신선도가 놀라울 정도였고, 셰프가 직접 설명해줘서 더 좋았어요."',
    content: '오늘은 강남 오마카세 후기를 써볼게요.\n\n3개월 전부터 예약해서 드디어 다녀왔습니다.',
    url: 'https://blog.naver.com/realfoodie/223456789',
    status: ReviewStatus.real,
    adProbability: 4,
    isSponsored: false,
    adScore: 0.12,
  ),
  BlogReview(
    id: 2,
    title: '✨강남 스시 맛집 추천✨ 분위기도 최고!',
    author: '라이프스타일블로그',
    date: '2024.05.20',
    preview: '"이번에 협찬으로 방문하게 되었는데요~ 정말 너무 맛있고 서비스도 좋아서 강추해요!"',
    content: '안녕하세요! 오늘은 강남 핫플 스시 맛집을 소개해드릴게요.',
    url: 'https://blog.naver.com/lifestyleblog/223567890',
    status: ReviewStatus.ad,
    adProbability: 92,
    isSponsored: true,
    adScore: 0.780171275138855,
  ),
  BlogReview(
    id: 3,
    title: '남편 생일 기념 오마카세 다녀왔어요',
    author: '일상기록 주부',
    date: '2024.05.09',
    preview: '"가격이 조금 부담스럽지만 특별한 날에 딱 맞는 곳이에요."',
    content: '남편 생일을 맞아 특별한 저녁을 준비했어요.',
    url: 'https://blog.naver.com/dailymom/223345678',
    status: ReviewStatus.real,
    adProbability: 8,
    isSponsored: false,
    adScore: 0.08,
  ),
  BlogReview(
    id: 4,
    title: '강남 스시 오마카세 가격 비교 분석',
    author: '맛집탐방 foodie',
    date: '2024.04.28',
    preview: '"여러 오마카세를 다녀봤는데 여기가 가성비로는 최고인 것 같아요."',
    content: '강남 오마카세 투어를 하면서 여러 곳을 다녀봤는데 비교 후기를 써볼게요.',
    url: 'https://blog.naver.com/foodielog/223234567',
    status: ReviewStatus.suspicious,
    adProbability: 41,
    isSponsored: false,
    adScore: 0.43,
  ),
];

const recentSearches = ['오모테나시 스시', '청담 스시 갠', '연남동 카페', '강남 라멘'];
