import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/design_system/app_tokens.dart';
import '../../core/design_system/widgets/widgets.dart';
import '../../core/providers/current_user_provider.dart';
import '../../core/services/naver_auth_service.dart';
import '../../main.dart';
import 'oauth_redirect.dart';

class StartAuthScreen extends ConsumerStatefulWidget {
  const StartAuthScreen({super.key});

  @override
  ConsumerState<StartAuthScreen> createState() => _StartAuthScreenState();
}

class _StartAuthScreenState extends ConsumerState<StartAuthScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  String? _loadingProvider;
  bool _hasNavigated = false;

  String get _oauthRedirectTo =>
      kIsWeb ? '${Uri.base.origin}/' : SupabaseConfig.mobileRedirectUrl;

  @override
  void initState() {
    super.initState();

    if (!SupabaseConfig.isConfigured) return;

    final auth = Supabase.instance.client.auth;

    try {
      if (auth.currentSession != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _goToMainShell());
      }
    } on AuthException catch (_) {
      unawaited(auth.signOut());
    }

    _authSubscription = auth.onAuthStateChange.listen(
      (data) {
        if (data.session != null) {
          final email = data.session!.user.email ?? '';
          if (email.isNotEmpty) {
            ref.read(appAuthProvider.notifier).setOAuthUser(email);
          }
          _goToMainShell();
        }
      },
      onError: (_) {
        unawaited(auth.signOut());
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signInWithOAuth({
    required OAuthProvider provider,
    required String providerKey,
    required String providerLabel,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      _showSnackBar(
        'Supabase 설정이 없습니다. SUPABASE_URL과 SUPABASE_ANON_KEY를 확인해 주세요.',
      );
      return;
    }

    setState(() => _loadingProvider = providerKey);

    try {
      if (kIsWeb) {
        final response = await Supabase.instance.client.auth.getOAuthSignInUrl(
          provider: provider,
          redirectTo: _oauthRedirectTo,
        );
        redirectToOAuthUrl(response.url);
        return;
      }

      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: _oauthRedirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar('$providerLabel 로그인 화면을 열지 못했습니다.');
      }
    } on AuthException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('$providerLabel 로그인을 시작하지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() => _loadingProvider = null);
      }
    }
  }

  Future<void> _signInWithKakao() {
    return _signInWithOAuth(
      provider: OAuthProvider.kakao,
      providerKey: 'kakao',
      providerLabel: '카카오',
    );
  }

  Future<void> _signInWithNaver() async {
    if (kIsWeb) {
      _showSnackBar('웹에서는 네이버 로그인을 지원하지 않습니다. 앱을 이용해 주세요.');
      return;
    }

    setState(() => _loadingProvider = 'naver');

    try {
      final result = await NaverLoginWebViewScreen.show(context);

      if (!mounted) return;

      if (result == null) {
        // 사용자가 WebView를 닫음 (취소)
        return;
      }

      if (!result.isSuccess) {
        _showSnackBar(result.errorMessage ?? '네이버 로그인에 실패했습니다.');
        return;
      }

      // 성공: 세션 저장 및 메인 화면 이동
      final email = result.email ?? '';
      if (email.isNotEmpty) {
        ref.read(appAuthProvider.notifier).setOAuthUser(email);
      }
      _goToMainShell();
    } catch (e) {
      if (mounted) _showSnackBar('네이버 로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _signInWithGoogle() {
    return _signInWithOAuth(
      provider: OAuthProvider.google,
      providerKey: 'google',
      providerLabel: 'Google',
    );
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
                child: PointerInterceptor(
                  child: DsCard(
                    padding: const EdgeInsets.all(AppSpacing.x7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(),
                        const SizedBox(height: AppSpacing.x7),
                        _kakaoButton(),
                        const SizedBox(height: AppSpacing.x3),
                        _naverButton(),
                        const SizedBox(height: AppSpacing.x3),
                        _googleButton(),
                        const SizedBox(height: AppSpacing.x5),
                        _temporaryAdminButton(),
                      ],
                    ),
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

  Widget _kakaoButton() {
    return _SocialLoginButton(
      label: _loadingProvider == 'kakao' ? '카카오 로그인 중' : '카카오로 시작하기',
      backgroundColor: const Color(0xFFFEE500),
      foregroundColor: const Color(0xFF191919),
      borderColor: const Color(0xFFF1D900),
      loading: _loadingProvider == 'kakao',
      enabled: _loadingProvider == null,
      onPressed: _signInWithKakao,
      mark: 'K',
    );
  }

  Widget _naverButton() {
    return _SocialLoginButton(
      label: _loadingProvider == 'naver' ? '네이버 로그인 중' : '네이버로 시작하기',
      backgroundColor: const Color(0xFF03C75A),
      foregroundColor: Colors.white,
      borderColor: const Color(0xFF03B351),
      loading: _loadingProvider == 'naver',
      enabled: _loadingProvider == null,
      onPressed: _signInWithNaver,
      mark: 'N',
    );
  }

  Widget _googleButton() {
    return _SocialLoginButton(
      label: _loadingProvider == 'google' ? 'Google 로그인 중' : 'Google로 시작하기',
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      borderColor: AppColors.border,
      loading: _loadingProvider == 'google',
      enabled: _loadingProvider == null,
      onPressed: _signInWithGoogle,
      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
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

class _SocialLoginButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;
  final String? mark;
  final Widget? icon;

  const _SocialLoginButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.loading,
    required this.enabled,
    required this.onPressed,
    this.mark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color:
            active ? backgroundColor : backgroundColor.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: active ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foregroundColor,
                            ),
                          )
                        : icon ??
                            Text(
                              mark ?? '',
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.body().copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
