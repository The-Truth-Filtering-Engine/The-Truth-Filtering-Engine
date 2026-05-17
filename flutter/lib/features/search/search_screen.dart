import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/widgets/widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../models/search_history_models.dart';
import '../../models/search_preview_models.dart';
import '../../screens/restaurant_list_screen.dart';
import '../map/models/restaurant_model.dart';
import '../map/restaurant_detail/restaurant_detail_screen.dart';
import 'search_controller.dart';
import 'widgets/quick_preview_widget.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    double? initialLat,
    double? initialLng,
    double? initialLatitude,
    double? initialLongitude,
    ValueChanged<RestaurantModel>? onRestaurantSelected,
    ValueChanged<RestaurantModel>? onViewPlace,
    this.onSelectTab,
  })  : initialLatitude = initialLatitude ?? initialLat,
        initialLongitude = initialLongitude ?? initialLng,
        onViewPlace = onViewPlace ?? onRestaurantSelected,
        assert(
          onViewPlace != null || onRestaurantSelected != null,
          'SearchScreen needs a restaurant selection callback.',
        );

  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<RestaurantModel>? onViewPlace;
  final ValueChanged<int>? onSelectTab;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _selectedTrendingLabel;

  static const _minimumSubmitLength = 2;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus &&
          ref.read(searchControllerProvider).query.trim().isEmpty) {
        ref.read(searchControllerProvider.notifier).onFocus();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      ref.read(searchControllerProvider.notifier).onFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final submittedQuery = state.query.trim();

    if (state.inputState == SearchInputState.submitted &&
        submittedQuery.length >= _minimumSubmitLength) {
      return _SubmittedBody(
        query: submittedQuery,
        initialLatitude: widget.initialLatitude,
        initialLongitude: widget.initialLongitude,
        onRestaurantSelected: widget.onViewPlace!,
        onTrendingRankSelected: _saveTrendingRankHistory,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: GestureDetector(
          onTap: () => _selectMainTab(0),
          child: const DsAppLogo(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _SearchBar(
              controller: _textController,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              onSubmitted: _submitSearch,
              onClear: _clearQuery,
              onBack: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
      bottomNavigationBar: _SearchBottomNavigationBar(
        currentIndex: 0,
        onTap: _selectMainTab,
      ),
    );
  }

  void _selectMainTab(int index) {
    widget.onSelectTab?.call(index);
    Navigator.of(context).maybePop();
  }

  Widget _buildBody(SearchState state) {
    switch (state.inputState) {
      case SearchInputState.beforeInput:
        return _BeforeInputBody(
          trendingChips: state.trendingChips,
          selectedTrendingLabel: _selectedTrendingLabel,
          recentQueries: _recentQueries(state),
          isLoadingHistory: state.isLoadingHistory,
          onTrendingTapped: _selectTrendingCategory,
          onTrendingRankTapped: _openTrendingRestaurant,
          onRecentTapped: _applyRecentQuery,
          onDeleteRecent:
              ref.read(searchControllerProvider.notifier).deleteHistoryItem,
          onClearRecent: state.recentHistory.isEmpty
              ? null
              : ref.read(searchControllerProvider.notifier).deleteAllHistory,
        );

      case SearchInputState.typing:
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: QuickPreviewWidget(
            preview: state.preview,
            isLoading: state.isLoadingPreview,
            error: state.previewError,
            onRelatedSearchTapped: _selectRelatedSearch,
            onMenuTapped: _selectMenu,
            onRestaurantTapped: _selectRestaurant,
            onPreviewCardTapped: _selectPreviewCard,
          ),
        );

      case SearchInputState.submitted:
        return _SubmittedBody(
          query: state.query.trim(),
          initialLatitude: widget.initialLatitude,
          initialLongitude: widget.initialLongitude,
          onRestaurantSelected: widget.onViewPlace!,
          onTrendingRankSelected: _saveTrendingRankHistory,
        );
    }
  }

  List<_RecentChipData> _recentQueries(SearchState state) {
    if (state.recentHistory.isNotEmpty) {
      final seen = <String>{};
      return state.recentHistory
          .where((item) => item.query.trim().isNotEmpty)
          .where((item) => seen.add(item.query.trim()))
          .take(10)
          .map(
            (item) => _RecentChipData(
              id: item.id,
              label: item.query.trim(),
              isFallback: false,
            ),
          )
          .toList();
    }

    return const [];
  }

  void _onQueryChanged(String query) {
    ref.read(searchControllerProvider.notifier).onQueryChanged(
          query,
          lat: widget.initialLatitude,
          lng: widget.initialLongitude,
        );
  }

  void _applyQuery(String query) {
    final trimmed = query.trim();
    _textController.text = trimmed;
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    _onQueryChanged(trimmed);
    _focusNode.requestFocus();
  }

  void _selectTrendingCategory(SearchTrendingChip chip) {
    _submitSearch(_trendingSearchQuery(chip.label), saveToRecent: false);
  }

  String _trendingSearchQuery(String label) {
    if (label.contains('지금 뜨는')) return '지금 뜨는 맛집';
    if (label.contains('많이 찾는')) return '많이 찾는 맛집';
    if (label.contains('신상')) return '신상 맛집';
    if (label.contains('추억')) return '추억의 맛집';
    return label
        .replaceAll(RegExp(r'[^0-9A-Za-z가-힣\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _openTrendingRestaurant(_TrendingRankItem item) {
    final restaurant = _restaurantForTrendingRankItem(
      item,
      initialLatitude: widget.initialLatitude,
      initialLongitude: widget.initialLongitude,
    );
    _saveTrendingRankHistory(item, restaurant);
    widget.onViewPlace?.call(restaurant);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  void _applyRecentQuery(String query) {
    _applyQuery(query);
  }

  void _clearQuery() {
    _textController.clear();
    _onQueryChanged('');
    _focusNode.requestFocus();
  }

  void _submitSearch(String query, {bool saveToRecent = true}) {
    final trimmed = query.trim();
    if (trimmed.length < _minimumSubmitLength) return;

    _textController.text = trimmed;
    _textController.selection = TextSelection.collapsed(offset: trimmed.length);

    final controller = ref.read(searchControllerProvider.notifier);
    controller.onQueryChanged(
      trimmed,
      lat: widget.initialLatitude,
      lng: widget.initialLongitude,
    );
    controller.onSubmit();
    if (saveToRecent) {
      unawaited(
        controller.onResultSelected(
          SearchRecentHistoryRequest(
            query: trimmed,
            clickedType: SearchClickType.restaurant,
            clickedLabel: trimmed,
          ),
        ),
      );
    }
    _focusNode.unfocus();
  }

  void _selectRelatedSearch(String query) {
    _submitSearch(query, saveToRecent: false);
  }

  Future<void> _selectMenu(SearchMenuSuggestion menu) async {
    _focusNode.unfocus();
    await ref.read(searchControllerProvider.notifier).onResultSelected(
          SearchRecentHistoryRequest(
            query: stateQuery,
            clickedType: SearchClickType.menu,
            clickedId: menu.id,
            clickedLabel: menu.name,
            menuId: menu.id,
          ),
        );
    _submitSearch(menu.name, saveToRecent: false);
  }

  Future<void> _selectRestaurant(
    SearchRestaurantSuggestion restaurant,
  ) async {
    _focusNode.unfocus();
    await ref.read(searchControllerProvider.notifier).onResultSelected(
          SearchRecentHistoryRequest(
            query: stateQuery,
            clickedType: SearchClickType.restaurant,
            clickedId: restaurant.id,
            clickedLabel: restaurant.name,
            restaurantId: restaurant.id,
          ),
        );
    _submitSearch(restaurant.name, saveToRecent: false);
  }

  Future<void> _selectPreviewCard(SearchQuickPreview preview) async {
    _focusNode.unfocus();
    final query = preview.menuName?.trim().isNotEmpty == true
        ? preview.menuName!
        : preview.restaurantName;
    await ref.read(searchControllerProvider.notifier).onResultSelected(
          SearchRecentHistoryRequest(
            query: stateQuery,
            clickedType: SearchClickType.quickPreview,
            clickedId: preview.restaurantId,
            clickedLabel: preview.menuName ?? preview.restaurantName,
            restaurantId: preview.restaurantId,
            menuId: preview.menuId,
          ),
        );
    _submitSearch(query, saveToRecent: false);
  }

  void _saveTrendingRankHistory(
    _TrendingRankItem item,
    RestaurantModel restaurant,
  ) {
    final title = item.title.trim();
    if (title.length < _minimumSubmitLength) return;

    unawaited(
      ref.read(searchControllerProvider.notifier).onResultSelected(
            SearchRecentHistoryRequest(
              query: title,
              clickedType: SearchClickType.restaurant,
              clickedId: restaurant.id,
              clickedLabel: title,
              restaurantId: restaurant.id,
            ),
          ),
    );
  }

  String get stateQuery {
    final query = ref.read(searchControllerProvider).query.trim();
    return query.isEmpty ? _textController.text.trim() : query;
  }
}

class _SearchBottomNavigationBar extends StatelessWidget {
  const _SearchBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: onTap,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: '탐색',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border_rounded),
            activeIcon: Icon(Icons.star_rounded),
            label: '즐겨찾기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_toggle_off_rounded),
            label: '최근 분석',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'AI 추천',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          cursorColor: AppColors.primary500,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '음식점 또는 메뉴를 검색',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: AppColors.textHint,
            ),
            prefixIcon: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.textSecondary,
              onPressed: onBack,
              padding: EdgeInsets.zero,
              tooltip: '뒤로',
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  tooltip: '지우기',
                );
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _BeforeInputBody extends StatelessWidget {
  const _BeforeInputBody({
    required this.trendingChips,
    required this.selectedTrendingLabel,
    required this.recentQueries,
    required this.isLoadingHistory,
    required this.onTrendingTapped,
    required this.onTrendingRankTapped,
    required this.onRecentTapped,
    required this.onDeleteRecent,
    required this.onClearRecent,
  });

  final List<SearchTrendingChip> trendingChips;
  final String? selectedTrendingLabel;
  final List<_RecentChipData> recentQueries;
  final bool isLoadingHistory;
  final ValueChanged<SearchTrendingChip> onTrendingTapped;
  final ValueChanged<_TrendingRankItem> onTrendingRankTapped;
  final ValueChanged<String> onRecentTapped;
  final ValueChanged<String> onDeleteRecent;
  final VoidCallback? onClearRecent;

  @override
  Widget build(BuildContext context) {
    final selectedChip = _selectedTrendingChip;
    final rankings = _rankingsForTrendingLabel(selectedChip?.label);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        _TrendingChipRow(
          chips: trendingChips,
          selectedLabel: selectedChip?.label,
          onTapped: onTrendingTapped,
        ),
        if (rankings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TrendingRankCarousel(
            key: ValueKey(selectedChip?.label ?? 'trending-ranks'),
            rankings: rankings,
            onRankTapped: onTrendingRankTapped,
          ),
        ],
        const SizedBox(height: 24),
        _SectionTitle(
          icon: Icons.history_rounded,
          title: '최근 검색어',
          actionLabel: onClearRecent == null ? null : '전체 삭제',
          onActionTap: onClearRecent,
        ),
        const SizedBox(height: 10),
        if (isLoadingHistory)
          const _RecentSearchSkeletonList()
        else
          _RecentSearchList(
            recentQueries: recentQueries,
            onRecentTapped: onRecentTapped,
            onDeleteRecent: onDeleteRecent,
          ),
      ],
    );
  }

  SearchTrendingChip? get _selectedTrendingChip {
    if (trendingChips.isEmpty) return null;
    final selectedLabel = selectedTrendingLabel;
    if (selectedLabel == null || selectedLabel.isEmpty) {
      return trendingChips.first;
    }
    for (final chip in trendingChips) {
      if (chip.label == selectedLabel) return chip;
    }
    return trendingChips.first;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentSearchSkeletonList extends StatelessWidget {
  const _RecentSearchSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _RecentSearchSkeletonTile(widthFactor: 0.64),
        _RecentSearchSkeletonTile(widthFactor: 0.48),
        _RecentSearchSkeletonTile(widthFactor: 0.58),
      ],
    );
  }
}

