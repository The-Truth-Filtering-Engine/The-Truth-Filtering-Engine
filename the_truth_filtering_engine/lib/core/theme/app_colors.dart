import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 브랜드 컬러
  static const Color primary = Color(0xFF1A1A1A); // 검정 (주요 마커, 버튼)
  static const Color background = Color(0xFFFFFFFF); // 흰 배경

  // 지도
  static const Color mapTeal = Color(0xFF4BBFBF); // 지도 배경 청록

  // TRUTH 점수 마커
  static const Color markerHigh = Color(0xFF1A1A1A); // 80+ 점수 마커 배경 (검정)
  static const Color markerHighText = Color(0xFFFFFFFF); // 높은 점수 텍스트 (흰)
  static const Color markerMid = Color(0xFFF5C518); // 70~79 점수 마커 배경 (골드)
  static const Color markerMidText = Color(0xFF1A1A1A); // 중간 점수 텍스트 (검정)
  static const Color markerVerified = Color(0xFF0066FF); // 인증 아이콘 색상

  // 바텀시트
  static const Color sheetBackground = Color(0xFFFFFFFF);
  static const Color sheetSubtext = Color(0xFF888888);
  static const Color sheetDivider = Color(0xFFEEEEEE);
  static const Color sheetQuoteBackground = Color(0xFFF7F7F7);

  // 버튼
  static const Color controlButtonBg = Color(0xFFFFFFFF);
  static const Color controlButtonIcon = Color(0xFF444444);

  // TRUTH 뱃지
  static const Color truthBadgeBg = Color(0xFF1A1A1A);
  static const Color truthBadgeText = Color(0xFFFFFFFF);
  static const Color truthBadgeLabel = Color(0xFF888888);

  // 검색바
  static const Color searchBarBg = Color(0xFFFFFFFF);
  static const Color searchBarHint = Color(0xFFAAAAAA);
  static const Color searchBarIcon = Color(0xFF888888);
}
