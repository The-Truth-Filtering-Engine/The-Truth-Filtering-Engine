import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/providers/current_user_provider.dart';
import '../../core/providers/liked_reviews_provider.dart';
import '../../core/providers/recent_visit_provider.dart';
import '../../core/providers/user_profile_provider.dart';
import '../bookmarks/bookmark_provider.dart';
import '../map/models/restaurant_model.dart';
import '../map/restaurant_detail/blog_review_url.dart';
import '../map/restaurant_detail/providers/review_like_provider.dart';

part 'account_section.dart';
part 'review_menu_section.dart';
part 'settings_flow_bottom_nav.dart';
part 'liked_reviews/liked_reviews_screen.dart';
part 'recent_reviews/recent_reviews_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onSelectTab;

  const SettingsScreen({super.key, this.onSelectTab});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _errorMessage;
  bool _isSaving = false;
  bool _isLoadingLinkedProviders = false;
  bool _isLoginAccountsExpanded = false;
  String? _linkingProvider;
  Set<String> _linkedProviders = const {};

  String? get _accessToken {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  bool get _hasGoogleSession => _accessToken != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasGoogleSession) {
        ref.read(userProfileProvider.notifier).loadIfPossible(force: true);
        _loadLinkedProviders();
      }
    });
  }

  void _updateSettingsState(VoidCallback update) {
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          const Text(
            '계정',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _accountSection(),
        ],
      ),
    );
  }
}

Future<void> _openReviewSource(BuildContext context, String rawUrl) async {
  final uri = mobileBlogReviewUri(rawUrl);
  if (uri == null) {
    _showReviewSourceMessage(context, '연결된 리뷰 원문이 없습니다.');
    return;
  }

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showReviewSourceMessage(context, '리뷰 원문을 열지 못했습니다.');
    }
  } catch (error) {
    debugPrint('Could not launch review source $rawUrl: $error');
    if (!context.mounted) return;
    _showReviewSourceMessage(context, '리뷰 원문을 열지 못했습니다.');
  }
}

Future<void> _recordRecentReviewAndOpen(
  BuildContext context,
  WidgetRef ref, {
  required String reviewId,
  required String name,
  required String reviewUrl,
  required String reviewTitle,
  required String reviewDescription,
}) async {
  try {
    await ref.read(recentVisitProvider.notifier).addReview(
          reviewId: reviewId,
          name: name,
          reviewUrl: reviewUrl,
          reviewTitle: reviewTitle,
          reviewDescription: reviewDescription,
        );
  } catch (error) {
    debugPrint('Recent visit save failed: $error');
    if (!context.mounted) return;
    _showReviewSourceMessage(context, '최근 기록에 저장하지 못했습니다.');
    return;
  }

  if (!context.mounted) return;
  await _openReviewSource(context, reviewUrl);
}

void _showReviewSourceMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
  );
}

class _SettingsListMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _SettingsListMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
