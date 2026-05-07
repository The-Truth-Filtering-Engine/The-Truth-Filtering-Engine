import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../models/ai_recommend_item.dart';

class RecommendCard extends StatelessWidget {
  final AiRecommendItem item;
  final ValueChanged<AiRecommendItem> onViewPlace;

  const RecommendCard({
    super.key,
    required this.item,
    required this.onViewPlace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name.isEmpty ? '이름 없는 장소' : item.name,
                  style: AppText.title().copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.reviewTitle.isEmpty ? '제목 없는 리뷰' : item.reviewTitle,
            style: AppText.subtitle(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.reviewDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.reviewDescription,
              style: AppText.body().copyWith(color: AppColors.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _metaText,
                  style: AppText.caption().copyWith(color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: item.hasLocation ? () => onViewPlace(item) : null,
                icon: const Icon(Icons.location_on_outlined, size: 16),
                label: const Text('위치 보기'),
              ),
              TextButton.icon(
                onPressed: item.reviewUrl.isEmpty
                    ? null
                    : () => _openReview(context, item.reviewUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('리뷰 열기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _metaText {
    final parts = [
      if (item.bloggerName.isNotEmpty) item.bloggerName,
      if (item.postDate.isNotEmpty) item.postDate,
    ];
    return parts.isEmpty ? '블로그 리뷰' : parts.join(' · ');
  }

  Future<void> _openReview(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack(context, '리뷰 URL 형식이 올바르지 않아요.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showSnack(context, '리뷰 페이지를 열 수 없어요.');
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
