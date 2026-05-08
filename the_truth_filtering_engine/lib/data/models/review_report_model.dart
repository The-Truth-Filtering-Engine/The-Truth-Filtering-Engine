// ─────────────────────────────────────────────
// reviews 테이블 컬럼 구조
//   report  : jsonb  → { "category": int, "user_email": string, "memo": string? }
//   confirm : int4   → 0=보류, 1=가짜 신고, 2=진짜 신고
// ─────────────────────────────────────────────

/// 신고 유형
/// report.category 에 int 코드로 저장됩니다.
enum ReportCategory {
  ad(1, '광고'),
  irrelevant(2, '관련없는 내용'),
  inappropriate(3, '부적합한 내용'),
  other(4, '기타');

  const ReportCategory(this.code, this.label);
  final int code;
  final String label;

  static ReportCategory? fromCode(int? code) {
    if (code == null) return null;
    try {
      return ReportCategory.values.firstWhere((e) => e.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// 개발자 분류 상태
/// reviews.confirm 컬럼에 int4 로 저장됩니다.
///   0 = 보류(기본값/미검토)
///   1 = 가짜 신고
///   2 = 진짜 신고
enum ConfirmStatus {
  pending(0, '보류'),
  fake(1, '가짜 신고'),
  real(2, '진짜 신고');

  const ConfirmStatus(this.code, this.label);
  final int code;
  final String label;

  static ConfirmStatus fromCode(int? code) {
    try {
      return ConfirmStatus.values.firstWhere((e) => e.code == code);
    } catch (_) {
      return ConfirmStatus.pending;
    }
  }
}

/// reviews.report 컬럼(jsonb)에 저장되는 신고 데이터
class ReviewReport {
  final ReportCategory category;
  final String userEmail;
  final String? memo; // ReportCategory.other 일 때만 사용

  const ReviewReport({
    required this.category,
    required this.userEmail,
    this.memo,
  });

  /// Supabase jsonb 컬럼에 저장할 Map
  Map<String, dynamic> toJson() => {
        'category': category.code, // int: 1~4
        'user_email': userEmail,
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
      };

  factory ReviewReport.fromJson(Map<String, dynamic> json) => ReviewReport(
        category: ReportCategory.fromCode(json['category'] as int?) ??
            ReportCategory.other,
        userEmail: json['user_email']?.toString() ?? '',
        memo: json['memo']?.toString(),
      );
}

/*
  ──────────────────────────────────────────────
  reviews 테이블 — report / confirm 컬럼 확인
  ──────────────────────────────────────────────

  이미 Supabase에 아래 두 컬럼이 존재합니다:
    report  jsonb   (NULL 허용)
    confirm int4    (NULL 허용)

  필요 시 기본값 지정 마이그레이션:
  ──────────────────────────────────────────────
  alter table public.reviews
    alter column confirm set default 0;

  -- report.category : 1=광고, 2=관련없는내용, 3=부적합, 4=기타
  -- confirm         : 0=보류, 1=가짜신고, 2=진짜신고
  ──────────────────────────────────────────────
*/
