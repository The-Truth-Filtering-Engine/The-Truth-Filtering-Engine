import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ─────────────────────────────────────────
/// 공통 텍스트 스타일
/// ─────────────────────────────────────────
class AppText {
  AppText._();

  static const String fontFamily = 'Malgun Gothic';

  static const List<String> fallback = [
    'Apple SD Gothic Neo',
    'Nanum Gothic',
    'Noto Sans KR',
    'Segoe UI',
    'Arial',
    'sans-serif',
  ];

  // Display
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: -0.4,
  );

  // Title
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: -0.3,
  );

  // Subtitle
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Body
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
    height: 1.5,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Label
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  // Marker Score
  static const TextStyle markerScore = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.markerHighText,
  );

  static const TextStyle markerScoreDark = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.markerMidText,
  );

  // Truth Badge
  static const TextStyle truthLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 1.0,
  );

  static const TextStyle truthScore = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
    letterSpacing: -0.5,
  );

  // Button
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

/// ─────────────────────────────────────────
/// 앱 테마
/// ─────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppText.fontFamily,
      fontFamilyFallback: AppText.fallback,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: AppText.title,
        iconTheme: const IconThemeData(
          color: AppColors.textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppText.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppText.body.copyWith(
          color: AppColors.searchBarHint,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
