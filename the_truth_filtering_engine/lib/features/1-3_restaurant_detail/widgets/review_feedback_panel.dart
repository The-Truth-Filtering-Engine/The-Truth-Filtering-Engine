import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ════════════════════════════════════════════════════════════════════════════
// 상수
// ════════════════════════════════════════════════════════════════════════════

const _green = Color(0xFF1D9E75);
const _red = Color(0xFFE24B4A);
const _amber = Color(0xFFEF9F27);
const _gray = Color(0xFF6B7A72);
const _bg = Color(0xFFF4F8F6);
const _border = Color(0xFFDDE7E1);

const _allTags = ['광고같음', '내돈내산', '과장됨', '사진없음', '재방문의향', '친절함'];

// ════════════════════════════════════════════════════════════════════════════
// ReviewFeedbackPanel  ─  카드 하단에 붙이는 통합 피드백 패널
// ════════════════════════════════════════════════════════════════════════════

class ReviewFeedbackPanel extends StatefulWidget {
  final String reviewId;
  final String baseUrl;
  final bool? aiPredIsAd; // AI가 광고라 했는지 여부

  const ReviewFeedbackPanel({
    super.key,
    required this.reviewId,
    required this.baseUrl,
    this.aiPredIsAd,
  });

  @override
  State<ReviewFeedbackPanel> createState() => _ReviewFeedbackPanelState();
}

class _ReviewFeedbackPanelState extends State<ReviewFeedbackPanel> {
  // 투표
  int _trust = 0;
  int _doubt = 0;
  String? _myVote; // "trust" | "doubt" | null

  // AI 피드백
  bool? _aiCorrect; // true=맞음 / false=틀림

