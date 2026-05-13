class ReviewItem {
  final int id;
  final String name;
  final String? reviewUrl;
  final String? reviewTitle;
  final String? reviewDescription;
  final String? reviewBloggername;
  final String? reviewPostdate;
  final int? isAd;
  final int? isAdLlmPred;
  final int? isAdBertPred;

  ReviewItem({
    required this.id,
    required this.name,
    this.reviewUrl,
    this.reviewTitle,
    this.reviewDescription,
    this.reviewBloggername,
    this.reviewPostdate,
    this.isAd,
    this.isAdLlmPred,
    this.isAdBertPred,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      reviewUrl: json['review_url'],
      reviewTitle: json['review_title'],
      reviewDescription: json['review_description'],
      reviewBloggername: json['review_bloggername'],
      reviewPostdate: json['review_postdate'],
      isAd: json['is_ad'],
      isAdLlmPred: json['is_ad_llm_pred'],
      isAdBertPred: json['is_ad_bert_pred'],
    );
  }

  bool get isAdByLlm => isAdLlmPred == 1;
}
