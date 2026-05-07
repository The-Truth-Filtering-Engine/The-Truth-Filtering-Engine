import 'package:flutter/material.dart';

import 'app_colors.dart';

// ── 텍스트 스타일 ────────────────────────────
class AppText {
  static const _baseFontFamily = 'Malgun Gothic';
  static const _fontFallbacks = <String>[
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
        fontFamily: _baseFontFamily,
        fontFamilyFallback: _fontFallbacks,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      );

  static TextStyle title() => const TextStyle(
        fontFamily: _baseFontFamily,
        fontFamilyFallback: _fontFallbacks,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      );

  static TextStyle subtitle() => const TextStyle(
        fontFamily: _baseFontFamily,
        fontFamilyFallback: _fontFallbacks,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      );

  static TextStyle body() => const TextStyle(
        fontFamily: _baseFontFamily,
        fontFamilyFallback: _fontFallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
        height: 1.6,
      );

  static TextStyle caption() => const TextStyle(
        fontFamily: _baseFontFamily,
        fontFamilyFallback: _fontFallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle label() => const TextStyle(
        fontFamily: _baseFontFamily,
        fontFamilyFallback: _fontFallbacks,
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: AppColors.searchBarHint,
        letterSpacing: 0.4,
      );
}

// ── 테마 ─────────────────────────────────────
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppText._baseFontFamily,
    fontFamilyFallback: AppText._fontFallbacks,
    textTheme: ThemeData.light().textTheme.apply(
      fontFamily: AppText._baseFontFamily,
      fontFamilyFallback: AppText._fontFallbacks,
    ),
    primaryTextTheme: ThemeData.light().textTheme.apply(
      fontFamily: AppText._baseFontFamily,
      fontFamilyFallback: AppText._fontFallbacks,
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
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
      hintStyle: AppText.body().copyWith(color: AppColors.searchBarHint),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppText.body().copyWith(
          fontWeight: FontWeight.w500, color: Colors.white),
        minimumSize: const Size(double.infinity, 46),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.searchBarHint,
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
