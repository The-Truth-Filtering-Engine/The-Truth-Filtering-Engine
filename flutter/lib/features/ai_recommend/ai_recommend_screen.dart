import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../map/models/map_point.dart';
import '../map/models/restaurant_model.dart';
import '../map/map_provider.dart';
import 'ai_recommend_provider.dart';
import 'recommend_card.dart';

class AiRecommendScreen extends ConsumerWidget {
  final ValueChanged<RestaurantModel> onViewPlace;

  const AiRecommendScreen({
    super.key,
    required this.onViewPlace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentLocationProvider, (previous, next) {
      if (next == null || _sameLocation(previous, next)) return;
      ref.read(aiRecommendProvider.notifier).reloadForCurrentLocation();
    });

    final state = ref.watch(aiRecommendProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final notifier = ref.read(aiRecommendProvider.notifier);

    return Container(
      color: AppColors.bg,
      child: Builder(
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

          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              itemCount: state.items.isEmpty ? 2 : state.items.length + 2,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 14)
                  : const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(
                    state: state,
                    currentLocation: currentLocation,
                    onRegionScopeChanged: notifier.changeRegionScope,
                  );
                }
                if (state.items.isEmpty) {
                  return const _EmptyState();
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
  final AiRecommendState state;
  final MapPoint? currentLocation;
  final ValueChanged<AiRegionScope> onRegionScopeChanged;

  const _Header({
    required this.state,
    required this.currentLocation,
    required this.onRegionScopeChanged,
  });

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
              '${state.page} 페이지',
              style: AppText.caption().copyWith(color: AppColors.textHint),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '가게별로 광고 가능성이 가장 낮게 감지된 리뷰입니다.',
          style: AppText.body().copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        if (state.currentRegionLabel.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 위치',
                  style: AppText.caption().copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 3),
                Text(
                  state.currentRegionLabel,
                  style: AppText.subtitle().copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AiRegionScope.values.map((regionScope) {
              final selected = state.regionScope == regionScope;
              return ChoiceChip(
                label: Text(_regionScopeLabel(regionScope)),
                selected: selected,
                onSelected: state.isLoading
                    ? null
                    : (_) => onRegionScopeChanged(regionScope),
                selectedColor: AppColors.primary50,
                checkmarkColor: AppColors.primary700,
                labelStyle: AppText.caption().copyWith(
                  color:
                      selected ? AppColors.primary700 : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected ? AppColors.primary200 : AppColors.border,
                ),
              );
            }).toList(),
          ),
        ] else
          Text(
            _locationStatusText,
            style: AppText.caption().copyWith(color: AppColors.textHint),
          ),
      ],
    );
  }

  String _regionScopeLabel(AiRegionScope regionScope) {
    final label = switch (regionScope) {
      AiRegionScope.si => state.currentRegionSi,
      AiRegionScope.gu => state.currentRegionGu,
      AiRegionScope.dong => state.currentRegionDong,
    };
    return label.trim().isNotEmpty ? label : regionScope.fallbackLabel;
  }

  String get _locationStatusText {
    if (currentLocation == null) {
      return '현재 위치를 확인하면 지역별 추천이 적용됩니다.';
    }
    if (state.isLoading) {
      return '현재 위치를 확인하는 중입니다.';
    }
    return '현재 위치 지역을 확인하지 못해 전체 추천을 보여줍니다.';
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.sizeOf(context).height * 0.12,
        left: 8,
        right: 8,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 48,
            color: AppColors.textHint,
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
              color: AppColors.danger400,
            ),
            const SizedBox(height: 12),
            Text(message, style: AppText.title(), textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                style: AppText.caption().copyWith(color: AppColors.textHint),
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

bool _sameLocation(MapPoint? a, MapPoint? b) {
  if (a == null || b == null) return a == b;
  return a.latitude == b.latitude && a.longitude == b.longitude;
}