  // 태그
  Map<String, int> _tags = {};
  String? _myTag;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── 데이터 로드 ─────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    await Future.wait([_loadVotes(), _loadTags()]);
  }

  Future<void> _loadVotes() async {
    try {
      final resp = await http
          .get(
            Uri.parse('${widget.baseUrl}/api/reviews/${widget.reviewId}/votes'),
          )
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body);
        if (mounted)
          setState(() {
            _trust = d['trust'] ?? 0;
            _doubt = d['doubt'] ?? 0;
          });
      }
    } catch (_) {}
  }

  Future<void> _loadTags() async {
    try {
      final resp = await http
          .get(
            Uri.parse('${widget.baseUrl}/api/reviews/${widget.reviewId}/tags'),
          )
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        final raw = d['tags'] as Map<String, dynamic>? ?? {};
        if (mounted)
          setState(() => _tags = raw.map((k, v) => MapEntry(k, v as int)));
      }
    } catch (_) {}
  }

  // ── API 호출 ────────────────────────────────────────────────────────────

  Future<void> _vote(String vote) async {
    if (_myVote == vote || _loading) return;
    setState(() {
      _loading = true;
    });

    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/api/reviews/${widget.reviewId}/vote'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'review_id': widget.reviewId, 'vote': vote}),
      );
      setState(() {
        if (_myVote != null) {
          _myVote == 'trust' ? _trust-- : _doubt--;
        }
        _myVote = vote;
        vote == 'trust' ? _trust++ : _doubt++;
      });
    } catch (_) {
      _snack('투표 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendAiFeedback(bool correct) async {
    if (_aiCorrect != null || _loading) return;
    setState(() {
      _loading = true;
    });

    try {
      await http.post(
        Uri.parse(
          '${widget.baseUrl}/api/reviews/${widget.reviewId}/ai-feedback',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'review_id': widget.reviewId,
          'ai_was_correct': correct,
          'user_label': !correct
              ? (widget.aiPredIsAd == true ? 'not_ad' : 'ad')
              : null,
        }),
      );
      setState(() => _aiCorrect = correct);
      _snack(
        correct ? 'AI 판별이 맞다고 평가해 주셨어요 👍' : 'AI 판별 오류를 알려주셨어요. 모델 개선에 반영됩니다.',
      );
    } catch (_) {
      _snack('피드백 전송 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addTag(String tag) async {
    if (_myTag != null || _loading) return;
    setState(() {
      _loading = true;
    });

    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/api/reviews/${widget.reviewId}/tag'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'review_id': widget.reviewId, 'tag': tag}),
      );
      setState(() {
        _myTag = tag;
        _tags[tag] = (_tags[tag] ?? 0) + 1;
      });
    } catch (_) {
      _snack('태그 추가 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: _border),
          const SizedBox(height: 10),
          _votRow(),
          const SizedBox(height: 10),
          _aiFeedbackRow(),
          const SizedBox(height: 10),
          _tagRow(),
        ],
      ),
    );
  }

  // 1. 신뢰도 투표
  Widget _votRow() {
    final total = _trust + _doubt;
    final ratio = total > 0 ? _trust / total : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이 리뷰 믿을만한가요?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _gray,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _voteBtn(
              label: '👍 신뢰됨',
              count: _trust,
              active: _myVote == 'trust',
              activeColor: _green,
              onTap: () => _vote('trust'),
            ),
            const SizedBox(width: 8),
            _voteBtn(
              label: '👎 의심됨',
              count: _doubt,
              active: _myVote == 'doubt',
              activeColor: _red,
              onTap: () => _vote('doubt'),
            ),
            if (ratio != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: _red.withOpacity(.25),
                        valueColor: const AlwaysStoppedAnimation(_green),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '신뢰 ${(ratio * 100).toStringAsFixed(0)}% ($total명)',
                      style: const TextStyle(fontSize: 10, color: _gray),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _voteBtn({
    required String label,
    required int count,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? activeColor : _border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? activeColor : _gray,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? activeColor : _gray,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 2. AI 피드백
  Widget _aiFeedbackRow() {
    if (widget.aiPredIsAd == null) return const SizedBox.shrink();

    final aiLabel = widget.aiPredIsAd! ? '광고 의심' : '일반 리뷰';
    final aiColor = widget.aiPredIsAd! ? _red : _green;

    return Row(
      children: [
        const Text('AI 판별:', style: TextStyle(fontSize: 12, color: _gray)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: aiColor.withOpacity(.1),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: aiColor.withOpacity(.5)),
          ),
          child: Text(
            aiLabel,
            style: TextStyle(
              fontSize: 11,
              color: aiColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        if (_aiCorrect == null) ...[
          const Text('맞나요?', style: TextStyle(fontSize: 11, color: _gray)),
          const SizedBox(width: 6),
          _aiFeedbackBtn('맞아요', true, _green),
          const SizedBox(width: 4),
          _aiFeedbackBtn('아니에요', false, _amber),
        ] else
          Row(
            children: [
              Icon(
                _aiCorrect!
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                size: 14,
                color: _aiCorrect! ? _green : _amber,
              ),
              const SizedBox(width: 4),
              Text(
                _aiCorrect! ? '정확한 판별이에요' : '오류를 신고했어요',
                style: TextStyle(
                  fontSize: 11,
                  color: _aiCorrect! ? _green : _amber,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _aiFeedbackBtn(String label, bool correct, Color color) {
    return GestureDetector(
      onTap: () => _sendAiFeedback(correct),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 3. 태그
  Widget _tagRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '태그',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _gray,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allTags.map((tag) {
            final count = _tags[tag] ?? 0;
            final isMine = _myTag == tag;
            final hasCount = count > 0;

            return GestureDetector(
              onTap: _myTag == null ? () => _addTag(tag) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isMine
                      ? _green.withOpacity(.12)
                      : hasCount
                      ? Colors.white
                      : _bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isMine
                        ? _green
                        : hasCount
                        ? _border
                        : _border.withOpacity(.6),
                    width: isMine ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 11,
                        color: isMine
                            ? _green
                            : hasCount
                            ? const Color(0xFF1E2A24)
                            : _gray,
                        fontWeight: isMine || hasCount
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    if (hasCount) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine ? _green : _gray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_myTag == null)
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text(
              '탭해서 태그를 추가하세요',
              style: TextStyle(fontSize: 10, color: _gray),
            ),
          ),
      ],
    );
  }
}
