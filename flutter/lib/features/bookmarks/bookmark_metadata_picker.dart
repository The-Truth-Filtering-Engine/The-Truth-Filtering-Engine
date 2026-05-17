import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../map/models/restaurant_model.dart';
import 'bookmark_options.dart';

class BookmarkMetadataSelection {
  final List<String> topicIds;
  final String colorKey;

  const BookmarkMetadataSelection({
    required this.topicIds,
    required this.colorKey,
  });
}

Future<BookmarkMetadataSelection?> showBookmarkMetadataPicker({
  required BuildContext context,
  required RestaurantModel restaurant,
  List<BookmarkTopicOption> customTopics = const [],
  Set<String> hiddenTopicIds = const {},
  String title = '북마크에 저장',
  String actionLabel = '저장',
}) {
  final selectedTopics = restaurant.bookmarkTopicIds.isEmpty
      ? <String>{BookmarkTopics.defaultTopicId}
      : restaurant.bookmarkTopicIds.toSet();
  final topics = BookmarkTopics.all(customTopics, hiddenTopicIds);
  final visibleTopicIds = topics.map((topic) => topic.id).toSet();
  selectedTopics.removeWhere(
    (topicId) =>
        !visibleTopicIds.contains(BookmarkTopics.visibleTopicId(topicId)),
  );
  if (selectedTopics.isEmpty) {
    selectedTopics.add(BookmarkTopics.defaultTopicId);
  }

  return showDialog<BookmarkMetadataSelection>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textHint,
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '북마크',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topics.map((topic) {
                        final selected = selectedTopics.contains(topic.id);
                        final color = BookmarkColors.byKey(topic.colorKey);
                        return FilterChip(
                          label: Text(topic.label),
                          selected: selected,
                          selectedColor: color.background,
                          checkmarkColor: color.foreground,
                          onSelected: (value) {
                            setModalState(() {
                              if (value) {
                                selectedTopics.add(topic.id);
                              } else {
                                selectedTopics.remove(topic.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final topicIds = selectedTopics.isEmpty
                                ? const [BookmarkTopics.defaultTopicId]
                                : selectedTopics.toList();
                            Navigator.pop(
                              context,
                              BookmarkMetadataSelection(
                                topicIds: topicIds,
                                colorKey: BookmarkTopics.colorKeyForTopicIds(
                                  topicIds,
                                  customTopics: customTopics,
                                  fallbackColorKey: restaurant.bookmarkColorKey,
                                ),
                              ),
                            );
                          },
                          child: Text(actionLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
