import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/design_system/app_tokens.dart';
import '../../core/design_system/widgets/widgets.dart';
import '../../core/providers/current_user_provider.dart';
import '../../main.dart';

class StartAuthScreen extends ConsumerStatefulWidget {
  const StartAuthScreen({super.key});

  @override
  ConsumerState<StartAuthScreen> createState() => _StartAuthScreenState();
}

class _StartAuthScreenState extends ConsumerState<StartAuthScreen> {
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

    DsToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SizedBox(
                width: double.infinity,
                child: DsCard(
                  padding: const EdgeInsets.all(AppSpacing.x7),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _header(),
                      const SizedBox(height: AppSpacing.x7),
                      _googleButton(),
                      const SizedBox(height: AppSpacing.x3),
                      _temporaryAdminButton(),
                    ],
                  ),
                ),
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
        const DsAppLogo(showTitle: false, size: 48),
        const SizedBox(width: AppSpacing.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign in',
                style: AppText.label(),
              ),
              const SizedBox(height: 3),
              Text(
                '로그인이 필요합니다',
                style: AppText.display().copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _googleButton() {
    return DsButton(
      label: _isGoogleLoading ? 'Google 로그인 중' : 'Google로 계속하기',
      variant: DsButtonVariant.secondary,
      size: DsButtonSize.lg,
      loading: _isGoogleLoading,
      onPressed: _isGoogleLoading ? null : _signInWithGoogle,
      leftIcon: const Icon(Icons.g_mobiledata, size: 28),
    );
  }

  Widget _temporaryAdminButton() {
    return DsButton(
      label: '관리자용 임시 로그인',
      variant: DsButtonVariant.ghost,
      size: DsButtonSize.md,
      onPressed: _signInAsTemporaryAdmin,
      leftIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
    );
  }
}
