import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/widgets/widgets.dart';

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
          'detail':
              _detailCtrl.text.trim().isEmpty ? null : _detailCtrl.text.trim(),
        }),
      );

      if (!mounted) return;

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        Navigator.pop(context);
        DsToast.show(
          context,
          '신고가 접수되었습니다. 검토 후 조치하겠습니다.',
          tone: DsTone.success,
        );
      } else {
        throw Exception('서버 오류 ${resp.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      DsToast.show(context, '신고 실패: $e', tone: DsTone.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DsBottomSheet(
      showHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.x6,
              right: AppSpacing.x6,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '리뷰 신고',
                  style: AppText.title(),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  '신고 사유를 선택해 주세요.',
                  style:
                      AppText.body().copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.x4),

                // 신고 사유 선택
                ...ReportReason.values.map((r) => _reasonTile(r)),
                const SizedBox(height: AppSpacing.x3),

                // 부가 설명 (선택)
                DsTextField(
                  controller: _detailCtrl,
                  maxLines: 2,
                  hintText: '추가 설명 (선택 사항)',
                ),
                const SizedBox(height: AppSpacing.x5),

                // 제출 버튼
                DsButton(
                  label: '신고 제출',
                  variant: DsButtonVariant.danger,
                  loading: _loading,
                  onPressed: (_selected == null || _loading) ? null : _submit,
                ),
              ],
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
          color: selected ? AppColors.primary50 : AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.border,
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
              color: selected ? AppColors.primary500 : AppColors.textHint,
            ),
            const SizedBox(width: AppSpacing.x3),
            Text(
              r.label,
              style: AppText.subtitle().copyWith(
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
