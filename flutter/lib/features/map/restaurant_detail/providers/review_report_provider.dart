import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/models/review_report_model.dart';
import '../../../../data/repositories/review_report_repository.dart';
import '../../../../data/sources/review_report_remote_source.dart';

// ── 의존성 ────────────────────────────────────
final reviewReportRepositoryProvider = Provider<ReviewReportRepository>(
  (ref) => ReviewReportRepository(
    ReviewReportRemoteSource(Supabase.instance.client),
  ),
);

// ── 상태 ──────────────────────────────────────
class ReviewReportState {
  final bool isLoading;
  final ReportSubmitResult? result;

  const ReviewReportState({this.isLoading = false, this.result});

  ReviewReportState copyWith({bool? isLoading, ReportSubmitResult? result}) =>
      ReviewReportState(
        isLoading: isLoading ?? this.isLoading,
        result: result ?? this.result,
      );
}

// ── Notifier ──────────────────────────────────
class ReviewReportNotifier extends StateNotifier<ReviewReportState> {
  final ReviewReportRepository _repo;

  ReviewReportNotifier(this._repo) : super(const ReviewReportState());

  Future<ReportSubmitResult> toggle({
    required String reviewId,
    required ReportCategory category,
    required String userEmail,
    String? memo,
  }) async {
    state = state.copyWith(isLoading: true);

    final result = await _repo.toggleReport(
      reviewId: reviewId,
      report: ReviewReport(
        category: category,
        userEmail: userEmail,
        memo: memo,
      ),
    );

    state = state.copyWith(isLoading: false, result: result);
    return result;
  }

  void reset() => state = const ReviewReportState();
}

final reviewReportProvider =
    StateNotifierProvider.autoDispose<ReviewReportNotifier, ReviewReportState>(
  (ref) => ReviewReportNotifier(ref.read(reviewReportRepositoryProvider)),
);
