import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../widgets/liked_reviews_tab.dart';
import '../widgets/profile_menu.dart';
import '../widgets/recent_visit_tab.dart';

class ProfileScreen extends ConsumerWidget {
  /// 최근 본 식당 탭에서 식당을 탭하면 호출 (지도로 이동 등)
  final ValueChanged<RestaurantModel>? onViewRestaurant;

  const ProfileScreen({super.key, this.onViewRestaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(appAuthProvider);
    final profileAsync = ref.watch(userProfileProvider);

    if (!authState.isLoggedIn) {
      return _NotLoggedIn();
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                email: authState.email ?? '',
                profileAsync: profileAsync,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  labelColor: AppColors.primary500,
                  unselectedLabelColor: AppColors.textHint,
                  indicatorColor: AppColors.primary500,
                  indicatorWeight: 2.5,
                  labelStyle: AppText.subtitle(),
                  tabs: const [
                    Tab(text: '최근 기록'),
                    Tab(text: '하트'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              RecentVisitTab(onTapRestaurant: onViewRestaurant),
              const LikedReviewsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 프로필 헤더 ───────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String email;
  final AsyncValue<UserProfile?> profileAsync;

  const _ProfileHeader({required this.email, required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    final profile = profileAsync.asData?.value;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Row(
        children: [
          Expanded(child: ProfileMenuButton()),
          if (profile != null) ...[
            const SizedBox(width: 12),
            Text(
              '코인 ${profile.coin} · 분석 ${profile.freecount + profile.premiumcount}회',
              style: AppText.caption().copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 비로그인 안내 ─────────────────────────────────────────────
class _NotLoggedIn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('로그인이 필요합니다.', style: AppText.title()),
          const SizedBox(height: 8),
          Text(
            '로그인 후 최근 기록과 하트 리뷰를 확인할 수 있습니다.',
            style: AppText.body().copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── SliverPersistentHeader 용 TabBar 래퍼 ───────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
