import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'report_bottom_sheet.dart';

// ── 데이터 모델 ──────────────────────────────────────────────────────────
class ReviewItem {
  final String id;
  final String title;
  final String description;
  final bool? isAdElectra;
  final double? adScore;

  const ReviewItem({
    required this.id,
    required this.title,
    required this.description,
    this.isAdElectra,
    this.adScore,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
    id: j['id']?.toString() ?? '',
    title: j['title'] ?? '',
    description: j['review_description'] ?? '',
    isAdElectra: j['is_ad_electra_pred'] as bool?,
    adScore: (j['is_ad_finetuned_pred'] as num?)?.toDouble(),
  );
}

// ── 페이지네이션 리뷰 리스트 ─────────────────────────────────────────────
class PaginatedReviewList extends StatefulWidget {
  final String query;
  final String baseUrl;
  final int pageSize;

  const PaginatedReviewList({
    super.key,
    required this.query,
    required this.baseUrl,
    this.pageSize = 10,
  });

  @override
  State<PaginatedReviewList> createState() => _PaginatedReviewListState();
}

class _PaginatedReviewListState extends State<PaginatedReviewList> {
  final List<ReviewItem> _reviews = [];
  int _start = 0;
  int _total = 0;
  bool _loading = false;
  bool _initialLoad = true;
  String? _error;

  static const _green = Color(0xFF1D9E75);

  @override
  void initState() {
    super.initState();
    _fetchPage();
  }

  @override
  void didUpdateWidget(PaginatedReviewList old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      _reviews.clear();
      _start = 0;
      _total = 0;
      _initialLoad = true;
      _fetchPage();
    }
  }

  Future<void> _fetchPage() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${widget.baseUrl}/api/reviews').replace(
        queryParameters: {
          'query': widget.query,
          'start': '$_start',
          'limit': '${widget.pageSize}',
        },
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) throw Exception('서버 오류 ${resp.statusCode}');

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (data['reviews'] as List)
          .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _reviews.addAll(items);
        _total = data['total'] ?? 0;
        _start += items.length;
        _initialLoad = false;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasNext => _start < _total;

  @override
  Widget build(BuildContext context) {
    if (_initialLoad && _loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_error != null && _reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE24B4A), size: 36),
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A72)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _fetchPage, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_reviews.isEmpty) {
      return const Center(
        child: Text('검색 결과가 없습니다.', style: TextStyle(color: Color(0xFF6B7A72))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 결과 수 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            '리뷰 $_total건 · ${_reviews.length}개 표시 중',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A72)),
          ),
        ),

        // 리뷰 카드 목록
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFDDE7E1)),
          itemBuilder: (ctx, i) =>
              _ReviewCard(review: _reviews[i], baseUrl: widget.baseUrl),
        ),

        // 더 보기 버튼
        if (_hasNext)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : _fetchPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: _green),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _green,
                        ),
                      )
                    : Text('더 보기 (${_total - _start}개 남음)'),
              ),
            ),
          ),

        if (!_hasNext && _reviews.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                '모든 리뷰를 불러왔습니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9BB0A8)),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 개별 리뷰 카드 ────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final ReviewItem review;
  final String baseUrl;

  const _ReviewCard({required this.review, required this.baseUrl});

  static const _green = Color(0xFF1D9E75);
  static const _red = Color(0xFFE24B4A);

  @override
  Widget build(BuildContext context) {
    final isAd = review.isAdElectra ?? false;
    final score = review.adScore;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 + 신고 버튼
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  review.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E2A24),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: Color(0xFF9BB0A8),
                ),
                tooltip: '신고',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => ReportBottomSheet.show(
                  context,
                  reviewId: review.id,
                  baseUrl: baseUrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 본문
          Text(
            review.description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4A5E54),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // 광고 여부 배지 + 신뢰도 바
          Row(
            children: [
              _adBadge(isAd),
              if (score != null) ...[
                const SizedBox(width: 10),
                Expanded(child: _trustBar(score)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _adBadge(bool isAd) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAd ? const Color(0xFFFFF0F0) : const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isAd ? _red : _green, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAd ? Icons.campaign_outlined : Icons.verified_outlined,
            size: 13,
            color: isAd ? _red : _green,
          ),
          const SizedBox(width: 4),
          Text(
            isAd ? '광고 의심' : '일반 리뷰',
            style: TextStyle(
              fontSize: 11,
              color: isAd ? _red : _green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustBar(double score) {
    // score: 0(광고) ~ 1(신뢰) — finetuned_pred가 광고 확률이면 1-score
    final trust = 1.0 - score.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: trust,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFDDE7E1),
                  valueColor: AlwaysStoppedAnimation(
                    trust > 0.6 ? _green : _red,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '신뢰 ${(trust * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7A72)),
            ),
          ],
        ),
      ],
    );
  }
}
