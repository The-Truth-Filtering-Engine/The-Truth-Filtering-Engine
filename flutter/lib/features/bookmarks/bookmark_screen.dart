import 'dart:async' show unawaited;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../map/models/restaurant_model.dart';
import 'bookmark_edit_dialog.dart';
import 'bookmark_options.dart';
import 'bookmark_provider.dart';

const _allTopicId = 'all';

class BookmarkScreen extends ConsumerStatefulWidget {
  final ValueChanged<RestaurantModel> onViewPlace;
  final bool isActive;

  const BookmarkScreen({
    super.key,
    required this.onViewPlace,
    this.isActive = true,
  });

  @override
  ConsumerState<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends ConsumerState<BookmarkScreen> {
  String _selectedTopicId = _allTopicId;
  final Map<String, RestaurantModel> _pendingRemovalRestaurants = {};

  @override
  void didUpdateWidget(covariant BookmarkScreen oldWidget) {
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
    final bookmarks = ref.watch(bookmarkRestaurantsProvider);
    final customTopics = ref.watch(bookmarkCustomTopicsProvider);
    final hiddenTopicIds = ref.watch(bookmarkHiddenTopicIdsProvider);
    final topics = BookmarkTopics.all(customTopics, hiddenTopicIds);
    final filteredBookmarks = _filterBookmarks(bookmarks);
    final topicCounts = _topicCounts(bookmarks, hiddenTopicIds);

    final itemCount =
        filteredBookmarks.isEmpty ? 2 : filteredBookmarks.length + 1;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _BookmarkHeader(
            selectedTopicId: _selectedTopicId,
            topics: topics,
            totalCount: bookmarks.length,
            topicCounts: topicCounts,
            onTopicSelected: (topicId) {
              setState(() {
                _selectedTopicId = topicId;
              });
            },
            onAddTopic: _showEditTopicDialog,
          );
        }

        if (filteredBookmarks.isEmpty) {
          return _BookmarkEmptyState(hasAnyBookmarks: bookmarks.isNotEmpty);
        }

        final restaurant = filteredBookmarks[index - 1];
        final pendingRemovalKey = _bookmarkRemovalKey(restaurant);
        return _BookmarkTile(
          restaurant: restaurant,
          customTopics: customTopics,
          hiddenTopicIds: hiddenTopicIds,
          isPendingRemoval:
              _pendingRemovalRestaurants.containsKey(pendingRemovalKey),
          onViewPlace: widget.onViewPlace,
          onRemove: () => _togglePendingRemoval(restaurant),
        );
      },
    );
  }

  void _togglePendingRemoval(RestaurantModel restaurant) {
    final key = _bookmarkRemovalKey(restaurant);
    setState(() {
      if (_pendingRemovalRestaurants.containsKey(key)) {
        _pendingRemovalRestaurants.remove(key);
      } else {
        _pendingRemovalRestaurants[key] = restaurant;
      }
    });
  }

  void _flushPendingRemovals() {
    if (_pendingRemovalRestaurants.isEmpty) return;
    final restaurants = List<RestaurantModel>.of(
      _pendingRemovalRestaurants.values,
    );
    _pendingRemovalRestaurants.clear();

    final notifier = ref.read(bookmarkRestaurantsProvider.notifier);
    for (final restaurant in restaurants) {
      unawaited(notifier.remove(restaurant));
    }
  }

  String _bookmarkRemovalKey(RestaurantModel restaurant) {
    return restaurant.effectiveStoreId;
  }

  List<RestaurantModel> _filterBookmarks(List<RestaurantModel> bookmarks) {
    if (_selectedTopicId == _allTopicId) return bookmarks;

    return bookmarks.where((restaurant) {
      final topicIds = _visibleTopicIds(restaurant);
      return topicIds.contains(_selectedTopicId);
    }).toList();
  }

  Map<String, int> _topicCounts(
    List<RestaurantModel> bookmarks,
    Set<String> hiddenTopicIds,
  ) {
    final counts = <String, int>{};
    for (final restaurant in bookmarks) {
      final topicIds = _visibleTopicIds(restaurant)
          .where((topicId) => !hiddenTopicIds.contains(topicId));
      for (final topicId in topicIds.toSet()) {
        counts[topicId] = (counts[topicId] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<String> _visibleTopicIds(RestaurantModel restaurant) {
    final source = restaurant.bookmarkTopicIds.isEmpty
        ? const [BookmarkTopics.defaultTopicId]
        : restaurant.bookmarkTopicIds;
    return source
        .map(BookmarkTopics.visibleTopicId)
        .where((topicId) => topicId.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _showEditTopicDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return BookmarkEditDialog(
          topics: BookmarkTopics.all(
            ref.read(bookmarkCustomTopicsProvider),
            ref.read(bookmarkHiddenTopicIdsProvider),
          ),
          onCreateTopic: (name, colorKey) async {
            final topic = await ref
                .read(bookmarkCustomTopicsProvider.notifier)
                .add(name, colorKey: colorKey);
            if (!mounted) return topic;
            if (topic != null) {
              setState(() {
                _selectedTopicId = topic.id;
              });
            }
            return topic;
          },
          onDeleteTopic: (topic) async {
            await ref
                .read(bookmarkRestaurantsProvider.notifier)
                .removeByTopicId(topic.id);
            if (BookmarkTopics.isDefaultTopic(topic.id)) {
              await ref
                  .read(bookmarkHiddenTopicIdsProvider.notifier)
                  .hide(topic.id);
            } else {
              await ref
                  .read(bookmarkCustomTopicsProvider.notifier)
                  .delete(topic.id);
            }
            if (!mounted) return;
            if (_selectedTopicId == topic.id) {
              setState(() {
                _selectedTopicId = _allTopicId;
              });
            }
          },
        );
      },
    );
  }
}

class _BookmarkHeader extends StatelessWidget {
  final String selectedTopicId;
  final List<BookmarkTopicOption> topics;
  final int totalCount;
  final Map<String, int> topicCounts;
  final ValueChanged<String> onTopicSelected;
  final VoidCallback onAddTopic;

  const _BookmarkHeader({
    required this.selectedTopicId,
    required this.topics,
    required this.totalCount,
    required this.topicCounts,
    required this.onTopicSelected,
    required this.onAddTopic,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '즐겨찾기',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '북마크로 좋아하는 식당을 나눠서 볼 수 있어요.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '북마크',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                primary: false,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: topics.length + 2,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _TopicIndexChip(
                      label: '전체',
                      count: totalCount,
                      selected: selectedTopicId == _allTopicId,
                      onTap: () => onTopicSelected(_allTopicId),
                    );
                  }

                  if (index == topics.length + 1) {
                    return _AddTopicChip(onTap: onAddTopic);
                  }

                  final topic = topics[index - 1];
                  return _TopicIndexChip(
                    label: topic.label,
                    count: topicCounts[topic.id] ?? 0,
                    color: BookmarkColors.byKey(topic.colorKey),
                    selected: selectedTopicId == topic.id,
                    onTap: () => onTopicSelected(topic.id),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicIndexChip extends StatelessWidget {
  final String label;
  final int count;
  final BookmarkColorOption? color;
  final bool selected;
  final VoidCallback onTap;

  const _TopicIndexChip({
    required this.label,
    required this.count,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = color?.foreground ?? AppColors.primary500;
    final idleColor = color == null
        ? AppColors.surface
        : color!.background.withValues(alpha: 0.55);
    final borderColor = color?.border ?? AppColors.border;
    final textColor = color?.foreground ?? AppColors.textSecondary;

    return Material(
      color: selected ? selectedColor : idleColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? selectedColor : borderColor,
            ),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTopicChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTopicChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            '편집',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookmarkEmptyState extends StatelessWidget {
  final bool hasAnyBookmarks;

  const _BookmarkEmptyState({required this.hasAnyBookmarks});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.star_border_rounded,
            size: 40,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 10),
          Text(
            hasAnyBookmarks ? '선택한 주제의 식당이 없습니다' : '아직 즐겨찾기한 가게가 없습니다',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final RestaurantModel restaurant;
  final List<BookmarkTopicOption> customTopics;
  final Set<String> hiddenTopicIds;
  final bool isPendingRemoval;
  final ValueChanged<RestaurantModel> onViewPlace;
  final VoidCallback onRemove;

  const _BookmarkTile({
    required this.restaurant,
    required this.customTopics,
    required this.hiddenTopicIds,
    required this.isPendingRemoval,
    required this.onViewPlace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorKey = BookmarkTopics.colorKeyForTopicIds(
      restaurant.bookmarkTopicIds,
      customTopics: customTopics,
      hiddenTopicIds: hiddenTopicIds,
      fallbackColorKey: restaurant.bookmarkColorKey,
    );
    final color = BookmarkColors.byKey(colorKey);
    final topics = BookmarkTopics.labelsFor(
      restaurant.bookmarkTopicIds,
      customTopics: customTopics,
      hiddenTopicIds: hiddenTopicIds,
    );
    final bookmarkLabel = topics.isEmpty
        ? '즐겨찾기'
        : topics.length == 1
            ? topics.first
            : '${topics.first} +${topics.length - 1}';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onViewPlace(restaurant),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Tooltip(
                message: isPendingRemoval ? '삭제 예정 취소' : '즐겨찾기에서 삭제',
                child: Semantics(
                  button: true,
                  label: isPendingRemoval ? '삭제 예정 취소' : '즐겨찾기에서 삭제',
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isPendingRemoval
                            ? color.background.withValues(alpha: 0.45)
                            : color.foreground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPendingRemoval
                              ? color.border
                              : AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: isPendingRemoval
                            ? color.foreground.withValues(alpha: 0.35)
                            : AppColors.surface,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 96),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.background.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            bookmarkLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: color.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            restaurant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      restaurant.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      restaurant.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
