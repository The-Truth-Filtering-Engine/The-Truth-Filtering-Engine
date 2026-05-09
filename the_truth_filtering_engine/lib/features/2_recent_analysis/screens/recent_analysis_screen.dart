import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../providers/recent_analysis_provider.dart';

class RecentAnalysisScreen extends ConsumerStatefulWidget {
  const RecentAnalysisScreen({
    super.key,
    required this.onViewPlace,
  });

  final ValueChanged<RestaurantModel> onViewPlace;

  @override
  ConsumerState<RecentAnalysisScreen> createState() =>
      _RecentAnalysisScreenState();
}

class _RecentAnalysisScreenState extends ConsumerState<RecentAnalysisScreen> {
  bool get _hasGoogleSession {
    if (!SupabaseConfig.isConfigured) return false;
    return Supabase.instance.client.auth.currentSession != null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentAnalysesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recentAnalysesProvider);

    if (!_hasGoogleSession) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Google 로그인 후 최근분석을 확인할 수 있습니다',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(recentAnalysesProvider.notifier).load(),
      child: state.when(
        loading: () => const _RecentLoadingList(),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _MessageCard(
              icon: Icons.error_outline,
              title: '최근분석을 불러오지 못했습니다',
              message: error.toString(),
              actionLabel: '다시 시도',
              onAction: () => ref.read(recentAnalysesProvider.notifier).load(),
            ),
          ],
        ),
        data: (data) {
          if (data.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: const [
                _MessageCard(
                  icon: Icons.history,
                  title: '아직 분석한 가게가 없습니다',
                  message: '상세보기를 열어 분석한 가게가 여기에 표시됩니다.',
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _RecentSection(
                title: '무료 분석 가능',
                count: data.freeItems.length,
                emptyText: '무료 기간인 가게가 없습니다',
                items: data.freeItems,
                onTap: _openRecentItem,
              ),
              const SizedBox(height: 18),
              _RecentSection(
                title: '지난 검색',
                count: data.expiredItems.length,
                emptyText: '지난 검색 가게가 없습니다',
                items: data.expiredItems,
                onTap: _openRecentItem,
              ),
            ],
          );
        },
      ),
    );
  }

  void _openRecentItem(RecentAnalysisItem item) {
    if (!item.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최근분석 위치 정보를 찾지 못했습니다')),
      );
      return;
    }

    widget.onViewPlace(item.restaurant);
  }
}

class _RecentLoadingList extends StatelessWidget {
  const _RecentLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        _MessageCard(
          icon: Icons.sync,
          title: '최근분석을 불러오는 중입니다',
          message: '무료 분석 기간인 가게를 확인하고 있어요.',
          isLoading: true,
        ),
      ],
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.title,
    required this.count,
    required this.emptyText,
    required this.items,
    required this.onTap,
  });

  final String title;
  final int count;
  final String emptyText;
  final List<RecentAnalysisItem> items;
  final ValueChanged<RecentAnalysisItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              '$count개',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _SectionEmpty(text: emptyText)
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecentTile(
                item: item,
                onTap: () => onTap(item),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.item,
    required this.onTap,
  });

  final RecentAnalysisItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final restaurant = item.restaurant;
    final dateLabel = item.daysElapsed == null
        ? item.analyzedDate
        : item.daysElapsed == 0
            ? '${item.analyzedDate} · 오늘'
            : '${item.analyzedDate} · ${item.daysElapsed}일 전';
    final freeLabel =
        item.remainingFreeDays > 0 ? ' · 무료-${item.remainingFreeDays}일 남음' : '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  restaurant.category.contains('카페')
                      ? Icons.local_cafe_outlined
                      : Icons.restaurant_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${restaurant.category} · ${restaurant.address.isEmpty ? '주소 정보 없음' : restaurant.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateLabel$freeLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                item.hasLocation
                    ? Icons.chevron_right
                    : Icons.location_off_outlined,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (isLoading)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
