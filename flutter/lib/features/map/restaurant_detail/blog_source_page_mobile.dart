import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import 'blog_source_platform.dart';
import 'google_source_session.dart';
import 'kakao_webview_session.dart';
import 'naver_webview_session.dart';

class BlogSourcePage extends StatefulWidget {
  final Uri blogUri;
  final String title;

  const BlogSourcePage({
    super.key,
    required this.blogUri,
    this.title = '원문 보기',
  });

  @override
  State<BlogSourcePage> createState() => _BlogSourcePageState();
}

class _BlogSourcePageState extends State<BlogSourcePage> {
  late final WebViewController _controller;
  late final BlogSourcePlatform _platform;
  bool _isLoading = true;
  bool _isLoginPage = false;

  @override
  void initState() {
    super.initState();
    _platform = detectBlogSourcePlatform(widget.blogUri);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _syncUrlState(url);
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            await _syncUrlState(url);
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            debugPrint('Blog WebView error: ${error.description}');
          },
        ),
      );

    _loadInitialUrl();
  }

  Future<void> _loadInitialUrl() async {
    if (_platform == BlogSourcePlatform.google) {
      await _openGoogleSourceExternally();
      return;
    }

    final sessionReady = await _isSessionReady();
    final uri = sessionReady ? widget.blogUri : _loginUri();

    await _controller.loadRequest(uri);
  }

  Future<void> _syncUrlState(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    final isLoginPage = _isPlatformLoginUri(uri);
    if (mounted && _isLoginPage != isLoginPage) {
      setState(() => _isLoginPage = isLoginPage);
    }

    if (_isPlatformSourceUri(uri) && !isLoginPage) {
      await _markSessionReady();
    }
  }

  Future<void> _openLoginAgain() async {
    if (_platform == BlogSourcePlatform.google) {
      await _openGoogleSourceExternally();
      return;
    }

    await _clearSession();
    await _controller.loadRequest(_loginUri());
  }

  Future<bool> _isSessionReady() {
    return switch (_platform) {
      BlogSourcePlatform.naver => NaverWebViewSession.isReady(),
      BlogSourcePlatform.kakao => KakaoWebViewSession.isReady(),
      BlogSourcePlatform.google => GoogleSourceSession.isReady(),
      BlogSourcePlatform.external => Future.value(true),
    };
  }

  Uri _loginUri() {
    return switch (_platform) {
      BlogSourcePlatform.naver =>
        NaverWebViewSession.loginUri(redirectUri: widget.blogUri),
      BlogSourcePlatform.kakao =>
        KakaoWebViewSession.loginUri(redirectUri: widget.blogUri),
      BlogSourcePlatform.google => widget.blogUri,
      BlogSourcePlatform.external => widget.blogUri,
    };
  }

  bool _isPlatformLoginUri(Uri uri) {
    return switch (_platform) {
      BlogSourcePlatform.naver => NaverWebViewSession.isLoginUri(uri),
      BlogSourcePlatform.kakao => KakaoWebViewSession.isLoginUri(uri),
      BlogSourcePlatform.google => false,
      BlogSourcePlatform.external => false,
    };
  }

  bool _isPlatformSourceUri(Uri uri) {
    return switch (_platform) {
      BlogSourcePlatform.naver => NaverWebViewSession.isNaverSourceUri(uri),
      BlogSourcePlatform.kakao => KakaoWebViewSession.isKakaoSourceUri(uri),
      BlogSourcePlatform.google => GoogleSourceSession.isGoogleSourceUri(uri),
      BlogSourcePlatform.external => true,
    };
  }

  Future<void> _markSessionReady() {
    return switch (_platform) {
      BlogSourcePlatform.naver => NaverWebViewSession.markReady(),
      BlogSourcePlatform.kakao => KakaoWebViewSession.markReady(),
      BlogSourcePlatform.google => GoogleSourceSession.markReady(),
      BlogSourcePlatform.external => Future.value(),
    };
  }

  Future<void> _clearSession() {
    return switch (_platform) {
      BlogSourcePlatform.naver => NaverWebViewSession.clear(),
      BlogSourcePlatform.kakao => KakaoWebViewSession.clear(),
      BlogSourcePlatform.google => GoogleSourceSession.clear(),
      BlogSourcePlatform.external => Future.value(),
    };
  }

  Future<void> _openGoogleSourceExternally() async {
    await GoogleSourceSession.markReady();
    await launchUrl(widget.blogUri, mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_platform == BlogSourcePlatform.external
            ? widget.title
            : _platform.label),
        actions: [
          if (_platform != BlogSourcePlatform.external)
            IconButton(
              tooltip: _platform == BlogSourcePlatform.google
                  ? '${_platform.label} 브라우저로 열기'
                  : '${_platform.label} 로그인',
              icon: Icon(_platform == BlogSourcePlatform.google
                  ? Icons.open_in_new_rounded
                  : Icons.login_rounded),
              onPressed: _openLoginAgain,
            ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _controller.reload,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_platform != BlogSourcePlatform.google)
            WebViewWidget(controller: _controller),
          if (_platform == BlogSourcePlatform.google)
            _ExternalGoogleSourceNotice(
              onOpenExternal: _openGoogleSourceExternally,
            ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_isLoginPage)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _LoginNotice(
                platformLabel: _platform.label,
                onLoginAgain: _openLoginAgain,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExternalGoogleSourceNotice extends StatelessWidget {
  final VoidCallback onOpenExternal;

  const _ExternalGoogleSourceNotice({required this.onOpenExternal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              size: 42,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 14),
            const Text(
              '구글 계열 원문은 브라우저로 엽니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'YouTube, Blogger, Google Maps 로그인은 WebView에서 제한될 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onOpenExternal,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('브라우저로 열기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginNotice extends StatelessWidget {
  final String platformLabel;
  final VoidCallback onLoginAgain;

  const _LoginNotice({
    required this.platformLabel,
    required this.onLoginAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$platformLabel 로그인 후 원문을 볼 수 있어요.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: onLoginAgain,
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
