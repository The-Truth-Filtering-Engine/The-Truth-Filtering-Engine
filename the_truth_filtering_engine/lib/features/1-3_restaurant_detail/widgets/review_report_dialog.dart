import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/review_report_model.dart';
import '../../../data/repositories/review_report_repository.dart';
import '../../1-3_restaurant_detail/providers/review_report_provider.dart';

Future<ReportSubmitResult?> showReviewReportDialog(
  BuildContext context, {
  required String reviewId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewReportSheet(reviewId: reviewId),
  );
}

class _ReviewReportSheet extends ConsumerStatefulWidget {
  final String reviewId;
  const _ReviewReportSheet({required this.reviewId});

  @override
  ConsumerState<_ReviewReportSheet> createState() => _ReviewReportSheetState();
}

class _ReviewReportSheetState extends ConsumerState<_ReviewReportSheet> {
  ReportCategory? _selected;
  final _memoController = TextEditingController();

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;

    final email = ref.read(currentUserEmailProvider);
    if (email == null) return;

    final result = await ref.read(reviewReportProvider.notifier).toggle(
          reviewId: widget.reviewId,
          category: _selected!,
          userEmail: email,
          memo: _selected == ReportCategory.other
              ? _memoController.text.trim()
              : null,
        );

    if (!mounted) return;

    switch (result) {
      case ReportSubmitResult.submitted:
        Navigator.pop(context, result);
      case ReportSubmitResult.duplicate:
        _showSnack(context, '이미 다른 사용자가 신고한 리뷰입니다.', isError: true);
      case ReportSubmitResult.error:
        _showSnack(context, '오류가 발생했습니다. 다시 시도해 주세요.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewReportProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.danger50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flag_rounded,
                    size: 16, color: AppColors.danger400),
              ),
              const SizedBox(width: 10),
              Text('리뷰 신고', style: AppText.title()),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('신고 사유를 선택해 주세요. 검토 후 조치가 이루어집니다.', style: AppText.caption()),
          const SizedBox(height: 20),
          ...ReportCategory.values.map((cat) => _CategoryTile(
                category: cat,
                isSelected: _selected == cat,
                onTap: () => setState(() => _selected = cat),
              )),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _selected == ReportCategory.other
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: _memoController,
                      maxLines: 3,
                      maxLength: 200,
                      style: AppText.body(),
                      decoration: const InputDecoration(
                        hintText: '신고 사유를 직접 입력해 주세요.',
                        counterText: '',
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (_selected == null || state.isLoading) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger400,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('신고하기',
                      style: AppText.body().copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ReportCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile(
      {required this.category, required this.isSelected, required this.onTap});

  IconData get _icon => switch (category) {
        ReportCategory.ad => Icons.campaign_outlined,
        ReportCategory.irrelevant => Icons.link_off_outlined,
        ReportCategory.inappropriate => Icons.block_outlined,
        ReportCategory.other => Icons.more_horiz_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.danger50 : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.danger400 : AppColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(_icon,
                size: 18,
                color:
                    isSelected ? AppColors.danger700 : AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(category.label,
                style: AppText.body().copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      isSelected ? AppColors.danger700 : AppColors.textPrimary,
                )),
            const Spacer(),
            AnimatedOpacity(
              opacity: isSelected ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.danger400),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSnack(BuildContext context, String message, {required bool isError}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content:
          Text(message, style: AppText.body().copyWith(color: Colors.white)),
      backgroundColor: isError ? AppColors.danger400 : AppColors.success400,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ),
  );
}
