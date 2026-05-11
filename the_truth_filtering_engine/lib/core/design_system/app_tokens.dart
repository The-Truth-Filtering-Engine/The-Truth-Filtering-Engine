import 'package:flutter/material.dart';

enum DsButtonVariant { primary, secondary, ghost, danger }

enum DsButtonSize { sm, md, lg }

enum DsTone { real, suspicious, ad, info, success, warning, error }

class DsColors {
  DsColors._();

  static const white = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF8FAFC);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral400 = Color(0xFF94A3B8);
  static const neutral500 = Color(0xFF64748B);
  static const neutral600 = Color(0xFF475569);
  static const neutral950 = Color(0xFF111827);

  static const brand50 = Color(0xFFEEF0FF);
  static const brand100 = Color(0xFFC5C7F0);
  static const brand300 = Color(0xFF8890E8);
  static const brand500 = Color(0xFF2B54E8);
  static const brand600 = Color(0xFF2563EB);
  static const brand700 = Color(0xFF1A3AB8);
  static const brand900 = Color(0xFF2E2E4E);

  static const logoSurface = Color(0xFFF8F4E7);
  static const logoInk = Color(0xFF56503C);

  static const success50 = Color(0xFFE8F6EE);
  static const success400 = Color(0xFF4CBB87);
  static const success700 = Color(0xFF1A7A4A);

  static const warning50 = Color(0xFFFEF5E7);
  static const warning400 = Color(0xFFF5A623);
  static const warning700 = Color(0xFFA05800);

  static const danger50 = Color(0xFFFEF0F0);
  static const danger400 = Color(0xFFE85C5C);
  static const danger700 = Color(0xFFC0392B);

  static const info50 = Color(0xFFEAF2FF);
  static const info700 = Color(0xFF1D4ED8);

  static const bgDefault = white;
  static const bgSubtle = neutral50;
  static const bgMuted = neutral100;
  static const surface = white;
  static const surfaceInverse = neutral950;
  static const textPrimary = neutral950;
  static const textSecondary = neutral500;
  static const textMuted = neutral400;
  static const textSubtle = neutral600;
  static const textBrand = brand600;
  static const textInverse = white;
  static const textDanger = Color(0xFF991B1B);
  static const borderSubtle = Color(0x141E293B);
  static const borderDefault = Color(0x1F1E293B);
  static const borderStrong = neutral200;
}

class AppColors {
  AppColors._();

  static const primary50 = DsColors.brand50;
  static const primary200 = DsColors.brand300;
  static const primary500 = DsColors.brand500;
  static const primary700 = DsColors.brand700;
  static const primary900 = DsColors.brand900;

  static const success50 = DsColors.success50;
  static const success400 = DsColors.success400;
  static const success700 = DsColors.success700;

  static const warning50 = DsColors.warning50;
  static const warning400 = DsColors.warning400;
  static const warning700 = DsColors.warning700;

  static const danger50 = DsColors.danger50;
  static const danger400 = DsColors.danger400;
  static const danger700 = DsColors.danger700;

  static const bg = DsColors.bgSubtle;
  static const surface = DsColors.surface;
  static const border = Color(0xFFE4E4EC);
  static const textPrimary = DsColors.brand900;
  static const textSecondary = Color(0xFF6060A0);
  static const textHint = Color(0xFFA0A0C0);

  static const primary = DsColors.surfaceInverse;
  static const background = DsColors.bgDefault;
  static const mapTeal = Color(0xFF4BBFBF);

  static const markerHigh = DsColors.surfaceInverse;
  static const markerHighText = DsColors.textInverse;
  static const markerMid = Color(0xFFF5C518);
  static const markerMidText = DsColors.surfaceInverse;
  static const markerVerified = DsColors.brand600;

  static const sheetBackground = DsColors.surface;
  static const sheetSubtext = Color(0xFF888888);
  static const sheetDivider = Color(0xFFEEEEEE);
  static const sheetQuoteBackground = Color(0xFFF7F7F7);

  static const controlButtonBg = DsColors.surface;
  static const controlButtonIcon = Color(0xFF444444);

  static const truthBadgeBg = DsColors.surfaceInverse;
  static const truthBadgeText = DsColors.textInverse;
  static const truthBadgeLabel = Color(0xFF888888);

  static const searchBarBg = DsColors.surface;
  static const searchBarHint = Color(0xFFAAAAAA);
  static const searchBarIcon = Color(0xFF888888);
}

class AppSpacing {
  AppSpacing._();

  static const double zero = 0;
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x7 = 28;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
}

class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 18;
  static const double sheet = 20;
}

class AppShadows {
  AppShadows._();

  static const sm = <BoxShadow>[
    BoxShadow(
      color: Color(0x141E293B),
      blurRadius: 16,
      offset: Offset(0, 5),
    ),
  ];

  static const md = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A0F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const sheet = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, -4),
    ),
  ];
}

class AppText {
  AppText._();

  static const baseFontFamily = 'Malgun Gothic';
  static const fontFallbacks = <String>[
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    'Apple SD 산돌고딕 Neo',
    'Nanum Gothic',
    'Segoe UI',
    'Noto Sans KR',
    'Arial',
    'Helvetica',
    'sans-serif',
  ];

  static TextStyle display() => const TextStyle(
        fontFamily: baseFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle title() => const TextStyle(
        fontFamily: baseFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.25,
      );

  static TextStyle subtitle() => const TextStyle(
        fontFamily: baseFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.35,
      );

  static TextStyle body() => const TextStyle(
        fontFamily: baseFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.6,
      );

  static TextStyle caption() => const TextStyle(
        fontFamily: baseFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      );

  static TextStyle label() => const TextStyle(
        fontFamily: baseFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textHint,
        letterSpacing: 0.6,
        height: 1.2,
      );
}

Color dsToneBackground(DsTone tone) {
  return switch (tone) {
    DsTone.real || DsTone.success => DsColors.success50,
    DsTone.suspicious || DsTone.warning => DsColors.warning50,
    DsTone.ad || DsTone.error => DsColors.danger50,
    DsTone.info => DsColors.info50,
  };
}

Color dsToneForeground(DsTone tone) {
  return switch (tone) {
    DsTone.real || DsTone.success => DsColors.success700,
    DsTone.suspicious || DsTone.warning => DsColors.warning700,
    DsTone.ad || DsTone.error => DsColors.danger700,
    DsTone.info => DsColors.info700,
  };
}

Color dsToneAccent(DsTone tone) {
  return switch (tone) {
    DsTone.real || DsTone.success => DsColors.success400,
    DsTone.suspicious || DsTone.warning => DsColors.warning400,
    DsTone.ad || DsTone.error => DsColors.danger400,
    DsTone.info => DsColors.brand600,
  };
}
