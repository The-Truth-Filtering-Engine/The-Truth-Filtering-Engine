import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // 마커 텍스트
  static const TextStyle markerScore = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.markerHighText,
    letterSpacing: -0.3,
  );

  static const TextStyle markerScoreDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.markerMidText,
    letterSpacing: -0.3,
  );

  // 검색바
  static const TextStyle searchHint = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.searchBarHint,
  );

  // 바텀시트 - 레스토랑 이름
  static const TextStyle restaurantName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: -0.4,
  );

  // 바텀시트 - 주소/카테고리
  static const TextStyle restaurantMeta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.sheetSubtext,
  );

  // 바텀시트 - 리뷰 인용
  static const TextStyle reviewQuote = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.primary,
    height: 1.5,
  );

  // TRUTH 뱃지 - 라벨
  static const TextStyle truthLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: AppColors.truthBadgeLabel,
    letterSpacing: 1.2,
  );

  // TRUTH 뱃지 - 점수
  static const TextStyle truthScore = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.truthBadgeText,
    letterSpacing: -0.5,
  );

  // 버튼 텍스트
  static const TextStyle primaryButton = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.background,
    letterSpacing: -0.2,
  );
}
