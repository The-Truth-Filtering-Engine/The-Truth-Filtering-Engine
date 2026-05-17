import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/search_preview_models.dart';
import 'preview_card.dart';

class QuickPreviewWidget extends StatefulWidget {
  const QuickPreviewWidget({
    super.key,
    required this.preview,
    required this.isLoading,
    required this.error,
    required this.onRelatedSearchTapped,
    required this.onMenuTapped,
    required this.onRestaurantTapped,
    required this.onPreviewCardTapped,
  });

  final SearchPreviewResponse? preview;
  final bool isLoading;
  final String? error;

  final ValueChanged<String> onRelatedSearchTapped;
  final ValueChanged<SearchMenuSuggestion> onMenuTapped;
  final ValueChanged<SearchRestaurantSuggestion> onRestaurantTapped;
  final ValueChanged<SearchQuickPreview> onPreviewCardTapped;

  @override
  State<QuickPreviewWidget> createState() => _QuickPreviewWidgetState();
}

class _QuickPreviewWidgetState extends State<QuickPreviewWidget> {
  Timer? _loadingDelayTimer;
  bool _showLoadingSkeleton = false;

  static const _loadingSkeletonDelay = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _syncLoadingDelay();
  }

  @override
  void didUpdateWidget(covariant QuickPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _syncLoadingDelay();
    }
  }

  @override
  void dispose() {
    _loadingDelayTimer?.cancel();
    super.dispose();
  }

  void _syncLoadingDelay() {
    _loadingDelayTimer?.cancel();

    if (!widget.isLoading) {
      if (_showLoadingSkeleton) {
        setState(() => _showLoadingSkeleton = false);
      } else {
        _showLoadingSkeleton = false;
      }
      return;
    }

    _showLoadingSkeleton = false;
    _loadingDelayTimer = Timer(_loadingSkeletonDelay, () {
      if (!mounted || !widget.isLoading) return;
      setState(() => _showLoadingSkeleton = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _showLoadingSkeleton
          ? const _LoadingState()
          : const SizedBox.shrink();
    }
    if (widget.error != null) return _ErrorState(message: widget.error!);
    if (widget.preview == null) return const SizedBox.shrink();

    final current = widget.preview!;
    final hasPreviews = current.quickPreviews.isNotEmpty;
    final hasRestaurants = current.suggestions.restaurants.isNotEmpty;

    if (!hasPreviews && !hasRestaurants) {
      return const _EmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RelatedSearchSection(onTapped: widget.onRelatedSearchTapped),
        const SizedBox(height: 18),
        if (hasPreviews) ...[
          const _SectionHeader(
              icon: Icons.restaurant_menu_rounded, label: '메뉴'),
          _PreviewSection(
            previews: current.quickPreviews,
            onCardTapped: widget.onPreviewCardTapped,
          ),
          const SizedBox(height: 18),
        ],
        if (hasRestaurants) ...[
          const _SectionHeader(
            icon: Icons.store_rounded,
            label: '식당',
          ),
          _RestaurantSection(
            restaurants: current.suggestions.restaurants,
            onRestaurantTapped: widget.onRestaurantTapped,
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

const _relatedSearchSuggestions = <String>[
  '웨이팅 적은 곳',
  '조용한 카페',
  '음악 좋은 가게',
  '혼밥하기 좋은 곳',
  '근처 디저트',
  '예약 가능한 곳',
];

class _RelatedSearchSection extends StatelessWidget {
  const _RelatedSearchSection({required this.onTapped});

  final ValueChanged<String> onTapped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          icon: Icons.auto_awesome_outlined,
          label: '연관 검색어',
        ),
        SizedBox(
          height: 38,
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
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _relatedSearchSuggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = _relatedSearchSuggestions[index];
                return _RelatedSearchChip(
                  label: label,
                  onTap: () => onTapped(label),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RelatedSearchChip extends StatelessWidget {
  const _RelatedSearchChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4FBEA),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          constraints: const BoxConstraints(minWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD8F1AA), width: 0.7),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF315F00),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.previews,
    required this.onCardTapped,
  });

  final List<SearchQuickPreview> previews;
  final ValueChanged<SearchQuickPreview> onCardTapped;

  @override
  Widget build(BuildContext context) {
    final items = previews.take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth * 0.38).clamp(144.0, 172.0);

        return SizedBox(
          height: 220,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final preview = items[index];
                return SizedBox(
                  width: cardWidth,
                  child: PreviewCard(
                    preview: preview,
                    onTap: () => onCardTapped(preview),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _RestaurantSection extends StatelessWidget {
  const _RestaurantSection({
    required this.restaurants,
    required this.onRestaurantTapped,
  });

  final List<SearchRestaurantSuggestion> restaurants;
  final ValueChanged<SearchRestaurantSuggestion> onRestaurantTapped;

  @override
  Widget build(BuildContext context) {
    final items = restaurants.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final restaurant = items[index];
        return _RestaurantTile(
          restaurant: restaurant,
          onTap: () => onRestaurantTapped(restaurant),
        );
      },
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({
    required this.restaurant,
    required this.onTap,
  });

  final SearchRestaurantSuggestion restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.only(left: 2, right: 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 17,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: Icons.restaurant_menu_rounded,
          label: '메뉴',
        ),
        _PreviewSkeletonSection(),
        SizedBox(height: 18),
        _SectionHeader(
          icon: Icons.store_rounded,
          label: '식당',
        ),
        _RestaurantSkeletonSection(),
      ],
    );
  }
}

class _PreviewSkeletonSection extends StatelessWidget {
  const _PreviewSkeletonSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth * 0.38).clamp(144.0, 172.0);

        return SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              return SizedBox(
                width: cardWidth,
                child: _PreviewCardSkeleton(
                  titleWidthFactor: index == 0 ? 0.74 : 0.62,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PreviewCardSkeleton extends StatelessWidget {
  const _PreviewCardSkeleton({required this.titleWidthFactor});

  final double titleWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PreviewSkeletonBox(height: 110),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: titleWidthFactor,
                  child: const _PreviewSkeletonBox(height: 15),
                ),
                const SizedBox(height: 8),
                const FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.64,
                  child: _PreviewSkeletonBox(height: 12),
                ),
                const SizedBox(height: 10),
                const _PreviewSkeletonBox(width: 58, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantSkeletonSection extends StatelessWidget {
  const _RestaurantSkeletonSection();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        return _RestaurantSkeletonTile(
          widthFactor: switch (index) {
            0 => 0.72,
            1 => 0.56,
            2 => 0.66,
            _ => 0.48,
          },
        );
      },
    );
  }
}

class _RestaurantSkeletonTile extends StatelessWidget {
  const _RestaurantSkeletonTile({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 2, right: 4),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const _PreviewSkeletonBox(width: 17, height: 17),
          const SizedBox(width: 10),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: const _PreviewSkeletonBox(height: 14),
            ),
          ),
          const _PreviewSkeletonBox(width: 20, height: 20),
        ],
      ),
    );
  }
}

class _PreviewSkeletonBox extends StatelessWidget {
  const _PreviewSkeletonBox({
    this.width,
    required this.height,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Text(
        '검색 결과가 없습니다',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}
