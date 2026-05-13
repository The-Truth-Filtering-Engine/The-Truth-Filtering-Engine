import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/review_report_repository.dart';
import 'review_report_dialog.dart';

/// 신고 상태를 실시간으로 반영하는 신고 버튼
///
/// 사용:
/// ```dart
/// ReportButton(reviewId: blog.id)
/// ```
class ReportButton extends ConsumerWidget {
  final String reviewId;
  final bool iconOnly;
  final VoidCallback? onReportSubmitted;

  const ReportButton({
    super.key,
    required this.reviewId,
    this.iconOnly = false,
    this.onReportSubmitted,
  });

  // 현재 이 리뷰가 내가 신고한 리뷰인지 실시간 확인
  Future<bool> _isMyReport(String? email) async {
    if (email == null) return false;
    try {
      final res = await Supabase.instance.client
          .from('reviews')
          .select('report')
          .eq('id', reviewId)
          .single();
      final report = res['report'];
      if (report is! Map) return false;
      return report['user_email'] == email;
    } catch (_) {
      return false;
    }
  }

  Future<void> _open(BuildContext context, String? email) async {
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신고하려면 로그인이 필요합니다.',
              style: AppText.body().copyWith(color: Colors.white)),
          backgroundColor: AppColors.warning400,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await showReviewReportDialog(context, reviewId: reviewId);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (result == ReportSubmitResult.submitted) {
      onReportSubmitted?.call();
      _showSnack(
        messenger,
        '신고가 접수되어 리뷰를 숨겼습니다.',
        isError: false,
      );
    }
  }

  void _showSnack(
    ScaffoldMessengerState messenger,
    String message, {
    required bool isError,
  }) {
    messenger.showSnackBar(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(currentUserEmailProvider);

    return FutureBuilder<bool>(
      future: _isMyReport(email),
      builder: (context, snapshot) {
        final isReported = snapshot.data ?? false;

        if (iconOnly) {
          return GestureDetector(
            onTap: () => _open(context, email),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                isReported ? Icons.flag : Icons.flag_outlined,
                size: 16,
                color: isReported ? AppColors.danger400 : AppColors.textHint,
              ),
            ),
          );
        }

        return TextButton.icon(
          onPressed: () => _open(context, email),
          icon: Icon(
            isReported ? Icons.flag : Icons.flag_outlined,
            size: 13,
          ),
          label: Text(
            isReported ? '신고됨' : '신고',
            style: AppText.caption().copyWith(
              color: isReported ? AppColors.danger400 : AppColors.textHint,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor:
                isReported ? AppColors.danger400 : AppColors.textHint,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }
}
