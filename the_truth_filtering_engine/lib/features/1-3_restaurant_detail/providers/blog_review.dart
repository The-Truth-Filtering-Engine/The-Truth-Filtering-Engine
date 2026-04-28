import 'package:truth_mouth/core/providers/analysis_mode_provider.dart';

enum ReviewStatus { real, suspicious, ad }

class BlogReview {
  final int id;
  final String title;
  final String author;
  final String date;
  final String preview;
  final String content;
  final String url;
  final ReviewStatus status;
  final int adProbability; // 0~100
  final bool isSponsored;

  const BlogReview({
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
  });

  // ── FastAPI /search 응답 단건 파싱 ──────────────────────────────────────
  factory BlogReview.fromApiWithMode(
    Map<String, dynamic> json,
    AnalysisMode mode, // analysis_mode_provider.dart 에서 import
  ) {
    final pred = switch (mode) {
      AnalysisMode.model => json['is_ad_electra_pred'] as int? ?? -1,
      AnalysisMode.llm => json['is_ad_llm_pred'] as int? ?? -1,
    };

    final int adProb = switch (pred) {
      1 => 90,
      0 => 10,
      _ => 50,
    };

    final ReviewStatus status = switch (pred) {
      1 => ReviewStatus.ad,
      0 => ReviewStatus.real,
      _ => ReviewStatus.suspicious,
    };

    final String description = json['review_description'] as String? ?? '';

    return BlogReview(
      id: json['id'] as int? ?? 0,
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
      isSponsored: pred == 1,
    );
  }
}

/// YYYYMMDD → YYYY.MM.DD 변환. 그 외 형식은 그대로 반환.
String _formatDate(String raw) {
  if (raw.length == 8) {
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }
  return raw;
}

// ── ShopInfo ────────────────────────────────────────────────────────────────

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

  /// API 응답 전체(reviews 배열 포함)로 ShopInfo 생성
  factory ShopInfo.fromApiResponse({
    required String name,
    required String category,
    required List<BlogReview> reviews,
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

// ── 더미 데이터 (개발/테스트용 유지) ────────────────────────────────────────

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
    content:
        '오늘은 강남 오마카세 후기를 써볼게요.\n\n3개월 전부터 예약해서 드디어 다녀왔습니다. 총 12코스로 진행됐는데, 각 코스마다 셰프가 직접 재료 설명을 해줘서 정말 좋았어요.\n\n특히 성게알 군함말이가 인상적이었어요. 홋카이도산 성게를 사용한다고 하는데, 쓴맛이 전혀 없고 달달하면서 크리미한 맛이 정말 일품이었습니다.\n\n가격은 1인 12만원으로 오마카세치고는 합리적인 편이에요. 총평: 강남에서 이 가격에 이 퀄리티면 충분히 재방문 의사 있어요!',
    url: 'https://blog.naver.com/realfoodie/223456789',
    status: ReviewStatus.real,
    adProbability: 4,
    isSponsored: false,
  ),
  BlogReview(
    id: 2,
    title: '✨강남 스시 맛집 추천✨ 분위기도 최고!',
    author: '라이프스타일블로그',
    date: '2024.05.20',
    preview: '"이번에 협찬으로 방문하게 되었는데요~ 정말 너무 맛있고 서비스도 좋아서 강추해요!"',
    content:
        '안녕하세요! 오늘은 강남 핫플 스시 맛집을 소개해드릴게요.\n\n이번에 협찬으로 방문하게 되었는데요, 정말 너무 맛있고 서비스도 훌륭했어요!\n\n인테리어가 너무 예쁘고 사진도 잘 나와요. 인스타 감성 넘치는 공간이랍니다.\n\n오마카세 코스 정말 맛있었어요. 특히 디저트가 인상적이었어요!\n\n예약은 홈페이지에서 하실 수 있어요. 꼭 방문해 보세요!',
    url: 'https://blog.naver.com/lifestyleblog/223567890',
    status: ReviewStatus.ad,
    adProbability: 92,
    isSponsored: true,
  ),
  BlogReview(
    id: 3,
    title: '남편 생일 기념 오마카세 다녀왔어요',
    author: '일상기록 주부',
    date: '2024.05.09',
    preview: '"가격이 조금 부담스럽지만 특별한 날에 딱 맞는 곳이에요. 서비스도 친절하고 맛도 기대 이상이었어요."',
    content:
        '남편 생일을 맞아 특별한 저녁을 준비했어요.\n\n평소에 스시를 좋아하는 남편을 위해 오마카세를 예약했는데, 결과적으로 대만족이었어요!\n\n12만원이라는 가격이 처음엔 부담됐지만, 코스 하나하나가 정말 정성스러워서 충분히 값어치를 했어요.\n\n직원분들이 처음부터 끝까지 매우 친절하게 안내해주셔서 식사 내내 기분이 좋았어요.',
    url: 'https://blog.naver.com/dailymom/223345678',
    status: ReviewStatus.real,
    adProbability: 8,
    isSponsored: false,
  ),
  BlogReview(
    id: 4,
    title: '강남 스시 오마카세 가격 비교 분석',
    author: '맛집탐방 foodie',
    date: '2024.04.28',
    preview: '"여러 오마카세를 다녀봤는데 여기가 가성비로는 최고인 것 같아요. 예약이 힘든 게 단점이에요."',
    content:
        '강남 오마카세 투어를 하면서 여러 곳을 다녀봤는데 비교 후기를 써볼게요.\n\n가성비 측면에서는 이곳이 제일 낫더라고요. 비슷한 가격대의 다른 곳들보다 코스 퀄리티가 확실히 높았어요.\n\n단점이 있다면 예약이 정말 어려워요. 3개월 대기는 기본이에요.\n\n전체적으로 만족스러웠고, 기회가 된다면 재방문할 의향이 있어요.',
    url: 'https://blog.naver.com/foodielog/223234567',
    status: ReviewStatus.suspicious,
    adProbability: 41,
    isSponsored: false,
  ),
];

const recentSearches = ['오모테나시 스시', '청담 스시 갠', '연남동 카페', '강남 라멘'];
