import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import 'blog_source_platform.dart';

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
  bool _opened = false;
  late final BlogSourcePlatform _platform;

  @override
  void initState() {
    super.initState();
    _platform = detectBlogSourcePlatform(widget.blogUri);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openExternal());
  }

  Future<void> _openExternal() async {
    if (_opened) return;
    _opened = true;
    await launchUrl(widget.blogUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
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
                '웹에서는 브라우저로 원문을 엽니다.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _platform == BlogSourcePlatform.external
                    ? '모바일 앱에서는 원문을 앱 안 WebView로 볼 수 있습니다.'
                    : _platform == BlogSourcePlatform.google
                        ? '모바일 앱에서도 구글 계열 원문은 브라우저로 엽니다.'
                        : '모바일 앱에서는 ${_platform.label} WebView 로그인 세션을 사용합니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('다시 열기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
