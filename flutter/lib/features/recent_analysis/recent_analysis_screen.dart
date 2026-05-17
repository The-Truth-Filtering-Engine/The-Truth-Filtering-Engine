import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../map/models/restaurant_model.dart';
import 'recent_analysis_provider.dart';

const int _recentAnalysisRetentionDays = 14;

class RecentAnalysisScreen extends ConsumerStatefulWidget {
  const RecentAnalysisScreen({
    super.key,
    required this.onViewPlace,
    this.isActive = true,
  });

  final ValueChanged<RestaurantModel> onViewPlace;
  final bool isActive;

  @override
  ConsumerState<RecentAnalysisScreen> createState() =>
      _RecentAnalysisScreenState();
}

class _RecentAnalysisScreenState extends ConsumerState<RecentAnalysisScreen> {
  final Map<String, RecentAnalysisItem> _pendingRemovalItems = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentAnalysesProvider.notifier).load();
    });
  }

  @override
  void didUpdateWidget(covariant RecentAnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _flushPendingRemovals();
    }
  }

  @override
  void dispose() {
    _flushPendingRemovals();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recentAnalysesProvider);

    final content = state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('최근분석을 불러오지 못했습니다'),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.read(recentAnalysesProvider.notifier).load(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final items = [...data.freeItems, ...data.expiredItems];
        final sections = _recentAnalysisDateSections(items);

        if (items.isEmpty) {
          return const Center(
            child: Text('저장된 최근 분석이 없습니다.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            final section = sections[index];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    index == 0 ? 4 : 14,
                    16,
                    6,
                  ),
                  child: Text(
                    section.label,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (var itemIndex = 0;
                    itemIndex < section.items.length;
                    itemIndex++) ...[
                  _RecentAnalysisTile(
                    item: section.items[itemIndex],
                    dDayLabel:
                        _recentAnalysisDdayLabel(section.items[itemIndex]),
                    isPendingRemoval: _pendingRemovalItems.containsKey(
                      section.items[itemIndex].storeId,
                    ),
                    onTap: () => _openRecentItem(section.items[itemIndex]),
                    onDelete: () =>
                        _togglePendingRemoval(section.items[itemIndex]),
                  ),
                  if (itemIndex != section.items.length - 1)
                    const Divider(height: 1, indent: 72),
                ],
              ],
            );
          },
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RecentAnalysisHeader(),
        Expanded(child: content),
      ],
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

  void _togglePendingRemoval(RecentAnalysisItem item) {
    setState(() {
      if (_pendingRemovalItems.containsKey(item.storeId)) {
        _pendingRemovalItems.remove(item.storeId);
      } else {
        _pendingRemovalItems[item.storeId] = item;
      }
    });
  }

  void _flushPendingRemovals() {
    if (_pendingRemovalItems.isEmpty) return;
    final items = List<RecentAnalysisItem>.of(_pendingRemovalItems.values);
    _pendingRemovalItems.clear();

    final notifier = ref.read(recentAnalysesProvider.notifier);
    for (final item in items) {
      unawaited(notifier.remove(item));
    }
  }
}

class _RecentAnalysisHeader extends StatelessWidget {
  const _RecentAnalysisHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 분석',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '최근 확인한 음식점 분석을 다시 볼 수 있어요. 기록은 14일 후 자동으로 사라집니다.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAnalysisDateSection {
  _RecentAnalysisDateSection({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;
  final String label;
  final List<RecentAnalysisItem> items;
}

List<_RecentAnalysisDateSection> _recentAnalysisDateSections(
  List<RecentAnalysisItem> items,
) {
  final sortedItems = [...items]..sort((a, b) {
      final dateComparison = _recentAnalysisDateSortValue(b)
          .compareTo(_recentAnalysisDateSortValue(a));
      if (dateComparison != 0) return dateComparison;
      return a.restaurant.name.compareTo(b.restaurant.name);
    });

  final sections = <_RecentAnalysisDateSection>[];
  for (final item in sortedItems) {
    final key = _recentAnalysisDateKey(item);
    if (sections.isNotEmpty && sections.last.key == key) {
      sections.last.items.add(item);
      continue;
    }

    sections.add(
      _RecentAnalysisDateSection(
        key: key,
        label: _recentAnalysisDateSectionLabel(item),
        items: [item],
      ),
    );
  }

  return sections;
}

String _recentAnalysisSubtitle(RecentAnalysisItem item) {
  final restaurant = item.restaurant;
  final address = restaurant.address.isEmpty ? '주소 정보 없음' : restaurant.address;
  return '${restaurant.category} · $address';
}

String _recentAnalysisDateSectionLabel(RecentAnalysisItem item) {
  if (item.daysElapsed == 0) return '오늘';
  if (item.daysElapsed == 1) return '어제';

  final date = _recentAnalysisDate(item);
  if (date != null) {
    return '${date.year}.${_twoDigits(date.month)}.${_twoDigits(date.day)}';
  }

  return item.analyzedDate.isEmpty ? '날짜 없음' : item.analyzedDate;
}

String _recentAnalysisDateKey(RecentAnalysisItem item) {
  final date = _recentAnalysisDate(item);
  if (date != null) {
    return '${date.year}${_twoDigits(date.month)}${_twoDigits(date.day)}';
  }
  return item.analyzedDate;
}

int _recentAnalysisDateSortValue(RecentAnalysisItem item) {
  final date = _recentAnalysisDate(item);
  if (date != null) {
    return date.year * 10000 + date.month * 100 + date.day;
  }
  return int.tryParse(item.analyzedDate) ?? 0;
}

DateTime? _recentAnalysisDate(RecentAnalysisItem item) {
  final value = item.analyzedDate.trim();
  if (RegExp(r'^\d{8}$').hasMatch(value)) {
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    final day = int.tryParse(value.substring(6, 8));
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

int? _recentAnalysisDaysLeft(RecentAnalysisItem item) {
  final daysElapsed = item.daysElapsed;
  if (daysElapsed != null) {
    return (_recentAnalysisRetentionDays - daysElapsed).clamp(
      0,
      _recentAnalysisRetentionDays,
    );
  }

  if (item.remainingFreeDays > 0) return item.remainingFreeDays;
  return item.remainingFreeDays == 0 ? 0 : null;
}

String? _recentAnalysisDdayLabel(RecentAnalysisItem item) {
  final daysLeft = _recentAnalysisDaysLeft(item);
  if (daysLeft == null) return null;
  if (daysLeft <= 0) return 'D-day';
  return 'D-$daysLeft';
}

class _RecentAnalysisTile extends StatelessWidget {
  final RecentAnalysisItem item;
  final String? dDayLabel;
  final bool isPendingRemoval;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentAnalysisTile({
    required this.item,
    required this.dDayLabel,
    required this.isPendingRemoval,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final restaurant = item.restaurant;
    final showDday = dDayLabel != null;
    final calendarColor = isPendingRemoval
        ? Colors.grey.withValues(alpha: 0.35)
        : showDday
            ? Colors.grey
            : AppColors.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: isPendingRemoval ? '삭제 예정 취소' : '최근 분석 삭제',
                    child: IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.calendar_month_rounded),
                      color: calendarColor,
                    ),
                  ),
                  if (showDday)
                    Text(
                      dDayLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ).copyWith(color: calendarColor),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _recentAnalysisSubtitle(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              item.hasLocation
                  ? Icons.chevron_right
                  : Icons.location_off_outlined,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
