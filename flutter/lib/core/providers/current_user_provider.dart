import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
// AppAuthState — 소셜 OAuth + 관리자 임시 로그인 통합 관리
//
//  소셜 로그인      → email = OAuth 계정 이메일
//  관리자 임시 로그인 → email = 'admin', isAdmin = true
//  미로그인         → email = null
// ─────────────────────────────────────────────────────────────

class AppAuthState {
  final String? email;
  final bool isAdmin;

  const AppAuthState({this.email, this.isAdmin = false});

  bool get isLoggedIn => email != null;
}

class AppAuthNotifier extends StateNotifier<AppAuthState> {
  AppAuthNotifier() : super(const AppAuthState()) {
    // 앱 시작 시 Supabase 세션이 이미 있으면 복원
    final email = _currentEmail();
    if (email != null && email.isNotEmpty) {
      state = AppAuthState(email: email);
    }
  }

  /// 소셜 OAuth 로그인 완료 → start_auth_screen.dart 의 onAuthStateChange 에서 호출
  void setOAuthUser(String email) {
    state = AppAuthState(email: email);
  }

  /// 기존 호출부 호환용
  void setGoogleUser(String email) {
    setOAuthUser(email);
  }

  /// 관리자 임시 로그인 → start_auth_screen.dart 의 _signInAsTemporaryAdmin 에서 호출
  void setTempAdmin() {
    state = const AppAuthState(email: 'admin', isAdmin: true);
  }

  /// 로그아웃
  void signOut() {
    state = const AppAuthState();
  }

  String? _currentEmail() {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }
}

final appAuthProvider = StateNotifierProvider<AppAuthNotifier, AppAuthState>(
  (ref) => AppAuthNotifier(),
);

/// 이메일만 필요할 때 사용
/// ```dart
/// final email = ref.watch(currentUserEmailProvider);
/// ```
final currentUserEmailProvider = Provider<String?>((ref) {
  return ref.watch(appAuthProvider).email;
});
