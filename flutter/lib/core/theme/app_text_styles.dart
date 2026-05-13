import 'package:flutter/material.dart';

import '../design_system/app_tokens.dart';

class AppTextStyles {
  AppTextStyles._();

  static final TextStyle markerScore = AppText.subtitle().copyWith(
    fontWeight: FontWeight.w700,
    color: AppColors.markerHighText,
    letterSpacing: -0.3,
  );

  static final TextStyle markerScoreDark = AppText.subtitle().copyWith(
    fontWeight: FontWeight.w700,
    color: AppColors.markerMidText,
    letterSpacing: -0.3,
  );

  static final TextStyle searchHint = AppText.subtitle().copyWith(
    fontWeight: FontWeight.w400,
    color: AppColors.searchBarHint,
  );

  static final TextStyle restaurantName = AppText.title().copyWith(
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: -0.4,
  );

  static final TextStyle restaurantMeta = AppText.body().copyWith(
    color: AppColors.sheetSubtext,
  );

  static final TextStyle reviewQuote = AppText.subtitle().copyWith(
    fontWeight: FontWeight.w400,
    color: AppColors.primary,
    height: 1.5,
  );

  static final TextStyle truthLabel = AppText.label().copyWith(
    color: AppColors.truthBadgeLabel,
    letterSpacing: 1.2,
  );

  static final TextStyle truthScore = AppText.display().copyWith(
    fontWeight: FontWeight.w800,
    color: AppColors.truthBadgeText,
    letterSpacing: -0.5,
  );

  static final TextStyle primaryButton = AppText.subtitle().copyWith(
    fontWeight: FontWeight.w600,
    color: AppColors.background,
    letterSpacing: -0.2,
  );
}