class _RecentSearchSkeletonTile extends StatelessWidget {
  const _RecentSearchSkeletonTile({required this.widthFactor});

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
          const _SearchSkeletonBox(width: 17, height: 17),
          const SizedBox(width: 10),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: const _SearchSkeletonBox(height: 13),
            ),
          ),
          const _SearchSkeletonBox(width: 17, height: 17),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SearchSkeletonBox extends StatelessWidget {
  const _SearchSkeletonBox({
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
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _TrendingChipRow extends StatelessWidget {
  const _TrendingChipRow({
    required this.chips,
    required this.selectedLabel,
    required this.onTapped,
  });

  static const _nostalgiaStyle = _TrendingChipStyle(
    background: Color(0xFFF4FBEA),
    border: Color(0xFFD8F1AA),
    foreground: Color(0xFF315F00),
    selectedBackground: Color(0xFFE4F5C8),
    selectedBorder: Color(0xFF9DCE58),
    selectedForeground: Color(0xFF254D00),
  );

  final List<SearchTrendingChip> chips;
  final String? selectedLabel;
  final ValueChanged<SearchTrendingChip> onTapped;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    final visibleChips = chips.take(4).toList();

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          for (var index = 0; index < visibleChips.length; index++) ...[
            Expanded(
              child: _KeywordChip(
                label: visibleChips[index].label,
                style: _nostalgiaStyle,
                selected: visibleChips[index].label == selectedLabel,
                onTap: () => onTapped(visibleChips[index]),
              ),
            ),
            if (index < visibleChips.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _TrendingChipStyle {
  const _TrendingChipStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.selectedBackground,
    required this.selectedBorder,
    required this.selectedForeground,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color selectedBackground;
  final Color selectedBorder;
  final Color selectedForeground;
}

class _RecentSearchList extends StatelessWidget {
  const _RecentSearchList({
    required this.recentQueries,
    required this.onRecentTapped,
    required this.onDeleteRecent,
  });

  final List<_RecentChipData> recentQueries;
  final ValueChanged<String> onRecentTapped;
  final ValueChanged<String> onDeleteRecent;

  @override
  Widget build(BuildContext context) {
    if (recentQueries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '최근 검색어가 없습니다',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textHint,
          ),
        ),
      );
    }

    return Column(
      children: recentQueries
          .map(
            (recent) => _RecentSearchTile(
              label: recent.label,
              onTap: () => onRecentTapped(recent.label),
              onDeleted:
                  recent.isFallback ? null : () => onDeleteRecent(recent.id),
            ),
          )
          .toList(),
    );
  }
}

class _TrendingRankCarousel extends StatefulWidget {
  const _TrendingRankCarousel({
    super.key,
    required this.rankings,
    required this.onRankTapped,
  });

  final List<_TrendingRankItem> rankings;
  final ValueChanged<_TrendingRankItem> onRankTapped;

  @override
  State<_TrendingRankCarousel> createState() => _TrendingRankCarouselState();
}

class _TrendingRankCarouselState extends State<_TrendingRankCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _page = _middlePage(widget.rankings.length);
    _controller = PageController(
      initialPage: _page,
      viewportFraction: 0.44,
    );
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _TrendingRankCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rankings != widget.rankings) {
      _page = _middlePage(widget.rankings.length);
      if (_controller.hasClients) {
        _controller.jumpToPage(_page);
      }
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.rankings.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_controller.hasClients) return;
      final nextPage = _page + 1;
      _page = nextPage;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  int _middlePage(int itemCount) {
    return itemCount <= 1 ? 0 : itemCount;
  }

  void _handlePageChanged(int index) {
    _page = index;

    final itemCount = widget.rankings.length;
    if (itemCount <= 1) return;

    if (index == 0 || index == itemCount * 2) {
      final normalizedPage = itemCount + (index % itemCount);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _page = normalizedPage;
        _controller.jumpToPage(normalizedPage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rankings.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
          },
        ),
        child: PageView.builder(
          controller: _controller,
          padEnds: false,
          physics: const PageScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          onPageChanged: _handlePageChanged,
          itemBuilder: (context, index) {
            final item = widget.rankings[index % widget.rankings.length];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TrendingRankCard(
                item: item,
                onTap: () => widget.onRankTapped(item),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrendingRankCard extends StatelessWidget {
  const _TrendingRankCard({
    required this.item,
    required this.onTap,
  });

  final _TrendingRankItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 20,
                constraints: const BoxConstraints(minWidth: 26),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7EC),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${item.rank}위',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5F8E2F),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF8DAF54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final _TrendingChipStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? style.selectedBackground : style.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? style.selectedBorder : style.border,
              width: selected ? 1.4 : 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 0.95,
              ).copyWith(
                color: selected ? style.selectedForeground : style.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  const _RecentSearchTile({
    required this.label,
    required this.onTap,
    this.onDeleted,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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
                Icons.history_rounded,
                size: 17,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: AppColors.textHint,
                ),
                onPressed: onDeleted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                tooltip: '삭제',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmittedBody extends StatelessWidget {
  const _SubmittedBody({
    required this.query,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onRestaurantSelected,
    required this.onTrendingRankSelected,
  });

  final String query;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<RestaurantModel> onRestaurantSelected;
  final void Function(_TrendingRankItem item, RestaurantModel restaurant)
      onTrendingRankSelected;

  @override
  Widget build(BuildContext context) {
    final rankings = _rankingsForSubmittedQuery(query);
    if (rankings.isNotEmpty) {
      return _TrendingSubmittedResultsBody(
        query: query,
        rankings: rankings,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        onRestaurantSelected: onRestaurantSelected,
        onTrendingRankSelected: onTrendingRankSelected,
      );
    }

    return RestaurantListScreen(
      query: query,
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      onViewPlace: onRestaurantSelected,
    );
  }
}

class _TrendingSubmittedResultsBody extends StatefulWidget {
  const _TrendingSubmittedResultsBody({
    required this.query,
    required this.rankings,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onRestaurantSelected,
    required this.onTrendingRankSelected,
  });

  final String query;
  final List<_TrendingRankItem> rankings;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<RestaurantModel> onRestaurantSelected;
  final void Function(_TrendingRankItem item, RestaurantModel restaurant)
      onTrendingRankSelected;

  @override
  State<_TrendingSubmittedResultsBody> createState() =>
      _TrendingSubmittedResultsBodyState();
}

class _TrendingSubmittedResultsBodyState
    extends State<_TrendingSubmittedResultsBody> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _TrendingSubmittedResultsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        _queryController.text != widget.query) {
      _queryController.text = widget.query;
      _queryController.selection = TextSelection.collapsed(
        offset: _queryController.text.length,
      );
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _TrendingSubmittedSearchField(
          controller: _queryController,
          onSubmitted: _submitSearch,
          onSearchTap: () => _submitSearch(_queryController.text),
          onClear: () {
            _queryController.clear();
          },
        ),
        titleSpacing: 0,
        actions: const [
          SizedBox(width: 12),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(thickness: 0.5, height: 0.5, color: AppColors.border),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        itemCount: widget.rankings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 5),
        itemBuilder: (context, index) {
          final item = widget.rankings[index];
          return _TrendingSubmittedRankTile(
            item: item,
            onTap: () => _openRestaurant(context, item),
          );
        },
      ),
    );
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _SubmittedBody(
          query: trimmed,
          initialLatitude: widget.initialLatitude,
          initialLongitude: widget.initialLongitude,
          onRestaurantSelected: widget.onRestaurantSelected,
          onTrendingRankSelected: widget.onTrendingRankSelected,
        ),
      ),
    );
  }

  void _openRestaurant(BuildContext context, _TrendingRankItem item) {
    final restaurant = _restaurantForTrendingRankItem(
      item,
      initialLatitude: widget.initialLatitude,
      initialLongitude: widget.initialLongitude,
    );
    widget.onTrendingRankSelected(item, restaurant);
    widget.onRestaurantSelected(restaurant);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }
}

class _TrendingSubmittedSearchField extends StatelessWidget {
  const _TrendingSubmittedSearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onSearchTap,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: AppColors.textHint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '음식점 또는 메뉴를 검색',
                hintStyle: TextStyle(color: AppColors.textHint),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox(width: 2);
              return IconButton(
                icon: const Icon(
                  Icons.cancel_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: '지우기',
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              size: 16,
              color: AppColors.primary500,
            ),
            onPressed: onSearchTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: '검색',
          ),
        ],
      ),
    );
  }
}

