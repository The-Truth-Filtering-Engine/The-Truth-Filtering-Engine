import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── 브랜드 & 기본 컬러 ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF2B54E8);
  static const Color primaryLight = Color(0xFFEEF0FF);
  static const Color dark = Color(0xFF111827);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);

  // ── 텍스트 ──────────────────────────────────────────────────────────────
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color muted = Color(0xFF64748B);

  // ── 상태 컬러 (성공/경고/위험) ──────────────────────────────────────────────
  static const Color success = Color(0xFF1B7A3A);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFF9A6400);
  static const Color warningBg = Color(0xFFFFF7D6);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerBg = Color(0xFFFFEBEE);

  // ── 지도 & 마커 관련 ────────────────────────────────────────────────────
  static const Color mapTeal = Color(0xFF4BBFBF);
  static const Color markerHigh = Color(0xFF1A1A1A);
  static const Color markerHighText = Color(0xFFFFFFFF);
  static const Color markerMid = Color(0xFFF5C518);
  static const Color markerMidText = Color(0xFF1A1A1A);
  static const Color markerVerified = Color(0xFF0066FF);

  // ── 특정 UI 컴포넌트용 (하위 호환 유지) ───────────────────────────────────────────
  static const Color sheetBackground = Color(0xFFFFFFFF);
  static const Color sheetSubtext = Color(0xFF888888);
  static const Color sheetDivider = Color(0xFFEEEEEE);
  static const Color sheetQuoteBackground = Color(0xFFF7F7F7);
  static const Color searchBarBg = Color(0xFFFFFFFF);
  static const Color searchBarHint = Color(0xFFAAAAAA);
  static const Color searchBarIcon = Color(0xFF888888);
}
