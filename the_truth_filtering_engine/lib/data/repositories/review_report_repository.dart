import '../models/review_report_model.dart';
import '../sources/review_report_remote_source.dart';

enum ReportSubmitResult {
  submitted, // 신고 완료
  cancelled, // 신고 취소
  duplicate, // 다른 유저가 이미 신고한 리뷰
  error,
}

class ReviewReportRepository {
  final ReviewReportRemoteSource _source;

  ReviewReportRepository(this._source);

  // ── 신고 토글 ──────────────────────────────
  // 내가 신고한 리뷰 → 취소
  // 아무도 신고 안 함 → 신고 제출
  // 다른 사람이 신고 → duplicate 반환
  Future<ReportSubmitResult> toggleReport({
    required String reviewId,
    required ReviewReport report,
  }) async {
    try {
      // ① 내가 신고했는지 확인 → 취소
      final alreadyMine = await _source.hasReportedByUser(
        reviewId: reviewId,
        userEmail: report.userEmail,
      );
      if (alreadyMine) {
        await _source.cancelReport(reviewId);
        return ReportSubmitResult.cancelled;
      }

      // ② 다른 사람이 이미 신고했는지 확인
      final empty = await _source.isReportEmpty(reviewId);
      if (!empty) return ReportSubmitResult.duplicate;

      // ③ 신고 제출
      await _source.submitReport(reviewId: reviewId, report: report);
      return ReportSubmitResult.submitted;
    } catch (e) {
      return ReportSubmitResult.error;
    }
  }
}
