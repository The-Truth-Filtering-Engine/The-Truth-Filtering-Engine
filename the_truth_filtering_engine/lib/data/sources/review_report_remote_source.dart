import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_report_model.dart';

class ReviewReportRemoteSource {
  final SupabaseClient _client;
  static const _table = 'reviews';

  ReviewReportRemoteSource(this._client);

  // ── 신고 제출 ──────────────────────────────
  Future<void> submitReport({
    required String reviewId,
    required ReviewReport report,
  }) async {
    await _client.from(_table).update({
      'report': report.toJson(),
      'confirm': ConfirmStatus.pending.code,
    }).eq('id', reviewId);
  }

  // ── 신고 취소 (report, confirm → NULL) ────
  Future<void> cancelReport(String reviewId) async {
    await _client.from(_table).update({
      'report': null,
      'confirm': null,
    }).eq('id', reviewId);
  }

  // ── 내가 신고한 리뷰인지 확인 ─────────────
  Future<bool> hasReportedByUser({
    required String reviewId,
    required String userEmail,
  }) async {
    final res =
        await _client.from(_table).select('report').eq('id', reviewId).single();

    final report = (res as Map<String, dynamic>)['report'];
    if (report == null) return false;
    return (report as Map)['user_email'] == userEmail;
  }

  // ── 아무도 신고 안 했는지 확인 ────────────
  Future<bool> isReportEmpty(String reviewId) async {
    final res =
        await _client.from(_table).select('report').eq('id', reviewId).single();

    return (res as Map<String, dynamic>)['report'] == null;
  }
}
