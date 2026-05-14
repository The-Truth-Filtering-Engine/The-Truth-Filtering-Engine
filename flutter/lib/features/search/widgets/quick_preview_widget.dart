import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/search_preview_models.dart';
import 'issue_chip_row.dart';
import 'preview_card.dart';

class QuickPreviewWidget extends StatelessWidget {
  const QuickPreviewWidget({
    super.key,
    required this.preview,
    required this.isLoading,
    required this.error,
    required this.onIssueTapped,
    required this.onMenuTapped,
    required this.onRestaurantTapped,
    required this.onPreviewCardTapped,
  });

  final SearchPreviewResponse? preview;
  final bool isLoading;
  final String? error;

  final ValueChanged<SearchIssueChip> onIssueTapped;
  final ValueChanged<SearchMenuSuggestion> onMenuTapped;
  final ValueChanged<SearchRestaurantSuggestion> onRestaurantTapped;
  final ValueChanged<SearchQuickPreview> onPreviewCardTapped;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _LoadingState();
    if (error != null) return _ErrorState(message: error!);
    if (preview == null) return const SizedBox.shrink();

    final current = preview!;
    final hasLeft = current.issueChips.isNotEmpty ||
        current.suggestions.menus.isNotEmpty ||
        current.suggestions.restaurants.isNotEmpty;
    final hasRight = current.quickPreviews.isNotEmpty;

    if (!hasLeft && !hasRight) return const _EmptyState();

    final isCompact = MediaQuery.sizeOf(context).width < 520;
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasLeft)
            _LeftPanel(
              preview: current,
              onIssueTapped: onIssueTapped,
              onMenuTapped: onMenuTapped,
              onRestaurantTapped: onRestaurantTapped,
            ),
          if (hasLeft && hasRight)
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (hasRight)
            _RightPanel(
              previews: current.quickPreviews,
              onCardTapped: onPreviewCardTapped,
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasLeft)
          Flexible(
            flex: 4,
            child: _LeftPanel(
              preview: current,
              onIssueTapped: onIssueTapped,
              onMenuTapped: onMenuTapped,
              onRestaurantTapped: onRestaurantTapped,
            ),
          ),
        if (hasLeft && hasRight)
          const SizedBox(
            height: 260,
            child: VerticalDivider(width: 1, color: Color(0xFFEEEEEE)),
          ),
        if (hasRight)
          Flexible(
            flex: 6,
            child: _RightPanel(
              previews: current.quickPreviews,
              onCardTapped: onPreviewCardTapped,
            ),
          ),
      ],
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({
    required this.preview,
    required this.onIssueTapped,
    required this.onMenuTapped,
    required this.onRestaurantTapped,
  });

  final SearchPreviewResponse preview;
  final ValueChanged<SearchIssueChip> onIssueTapped;
  final ValueChanged<SearchMenuSuggestion> onMenuTapped;
  final ValueChanged<SearchRestaurantSuggestion> onRestaurantTapped;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (preview.issueChips.isNotEmpty) ...[
          const SizedBox(height: 8),
          IssueChipRow(
            chips: preview.issueChips,
            onChipTapped: onIssueTapped,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
        ],
        if (preview.suggestions.menus.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.restaurant_menu_rounded,
            label: '메뉴',
          ),
          ...preview.suggestions.menus.map(
            (menu) => _SuggestionTile(
              icon: Icons.restaurant_menu_outlined,
              label: menu.name,
              onTap: () => onMenuTapped(menu),
            ),
          ),
        ],
        if (preview.suggestions.restaurants.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.store_rounded,
            label: '식당',
          ),
          ...preview.suggestions.restaurants.map(
            (restaurant) => _SuggestionTile(
              icon: Icons.location_on_outlined,
              label: restaurant.name,
              onTap: () => onRestaurantTapped(restaurant),
            ),
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

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.previews,
    required this.onCardTapped,
  });

  final List<SearchQuickPreview> previews;
  final ValueChanged<SearchQuickPreview> onCardTapped;

  @override
  Widget build(BuildContext context) {
    final items = previews.take(3).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final preview = items[index];
        return PreviewCard(
          preview: preview,
          onTap: () => onCardTapped(preview),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
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