class _TrendingSubmittedRankTile extends StatelessWidget {
  const _TrendingSubmittedRankTile({
    required this.item,
    required this.onTap,
  });

  final _TrendingRankItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTopThree = item.rank <= 3;
    final badgeColor =
        isTopThree ? const Color(0xFFFFF4E6) : const Color(0xFFF4F7EC);
    final badgeTextColor =
        isTopThree ? const Color(0xFFB45C00) : const Color(0xFF5F8E2F);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 24,
                constraints: const BoxConstraints(minWidth: 36),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${item.rank}위',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: badgeTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _InlineMetaPill(label: item.category),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _RecommendedMenuStrip(item: item),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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

class _InlineMetaPill extends StatelessWidget {
  const _InlineMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBEA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8F1AA), width: 0.7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF315F00),
        ),
      ),
    );
  }
}

class _RecommendedMenuStrip extends StatelessWidget {
  const _RecommendedMenuStrip({required this.item});

  final _TrendingRankItem item;

  @override
  Widget build(BuildContext context) {
    final menus = item.recommendedMenus;

    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chipWidth = (constraints.maxWidth - 18) / 4;
          final visibleChipWidth = chipWidth.clamp(54.0, 120.0).toDouble();

          return ScrollConfiguration(
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
              itemCount: menus.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: visibleChipWidth,
                  child: _RecommendedMenuChip(menu: menus[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RecommendedMenuChip extends StatelessWidget {
  const _RecommendedMenuChip({required this.menu});

  final _RecommendedMenuItem menu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${menu.label} ${menu.priceLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _RecommendedMenuItem {
  const _RecommendedMenuItem({
    required this.label,
    required this.priceLabel,
  });

  final String label;
  final String priceLabel;
}

class _RecentChipData {
  const _RecentChipData({
    required this.id,
    required this.label,
    required this.isFallback,
  });

  final String id;
  final String label;
  final bool isFallback;
}

List<_TrendingRankItem> _rankingsForTrendingLabel(String? label) {
  if (label == null) return const [];
  if (label.contains('많이 찾는')) return _mostSearchedRanks;
  if (label.contains('신상')) return _newPlaceRanks;
  if (label.contains('추억')) return _nostalgicPlaceRanks;
  return _hotPlaceRanks;
}

List<_TrendingRankItem> _rankingsForSubmittedQuery(String query) {
  final normalized = query
      .replaceAll(RegExp(r'[^0-9A-Za-z가-힣]'), '')
      .replaceAll(RegExp(r'\s+'), '');

  if (normalized.contains('많이찾는맛집')) return _mostSearchedRanks;
  if (normalized.contains('신상맛집')) return _newPlaceRanks;
  if (normalized.contains('추억의맛집')) return _nostalgicPlaceRanks;
  if (normalized.contains('지금뜨는맛집') || normalized.contains('실시간검색맛집')) {
    return _hotPlaceRanks;
  }
  return const [];
}

RestaurantModel _restaurantForTrendingRankItem(
  _TrendingRankItem item, {
  double? initialLatitude,
  double? initialLongitude,
}) {
  final baseLat = initialLatitude ?? 37.2864;
  final baseLng = initialLongitude ?? 127.0574;
  final row = (item.rank - 1) ~/ 5;
  final column = (item.rank - 1) % 5;
  final latOffset = row == 0 ? -0.0012 : 0.0012;
  final lngOffset = (column - 2) * 0.0012;

  return item.toRestaurantModel(
    latitude: baseLat + latOffset,
    longitude: baseLng + lngOffset,
  );
}

class _TrendingRankItem {
  const _TrendingRankItem({
    required this.rank,
    required this.title,
    required this.subtitle,
  });

  final int rank;
  final String title;
  final String subtitle;

  String get region {
    if (title.contains('수원') || title.contains('남문') || title.contains('팔달문')) {
      return '수원';
    }
    if (title.contains('영통') || title.contains('권선')) {
      return title.contains('권선') ? '권선' : '영통';
    }
    return '광교';
  }

  String get category {
    if (title.contains('스타벅스') ||
        title.contains('커피빈') ||
        title.contains('블루보틀') ||
        title.contains('폴바셋') ||
        title.contains('투썸') ||
        title.contains('카페') ||
        title.contains('다방')) {
      return '카페';
    }
    if (title.contains('베이커리') ||
        title.contains('르빵') ||
        title.contains('빵집')) {
      return '베이커리';
    }
    if (title.contains('스시') ||
        title.contains('오마카세') ||
        title.contains('라멘') ||
        title.contains('소바') ||
        title.contains('정돈')) {
      return '일식';
    }
    if (title.contains('마라') ||
        title.contains('홍콩반점') ||
        title.contains('손짜장')) {
      return '중식';
    }
    if (title.contains('다운타우너') ||
        title.contains('쉐이크쉑') ||
        title.contains('아웃백') ||
        title.contains('브런치')) {
      return '양식';
    }
    if (title.contains('분식') || title.contains('떡볶이')) {
      return '분식';
    }
    if (title.contains('포케')) {
      return '건강식';
    }
    if (title.contains('바')) {
      return '바';
    }
    if (title.contains('통닭') ||
        title.contains('갈비') ||
        title.contains('국밥') ||
        title.contains('냉면') ||
        title.contains('기사식당')) {
      return '한식';
    }
    return '음식점';
  }

  String get representativeKeyword {
    if (title.contains('스타벅스')) return '돌체라떼';
    if (title.contains('커피빈')) return '아메리카노';
    if (title.contains('블루보틀')) return '콜드브루';
    if (title.contains('폴바셋')) return '라떼';
    if (title.contains('투썸')) return '케이크';
    if (title.contains('돌체')) return '돌체 케이크';
    if (title.contains('뉴올리언스')) return '브런치';
    if (title.contains('온기정')) return '텐동';
    if (title.contains('정돈')) return '돈카츠';
    if (title.contains('다운타우너') || title.contains('쉐이크쉑')) return '버거';
    if (title.contains('카페거리')) return '호수공원 카페';
    if (title.contains('스시') || title.contains('오마카세')) return '오마카세';
    if (title.contains('갈비')) return '갈비';
    if (title.contains('마라')) return '마라탕';
    if (title.contains('홍콩반점') || title.contains('손짜장')) return '짜장면';
    if (title.contains('분식') || title.contains('떡볶이')) return '떡볶이';
    if (title.contains('국밥')) return '국밥';
    if (title.contains('통닭')) return '통닭';
    if (title.contains('냉면')) return '냉면';
    if (title.contains('빵집') || title.contains('르빵')) return '소금빵';
    if (title.contains('포케')) return '포케';
    if (title.contains('다방')) return '쌍화차';
    if (title.contains('기사식당')) return '제육백반';
    if (title.contains('바')) return '칵테일';
    return category;
  }

  String get representativePriceLabel {
    final menu = representativeKeyword;
    return switch (menu) {
      '돌체라떼' => '5,900원',
      '아메리카노' => '4,500원',
      '콜드브루' => '5,800원',
      '라떼' => '5,500원',
      '케이크' => '6,800원',
      '돌체 케이크' => '7,200원',
      '브런치' => '15,000원',
      '텐동' => '12,000원',
      '돈카츠' => '14,000원',
      '버거' => '9,800원',
      '호수공원 카페' => '6,000원',
      '오마카세' => '변동가',
      '갈비' => '19,000원',
      '마라탕' => '11,000원',
      '짜장면' => '7,000원',
      '떡볶이' => '5,500원',
      '국밥' => '9,000원',
      '통닭' => '18,000원',
      '냉면' => '10,000원',
      '소금빵' => '3,800원',
      '포케' => '12,500원',
      '쌍화차' => '7,000원',
      '제육백반' => '9,000원',
      '칵테일' => '14,000원',
      _ => '가격 문의',
    };
  }

  List<_RecommendedMenuItem> get recommendedMenus {
    final categoryLabel = category;
    return <_RecommendedMenuItem>[
      _RecommendedMenuItem(
        label: representativeKeyword,
        priceLabel: _normalizedPriceLabel(representativePriceLabel),
      ),
      _RecommendedMenuItem(label: '$categoryLabel 시그니처', priceLabel: '가격 문의'),
      _RecommendedMenuItem(label: '$categoryLabel 세트', priceLabel: '가격 문의'),
      _RecommendedMenuItem(label: '$categoryLabel 사이드', priceLabel: '가격 문의'),
    ];
  }

  String _normalizedPriceLabel(String priceLabel) {
    final trimmed = priceLabel.trim();
    if (trimmed.isEmpty) return '가격 문의';
    if (trimmed.contains('문의') ||
        trimmed.contains('가게') ||
        trimmed.contains('변동') ||
        trimmed.contains('臾몄쓽') ||
        trimmed.contains('蹂')) {
      return '가격 문의';
    }
    return trimmed;
  }

  IconData get representativeIcon {
    final menu = representativeKeyword;
    if (category == '카페' || menu.contains('라떼') || menu.contains('커피')) {
      return Icons.local_cafe_rounded;
    }
    if (category == '베이커리' || menu.contains('케이크') || menu.contains('빵')) {
      return Icons.bakery_dining_rounded;
    }
    if (menu.contains('버거')) return Icons.lunch_dining_rounded;
    if (menu.contains('갈비') || menu.contains('통닭')) {
      return Icons.outdoor_grill_rounded;
    }
    if (menu.contains('칵테일')) return Icons.local_bar_rounded;
    if (menu.contains('포케')) return Icons.eco_rounded;
    if (category == '일식') return Icons.ramen_dining_rounded;
    return Icons.restaurant_rounded;
  }

  Color get representativeImageColor {
    return switch (category) {
      '카페' => const Color(0xFF8B6A4F),
      '베이커리' => const Color(0xFFD28A4C),
      '일식' => const Color(0xFF5577AA),
      '중식' => const Color(0xFFC65B4A),
      '양식' => const Color(0xFF6B8E5A),
      '분식' => const Color(0xFFE07A91),
      '건강식' => const Color(0xFF55A878),
      '바' => const Color(0xFF6750A4),
      '한식' => const Color(0xFFB87931),
      _ => const Color(0xFF8890A6),
    };
  }

  RestaurantModel toRestaurantModel({
    double? latitude,
    double? longitude,
  }) {
    final normalizedId = title
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^0-9A-Za-z가-힣_]'), '');
    final id = 'trending_$rank$normalizedId';

    return RestaurantModel(
      id: id,
      storeId: id,
      name: title,
      address: region,
      category: category,
      truthScore: 0,
      reviewSummary: subtitle,
      latitude: latitude ?? 37.2864,
      longitude: longitude ?? 127.0574,
    );
  }
}

const _hotPlaceRanks = [
  _TrendingRankItem(
    rank: 1,
    title: '스타벅스 수원광교점',
    subtitle: '오늘 실시간 검색 상승',
  ),
  _TrendingRankItem(
    rank: 2,
    title: '커피빈 광교점',
    subtitle: '카페 검색 증가',
  ),
  _TrendingRankItem(
    rank: 3,
    title: '돌체 베이커리',
    subtitle: '디저트 검색 상승',
  ),
  _TrendingRankItem(
    rank: 4,
    title: '뉴올리언스',
    subtitle: '근처 탐색 인기',
  ),
  _TrendingRankItem(
    rank: 5,
    title: '광교 앨리웨이 온기정',
    subtitle: '점심 방문 증가',
  ),
  _TrendingRankItem(
    rank: 6,
    title: '정돈 광교점',
    subtitle: '돈카츠 검색 상승',
  ),
  _TrendingRankItem(
    rank: 7,
    title: '다운타우너 광교',
    subtitle: '버거 매장 관심',
  ),
  _TrendingRankItem(
    rank: 8,
    title: '광교 호수공원 카페거리',
    subtitle: '근처 카페 탐색',
  ),
  _TrendingRankItem(
    rank: 9,
    title: '스시 오마카세 광교',
    subtitle: '저녁 예약 관심',
  ),
  _TrendingRankItem(
    rank: 10,
    title: '광교 갈비명가',
    subtitle: '가족 식사 검색',
  ),
];

const _mostSearchedRanks = [
  _TrendingRankItem(
    rank: 1,
    title: '스타벅스 수원광교점',
    subtitle: '가장 많이 찾는 식당',
  ),
  _TrendingRankItem(
    rank: 2,
    title: '블루보틀 광교점',
    subtitle: '브랜드 매장 검색 상위',
  ),
  _TrendingRankItem(
    rank: 3,
    title: '커피빈 광교점',
    subtitle: '카페 검색 상위',
  ),
  _TrendingRankItem(
    rank: 4,
    title: '돌체 베이커리',
    subtitle: '디저트 매장 검색 상위',
  ),
  _TrendingRankItem(
    rank: 5,
    title: '폴바셋 광교점',
    subtitle: '커피 매장 검색',
  ),
  _TrendingRankItem(
    rank: 6,
    title: '투썸플레이스 광교점',
    subtitle: '케이크 검색 상위',
  ),
  _TrendingRankItem(
    rank: 7,
    title: '쉐이크쉑 광교',
    subtitle: '버거 매장 검색',
  ),
  _TrendingRankItem(
    rank: 8,
    title: '아웃백 광교점',
    subtitle: '가족 외식 검색',
  ),
  _TrendingRankItem(
    rank: 9,
    title: '마라공방 광교점',
    subtitle: '매운맛 검색 증가',
  ),
  _TrendingRankItem(
    rank: 10,
    title: '홍콩반점 광교점',
    subtitle: '중식 검색 상위',
  ),
];

const _newPlaceRanks = [
  _TrendingRankItem(
    rank: 1,
    title: '돌체 베이커리',
    subtitle: '새로 등록된 베이커리',
  ),
  _TrendingRankItem(
    rank: 2,
    title: '뉴올리언스',
    subtitle: '최근 리뷰 증가',
  ),
  _TrendingRankItem(
    rank: 3,
    title: '블루보틀 광교점',
    subtitle: '신규 관심 매장',
  ),
  _TrendingRankItem(
    rank: 4,
    title: '커피빈 광교점',
    subtitle: '새 메뉴 관심 증가',
  ),
  _TrendingRankItem(
    rank: 5,
    title: '르빵 광교',
    subtitle: '신규 베이커리 관심',
  ),
  _TrendingRankItem(
    rank: 6,
    title: '오마카세 하루',
    subtitle: '새 코스 메뉴 등록',
  ),
  _TrendingRankItem(
    rank: 7,
    title: '무드브런치 광교',
    subtitle: '브런치 리뷰 증가',
  ),
  _TrendingRankItem(
    rank: 8,
    title: '라멘소바 광교',
    subtitle: '일식 매장 관심',
  ),
  _TrendingRankItem(
    rank: 9,
    title: '그린포케 광교',
    subtitle: '가벼운 식사 검색',
  ),
  _TrendingRankItem(
    rank: 10,
    title: '선셋바 광교',
    subtitle: '저녁 방문 관심',
  ),
];

const _nostalgicPlaceRanks = [
  _TrendingRankItem(
    rank: 1,
    title: '광교 옛날손짜장',
    subtitle: '오래된 중식 단골집',
  ),
  _TrendingRankItem(
    rank: 2,
    title: '수원 왕돈까스',
    subtitle: '학창 시절 느낌의 경양식',
  ),
  _TrendingRankItem(
    rank: 3,
    title: '팔달문 분식집',
    subtitle: '떡볶이와 튀김 추억 메뉴',
  ),
  _TrendingRankItem(
    rank: 4,
    title: '광교 옛날국밥',
    subtitle: '든든한 동네 국밥집',
  ),
  _TrendingRankItem(
    rank: 5,
    title: '남문 통닭거리',
    subtitle: '오래된 통닭 맛집',
  ),
  _TrendingRankItem(
    rank: 6,
    title: '영통 즉석떡볶이',
    subtitle: '친구들과 먹던 즉떡 감성',
  ),
  _TrendingRankItem(
    rank: 7,
    title: '수원 냉면집',
    subtitle: '여름마다 생각나는 오래된 맛',
  ),
  _TrendingRankItem(
    rank: 8,
    title: '광교 동네빵집',
    subtitle: '크림빵과 소보로 추억 메뉴',
  ),
  _TrendingRankItem(
    rank: 9,
    title: '권선동 기사식당',
    subtitle: '백반과 제육 단골 식당',
  ),
  _TrendingRankItem(
    rank: 10,
    title: '수원 옛날다방',
    subtitle: '쌍화차와 옛 카페 분위기',
  ),
];
