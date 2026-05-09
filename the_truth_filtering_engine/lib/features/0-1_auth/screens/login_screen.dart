import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/providers/current_user_provider.dart'; // ← 추가
import '../../../main.dart';

// StatefulWidget → ConsumerStatefulWidget 으로 변경
class LoginSignupScreen extends ConsumerStatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  ConsumerState<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends ConsumerState<LoginSignupScreen> {
  static const _mainColor = Color(0xFF1D9E75);
  static const _textColor = Color(0xFF1E2A24);
  static const _mutedColor = Color(0xFF6B7A72);
  static const _borderColor = Color(0xFFDDE7E1);

  StreamSubscription<AuthState>? _authSubscription;
  bool _isGoogleLoading = false;
  bool _hasNavigated = false;

  String get _oauthRedirectTo =>
      kIsWeb ? '${Uri.base.origin}/' : SupabaseConfig.mobileRedirectUrl;

  @override
  void initState() {
    super.initState();

    if (!SupabaseConfig.isConfigured) return;

    final auth = Supabase.instance.client.auth;

    if (auth.currentSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMainShell());
    }

    _authSubscription = auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        // ▼ Google 로그인 완료 → appAuthProvider 에 이메일 저장
        final email = data.session!.user.email ?? '';
        if (email.isNotEmpty) {
          ref.read(appAuthProvider.notifier).setGoogleUser(email);
        }
        _goToMainShell();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (!SupabaseConfig.isConfigured) {
      _showSnackBar(
        'Supabase 설정이 없습니다. SUPABASE_URL과 SUPABASE_ANON_KEY를 확인해 주세요.',
      );
      return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirectTo,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } on AuthException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Google 로그인을 시작하지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _signInAsTemporaryAdmin() {
    // ▼ 임시 로그인 → appAuthProvider 에 'admin' 저장
    ref.read(appAuthProvider.notifier).setTempAdmin();
    _showSnackBar('관리자 임시 로그인 상태입니다.');
    _goToMainShell();
  }

  void _goToMainShell() {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  const SizedBox(height: 28),
                  _googleButton(),
                  const SizedBox(height: 12),
                  _temporaryAdminButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _mainColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.layers_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign in',
                style: TextStyle(
                  color: _mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '로그인이 필요합니다',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isGoogleLoading ? null : _signInWithGoogle,
        icon: _isGoogleLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.g_mobiledata, size: 28),
        label: Text(_isGoogleLoading ? 'Google 로그인 중' : 'Google로 계속하기'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _textColor,
          disabledForegroundColor: _mutedColor,
          side: const BorderSide(color: _borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _temporaryAdminButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: TextButton.icon(
        onPressed: _signInAsTemporaryAdmin,
        icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
        label: const Text('관리자용 임시 로그인'),
        style: TextButton.styleFrom(
          foregroundColor: _mutedColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
