import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ── 신고 사유 정의 ────────────────────────────────────────────────────────
enum ReportReason {
  spam('spam', '스팸 / 도배'),
  fake('fake', '허위 정보'),
  ad('ad', '광고성 리뷰'),
  inappropriate('inappropriate', '부적절한 내용'),
  other('other', '기타');

  const ReportReason(this.value, this.label);
  final String value;
  final String label;
}

// ── 신고 바텀시트 ─────────────────────────────────────────────────────────
class ReportBottomSheet extends StatefulWidget {
  final String reviewId;
  final String baseUrl;

  const ReportBottomSheet({
    super.key,
    required this.reviewId,
    required this.baseUrl,
  });

  /// 외부에서 호출하는 헬퍼
  static Future<void> show(
    BuildContext context, {
    required String reviewId,
    required String baseUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBottomSheet(reviewId: reviewId, baseUrl: baseUrl),
    );
  }

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  ReportReason? _selected;
  final _detailCtrl = TextEditingController();
  bool _loading = false;

  static const _green = Color(0xFF1D9E75);
  static const _red = Color(0xFFE24B4A);

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _loading = true);

    try {
      final resp = await http.post(
        Uri.parse('${widget.baseUrl}/api/reviews/${widget.reviewId}/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'review_id': widget.reviewId,
          'reason': _selected!.value,
          'detail': _detailCtrl.text.trim().isEmpty
              ? null
              : _detailCtrl.text.trim(),
        }),
      );

      if (!mounted) return;

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
            backgroundColor: _green,
          ),
        );
      } else {
        throw Exception('서버 오류 ${resp.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신고 실패: $e'), backgroundColor: _red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE7E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '리뷰 신고',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E2A24),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '신고 사유를 선택해 주세요.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7A72)),
          ),
          const SizedBox(height: 16),

          // 신고 사유 선택
          ...ReportReason.values.map((r) => _reasonTile(r)),
          const SizedBox(height: 12),

          // 부가 설명 (선택)
          TextField(
            controller: _detailCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '추가 설명 (선택 사항)',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9BB0A8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              filled: true,
              fillColor: const Color(0xFFF4F8F6),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDE7E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 제출 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selected == null || _loading) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFDDE7E1),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '신고 제출',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonTile(ReportReason r) {
    final selected = _selected == r;
    return GestureDetector(
      onTap: () => setState(() => _selected = r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF3DE) : const Color(0xFFF4F8F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _green : const Color(0xFFDDE7E1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? _green : const Color(0xFF9BB0A8),
            ),
            const SizedBox(width: 10),
            Text(
              r.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected
                    ? const Color(0xFF1E2A24)
                    : const Color(0xFF4A5E54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
