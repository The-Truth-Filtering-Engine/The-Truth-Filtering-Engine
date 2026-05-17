import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────────────────────────────────────
// NaverAuthService
// 네이버 OAuth → Supabase Edge Function → Supabase 세션 교환
// ──────────────────────────────────────────────────────────────────────────────

class NaverAuthService {
  // ▼ 네이버 개발자센터에 등록한 값으로 교체하세요
  static const String _clientId = String.fromEnvironment(
    'NAVER_CLIENT_ID',
    defaultValue: 'MUUADsIYWROs07ZDyToI',
  );

  // 네이버 로그인 후 리다이렉트될 URI
  // 웹: 앱과 동일 도메인의 /naver-callback 경로
  // 앱: 스킴 방식 (현재는 WebView 방식이라 커스텀 URI 불필요)
  static const String _redirectUri =
      'https://trhwelbdnhhpldpkrxmp.supabase.co/functions/v1/naver-auth-callback';

  // Supabase Edge Function URL
  static String get _edgeFunctionUrl =>
      '${SupabaseConfig.url}/functions/v1/naver-auth';

  /// 네이버 OAuth URL 생성 (state는 CSRF 방지용 랜덤 문자열)
  static String buildAuthUrl(String state) {
    final params = {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'state': state,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://nid.naver.com/oauth2.0/authorize?$query';
  }

  static String generateState() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Edge Function을 호출해 Supabase 세션 교환
  static Future<NaverAuthResult> exchangeCodeForSession({
    required String code,
    required String state,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({'code': code, 'state': state}),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200 || body['success'] != true) {
        return NaverAuthResult.failure(
          body['error'] as String? ?? '네이버 로그인에 실패했습니다.',
        );
      }

      final email = body['email'] as String;
      final token = body['token'] as String;

      // Supabase OTP 토큰으로 세션 교환
      final authRes = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.magiclink,
        email: email,
        token: token,
      );

      if (authRes.session == null) {
        return NaverAuthResult.failure('Supabase 세션 생성에 실패했습니다.');
      }

      return NaverAuthResult.success(
        email: email,
        session: authRes.session!,
      );
    } catch (e) {
      debugPrint('[NaverAuth] Error: $e');
      return NaverAuthResult.failure('네이버 로그인 중 오류가 발생했습니다: $e');
    }
  }
}

class NaverAuthResult {
  final bool isSuccess;
  final String? email;
  final Session? session;
  final String? errorMessage;

  const NaverAuthResult._({
    required this.isSuccess,
    this.email,
    this.session,
    this.errorMessage,
  });

  factory NaverAuthResult.success({
    required String email,
    required Session session,
  }) =>
      NaverAuthResult._(isSuccess: true, email: email, session: session);

  factory NaverAuthResult.failure(String message) =>
      NaverAuthResult._(isSuccess: false, errorMessage: message);
}

// ──────────────────────────────────────────────────────────────────────────────
// NaverLoginWebViewScreen
// WebView로 네이버 로그인 페이지를 열고, 리다이렉트 URI에서 code를 캡처합니다.
// ──────────────────────────────────────────────────────────────────────────────

class NaverLoginWebViewScreen extends StatefulWidget {
  const NaverLoginWebViewScreen({super.key});

  /// Navigator.push 후 NaverAuthResult? 반환
  static Future<NaverAuthResult?> show(BuildContext context) {
    return Navigator.of(context).push<NaverAuthResult>(
      MaterialPageRoute(builder: (_) => const NaverLoginWebViewScreen()),
    );
  }

  @override
  State<NaverLoginWebViewScreen> createState() =>
      _NaverLoginWebViewScreenState();
}

class _NaverLoginWebViewScreenState extends State<NaverLoginWebViewScreen> {
  late final WebViewController _controller;
  late final String _state;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _state = NaverAuthService.generateState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: _onNavigationRequest,
          onWebResourceError: (error) {
            debugPrint('[NaverWebView] Resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(NaverAuthService.buildAuthUrl(_state)));
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    final isCallback = request.url.startsWith(
      'https://trhwelbdnhhpldpkrxmp.supabase.co/functions/v1/naver-auth-callback',
    );

    if (isCallback) {
      final code = uri.queryParameters['code'];
      final returnedState = uri.queryParameters['state'];

      if (code != null && returnedState == _state && !_isProcessing) {
        _isProcessing = true;
        _handleCallback(code: code, state: returnedState!);
      }
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _handleCallback({
    required String code,
    required String state,
  }) async {
    setState(() => _isLoading = true);

    final result = await NaverAuthService.exchangeCodeForSession(
      code: code,
      state: state,
    );

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('네이버로 시작하기'),
        backgroundColor: const Color(0xFF03C75A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Stack(
        children: [
          // 웹 전용: kIsWeb이면 WebView 불가 → 안내 메시지
          if (kIsWeb)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '웹 브라우저에서는 네이버 로그인을 지원하지 않습니다.\n앱에서 이용해 주세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF03C75A)),
            ),
        ],
      ),
    );
  }
}
