import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── 색상 팔레트 ──────────────────────────────
class AppColors {
  // Primary (Navy)
  static const primary50  = Color(0xFFEEF0FF);
  static const primary200 = Color(0xFF8890E8);
  static const primary500 = Color(0xFF2B54E8);
  static const primary700 = Color(0xFF1A3AB8);
  static const primary900 = Color(0xFF2E2E4E);

  // Success (진성 리뷰)
  static const success50  = Color(0xFFE8F6EE);
  static const success400 = Color(0xFF4CBB87);
  static const success700 = Color(0xFF1A7A4A);

  // Warning (광고 의심)
  static const warning50  = Color(0xFFFEF5E7);
  static const warning400 = Color(0xFFF5A623);
  static const warning700 = Color(0xFFA05800);

  // Danger (광고 확정)
  static const danger50   = Color(0xFFFEF0F0);
  static const danger400  = Color(0xFFE85C5C);
  static const danger700  = Color(0xFFC0392B);

  // Neutral
  static const bg         = Color(0xFFF7F7FA);
  static const surface    = Color(0xFFFFFFFF);
  static const border     = Color(0xFFE4E4EC);
  static const textPrimary   = Color(0xFF2E2E4E);
  static const textSecondary = Color(0xFF6060A0);
  static const textHint      = Color(0xFFA0A0C0);
}

// ── 텍스트 스타일 ────────────────────────────
class AppText {
  static TextStyle display() => GoogleFonts.notoSansKr(
    fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  static TextStyle title() => GoogleFonts.notoSansKr(
    fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  static TextStyle subtitle() => GoogleFonts.notoSansKr(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  static TextStyle body() => GoogleFonts.notoSansKr(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
    height: 1.6);

  static TextStyle caption() => GoogleFonts.notoSansKr(
    fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textSecondary);

  static TextStyle label() => GoogleFonts.notoSansKr(
    fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.textHint,
    letterSpacing: 0.4);
}

// ── 테마 ─────────────────────────────────────
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary500,
      surface: AppColors.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppText.subtitle(),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: AppText.body().copyWith(color: AppColors.textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary500,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppText.body().copyWith(
          fontWeight: FontWeight.w500, color: Colors.white),
        minimumSize: const Size(double.infinity, 46),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary500,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary500,
      unselectedItemColor: AppColors.textHint,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border, thickness: 0.5, space: 0),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
  );
}
