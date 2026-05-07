import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../models/ai_recommend_item.dart';
import '../providers/ai_recommend_provider.dart';
import '../widgets/recommend_card.dart';

class AiRecommendScreen extends ConsumerWidget {
  final ValueChanged<RestaurantModel> onViewPlace;

  const AiRecommendScreen({
    super.key,
    required this.onViewPlace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiRecommendProvider);
    final notifier = ref.read(aiRecommendProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.errorMessage != null && state.items.isEmpty) {
            return _ErrorState(
              message: 'AI 추천 목록을 불러오지 못했어요.',
              detail: state.errorMessage,
              onRetry: notifier.refresh,
            );
          }

          if (state.items.isEmpty) {
            return _EmptyState(onRefresh: notifier.refresh);
          }

          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              itemCount: state.items.length + 2,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 14)
                  : const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(page: state.page);
                }
                if (index == state.items.length + 1) {
                  return _PaginationControls(
                    page: state.page,
                    hasNext: state.hasNext,
                    isLoading: state.isLoading,
                    onPrevious: notifier.loadPreviousPage,
                    onNext: notifier.loadNextPage,
                  );
                }

                return RecommendCard(
                  item: state.items[index - 1],
                  onViewPlace: (item) => onViewPlace(item.toRestaurantModel()),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int page;

  const _Header({required this.page});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'AI 추천',
                style: AppText.title().copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$page 페이지',
              style: AppText.caption().copyWith(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '가게별로 광고 가능성이 가장 낮게 감지된 리뷰입니다.',
          style: AppText.body().copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int page;
  final bool hasNext;
  final bool isLoading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PaginationControls({
    required this.page,
    required this.hasNext,
    required this.isLoading,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: page <= 1 || isLoading ? null : onPrevious,
            icon: const Icon(Icons.chevron_left),
            label: const Text('이전 10개'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: !hasNext || isLoading ? null : onNext,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            label: const Text('다음 10개'),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          const Icon(
            Icons.auto_awesome_outlined,
            size: 48,
            color: AppColors.muted,
          ),
          const SizedBox(height: 14),
          Text(
            '표시할 추천 데이터가 없어요',
            textAlign: TextAlign.center,
            style: AppText.title(),
          ),
          const SizedBox(height: 8),
          Text(
            'is_ad_finetuned_pred 값이 0.1보다 낮은 리뷰가 생기면 여기에 표시됩니다.',
            textAlign: TextAlign.center,
            style: AppText.body().copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String? detail;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(message, style: AppText.title(), textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                style: AppText.caption().copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
