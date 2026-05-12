import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/providers/analysis_mode_provider.dart';
import '../../../core/providers/liked_reviews_provider.dart';
import '../../../core/providers/recent_visit_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../../1-3_restaurant_detail/providers/review_like_provider.dart';
import '../../1-3_restaurant_detail/utils/blog_review_url.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onSelectTab;

  const SettingsScreen({super.key, this.onSelectTab});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _errorMessage;
  bool _isSaving = false;

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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(analysisModeProvider);
    final color = Theme.of(context).colorScheme.primary;

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
          const SizedBox(height: 12),
          _logoutButton(),
          const SizedBox(height: 24),
          const Text(
            '리뷰',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _ReviewButtonsSection(onSelectTab: widget.onSelectTab),
        ],
      ),
    );
  }

  Widget _accountSection() {
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.asData?.value;
    final profileError =
        profileState.hasError ? profileState.error.toString() : null;

    if (!_hasGoogleSession) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.admin_panel_settings_outlined),
                title: Text('임시 관리자 로그인'),
                subtitle: Text('Google 로그인 사용자가 아니어서 결제 설정은 비활성화됩니다.'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  OutlinedButton(
                    onPressed: null,
                    child: Text('프리미엄 설정'),
                  ),
                  OutlinedButton(
                    onPressed: null,
                    child: Text('1,000 코인 충전'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (profileState.isLoading && profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (profileError != null && profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                profileError,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: profileState.isLoading ? null : _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (profile == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Google 로그인 정보를 확인할 수 없습니다'),
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(profile.email),
                subtitle: Text(profile.isPremium ? '프리미엄 사용자' : '일반 사용자'),
              ),
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _statTile('Coin', profile.coin.toString()),
                    _statTile('Free', profile.freecount.toString()),
                    _statTile('Premium', profile.premiumcount.toString()),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '프리미엄',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '현재 계정의 premium 값을 ${profile.isPremium ? 0 : 1}로 저장합니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _togglePremium,
                  icon: Icon(
                    profile.isPremium
                        ? Icons.workspace_premium
                        : Icons.workspace_premium_outlined,
                  ),
                  label: Text(profile.isPremium ? '프리미엄 해제' : '프리미엄 설정'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '코인 충전',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '테스트용 충전 버튼입니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1000, 2000, 3000]
                      .map(
                        (amount) => OutlinedButton.icon(
                          onPressed:
                              _isSaving ? null : () => _chargeCoins(amount),
                          icon: const Icon(Icons.monetization_on_outlined),
                          label: Text(amount.toString()),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return OutlinedButton.icon(
      onPressed: _logout,
      icon: const Icon(Icons.logout),
      label: const Text('로그아웃'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        minimumSize: const Size.fromHeight(46),
      ),
    );
  }

  Future<void> _loadProfile() async {
    setState(() {
      _errorMessage = null;
    });
    await ref.read(userProfileProvider.notifier).loadIfPossible(force: true);
  }

  Future<void> _togglePremium() async {
    final profile = ref.read(userProfileProvider).asData?.value;
    if (!_hasGoogleSession || profile == null) return;

    await _mutateProfile(
      () =>
          ref.read(userProfileProvider.notifier).setPremium(!profile.isPremium),
      profile.isPremium ? '프리미엄이 해제되었습니다' : '프리미엄이 설정되었습니다',
    );
  }

  Future<void> _chargeCoins(int amount) async {
    if (!_hasGoogleSession) return;

    await _mutateProfile(
      () => ref.read(userProfileProvider.notifier).chargeCoins(amount),
      '$amount 코인이 충전되었습니다',
    );
  }

  Future<void> _mutateProfile(
    Future<UserProfile> Function() request,
    String successMessage,
  ) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await request();
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _logout() async {
    try {
      if (SupabaseConfig.isConfigured &&
          Supabase.instance.client.auth.currentSession != null) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃하지 못했습니다')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }
}

class _ReviewButtonsSection extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;

  const _ReviewButtonsSection({this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ReviewNavigationButton(
            icon: Icons.favorite_border,
            iconColor: Color(0xFFE85C5C),
            title: '내 하트',
            subtitle: '하트를 누른 리뷰 목록',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _LikedReviewsSettingsScreen(
                    onSelectTab: onSelectTab,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 0),
          _ReviewNavigationButton(
            icon: Icons.history,
            title: '최근 기록',
            subtitle: '최근 확인한 리뷰 목록',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _RecentReviewsSettingsScreen(
                    onSelectTab: onSelectTab,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewNavigationButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReviewNavigationButton({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _LikedReviewsSettingsScreen extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;

  const _LikedReviewsSettingsScreen({this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 하트')),
      bottomNavigationBar: _SettingsFlowBottomNavigationBar(
        onTap: (index) => _selectMainTab(context, onSelectTab, index),
      ),
      body: const _LikedReviewsSettingsList(),
    );
  }
}

class _RecentReviewsSettingsScreen extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;

  const _RecentReviewsSettingsScreen({this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('최근 기록')),
      bottomNavigationBar: _SettingsFlowBottomNavigationBar(
        onTap: (index) => _selectMainTab(context, onSelectTab, index),
      ),
      body: const _RecentReviewsSettingsList(),
    );
  }
}

void _selectMainTab(
  BuildContext context,
  ValueChanged<int>? onSelectTab,
  int index,
) {
  onSelectTab?.call(index);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class _SettingsFlowBottomNavigationBar extends StatelessWidget {
  final ValueChanged<int> onTap;

  const _SettingsFlowBottomNavigationBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 4,
        onTap: onTap,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: '탐색',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border_rounded),
            activeIcon: Icon(Icons.bookmark_rounded),
            label: '북마크',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_toggle_off_rounded),
            label: '최근 분석',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome_rounded),
            label: 'AI 추천',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
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

class _LikedReviewsSettingsList extends ConsumerWidget {
  const _LikedReviewsSettingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedReviews = ref.watch(likedReviewsProvider);

    return likedReviews.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _SettingsListMessage(
        icon: Icons.error_outline,
        message: '내 하트 목록을 불러오지 못했습니다.',
        action: TextButton.icon(
          onPressed: () => ref.read(likedReviewsProvider.notifier).load(),
          icon: const Icon(Icons.refresh),
          label: const Text('다시 시도'),
        ),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const _SettingsListMessage(
            icon: Icons.favorite_border,
            message: '하트를 누른 리뷰가 없습니다.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final review = reviews[index];

            return _LikedReviewSettingsTile(
              review: review,
              onTap: () => _recordRecentReviewAndOpen(
                context,
                ref,
                reviewId: review.id,
                name: review.restaurantName,
                reviewUrl: review.reviewUrl,
                reviewTitle: review.title,
                reviewDescription: review.description,
              ),
              onRemove: () async {
                final userId = ref.read(currentUserIdProvider);
                try {
                  await ref.read(likedReviewsProvider.notifier).remove(
                        review.id,
                      );
                  ref.invalidate(reviewLikeProvider);
                  if (userId != null) {
                    ref
                        .read(
                          reviewLikeProvider(
                            ReviewLikeProviderKey(
                              reviewId: review.id,
                              userId: userId,
                            ),
                          ).notifier,
                        )
                        .markUnliked();
                  }
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('내 하트를 해제하지 못했습니다.')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _LikedReviewSettingsTile extends StatelessWidget {
  final LikedReview review;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _LikedReviewSettingsTile({
    required this.review,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: IconButton(
        tooltip: '내 하트 해제',
        icon: const Icon(Icons.favorite, color: Color(0xFFE85C5C)),
        onPressed: onRemove,
      ),
      title: Text(
        review.title.isEmpty ? '제목 없는 리뷰' : review.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.restaurantName.isNotEmpty)
            Text(
              review.restaurantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (review.description.isNotEmpty)
            Text(
              review.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _RecentReviewsSettingsList extends ConsumerWidget {
  const _RecentReviewsSettingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentRestaurants = ref.watch(recentVisitProvider);

    if (recentRestaurants.isEmpty) {
      return const _SettingsListMessage(
        icon: Icons.history,
        message: '최근 기록이 없습니다.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: recentRestaurants.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final restaurant = recentRestaurants[index];

        return _RecentReviewSettingsTile(
          restaurant: restaurant,
          onTap: () => _openReviewSource(context, restaurant.reviewUrl ?? ''),
          onRemove: () => ref
              .read(recentVisitProvider.notifier)
              .remove(restaurant.effectiveReviewId),
        );
      },
    );
  }
}

class _RecentReviewSettingsTile extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _RecentReviewSettingsTile({
    required this.restaurant,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      restaurant.category,
      restaurant.address,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    final textTheme = Theme.of(context).textTheme;
    final title = restaurant.reviewTitle?.trim() ?? '';
    final description = restaurant.reviewDescription?.trim().isNotEmpty == true
        ? restaurant.reviewDescription!.trim()
        : restaurant.reviewSummary.trim().isNotEmpty
            ? restaurant.reviewSummary.trim()
            : subtitle;

    return ListTile(
      leading: IconButton(
        tooltip: '최근 기록 삭제',
        icon: Icon(
          Icons.close_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: onRemove,
      ),
      title: Text(
        title.isEmpty ? '제목 없는 리뷰' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (restaurant.name.isNotEmpty)
            Text(
              restaurant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (description.isNotEmpty)
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
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
