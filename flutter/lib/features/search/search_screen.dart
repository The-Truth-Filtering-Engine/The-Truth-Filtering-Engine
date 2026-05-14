import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/widgets/widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../models/search_history_models.dart';
import '../../models/search_preview_models.dart';
import '../../screens/restaurant_list_screen.dart';
import '../map/models/restaurant_model.dart';
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

  static const _minimumSubmitLength = 2;

  static const _fallbackRecentQueries = <String>[
    '돌체라떼',
    '블루보틀',
    '스타벅스',
  ];

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
          recentQueries: _recentQueries(state),
          isLoadingHistory: state.isLoadingHistory,
          onTrendingTapped: _applyTrendingQuery,
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
            onIssueTapped: _selectIssue,
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

    return _fallbackRecentQueries
        .map(
          (query) => _RecentChipData(
            id: query,
            label: query,
            isFallback: true,
          ),
        )
        .toList();
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

  void _applyTrendingQuery(SearchTrendingChip chip) {
    _applyQuery(chip.label);
  }

  void _applyRecentQuery(String query) {
    _applyQuery(query);
  }

  void _clearQuery() {
    _textController.clear();
    _onQueryChanged('');
    _focusNode.requestFocus();
  }

  void _submitSearch(String query) {
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
    _focusNode.unfocus();
  }

  Future<void> _selectIssue(SearchIssueChip chip) async {
    final query = chip.keyword.trim().isEmpty ? chip.label : chip.keyword;
    await ref.read(searchControllerProvider.notifier).onResultSelected(
          SearchRecentHistoryRequest(
            query: stateQuery,
            clickedType: SearchClickType.issue,
            clickedId: chip.id,
            clickedLabel: chip.label,
          ),
        );
    _applyQuery(query);
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
    _submitSearch(menu.name);
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
    _submitSearch(restaurant.name);
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
    _submitSearch(query);
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
            icon: Icon(Icons.bookmark_border_rounded),
            activeIcon: Icon(Icons.bookmark_rounded),
            label: '북마크',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_toggle_off_rounded),
            label: '최근 분석',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome_rounded),
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
    required this.recentQueries,
    required this.isLoadingHistory,
    required this.onTrendingTapped,
    required this.onRecentTapped,
    required this.onDeleteRecent,
    required this.onClearRecent,
  });

  final List<SearchTrendingChip> trendingChips;
  final List<_RecentChipData> recentQueries;
  final bool isLoadingHistory;
  final ValueChanged<SearchTrendingChip> onTrendingTapped;
  final ValueChanged<String> onRecentTapped;
  final ValueChanged<String> onDeleteRecent;
  final VoidCallback? onClearRecent;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        const _SectionTitle(
          title: '지금 뜨는 맛집',
        ),
        const SizedBox(height: 10),
        _TrendingChipRow(
          chips: trendingChips,
          onTapped: onTrendingTapped,
        ),
        const SizedBox(height: 26),
        _SectionTitle(
          title: '최근 검색어',
          actionLabel: onClearRecent == null ? null : '전체 삭제',
          onActionTap: onClearRecent,
        ),
        const SizedBox(height: 10),
        if (isLoadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          _RecentSearchList(
            recentQueries: recentQueries,
            onRecentTapped: onRecentTapped,
            onDeleteRecent: onDeleteRecent,
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
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

class _TrendingChipRow extends StatelessWidget {
  const _TrendingChipRow({
    required this.chips,
    required this.onTapped,
  });

  static const _styles = <_TrendingChipStyle>[
    _TrendingChipStyle(
      background: Color(0xFFFFF4F7),
      border: Color(0xFFFFC8D7),
      foreground: Color(0xFF8A1F3F),
    ),
    _TrendingChipStyle(
      background: Color(0xFFFFF5EA),
      border: Color(0xFFFFD3A3),
      foreground: Color(0xFF7A3F00),
    ),
    _TrendingChipStyle(
      background: Color(0xFFFFFBE1),
      border: Color(0xFFFFECA0),
      foreground: Color(0xFF604800),
    ),
    _TrendingChipStyle(
      background: Color(0xFFF4FBEA),
      border: Color(0xFFD8F1AA),
      foreground: Color(0xFF315F00),
    ),
    _TrendingChipStyle(
      background: Color(0xFFF0FAFF),
      border: Color(0xFFBEE8FF),
      foreground: Color(0xFF105C7C),
    ),
    _TrendingChipStyle(
      background: Color(0xFFF7F2FF),
      border: Color(0xFFDCCAFF),
      foreground: Color(0xFF4C2C9A),
    ),
    _TrendingChipStyle(
      background: Color(0xFFF0FCF7),
      border: Color(0xFFC3F0DE),
      foreground: Color(0xFF126548),
    ),
    _TrendingChipStyle(
      background: Color(0xFFFCF2FF),
      border: Color(0xFFECC8FF),
      foreground: Color(0xFF6B248E),
    ),
  ];

  final List<SearchTrendingChip> chips;
  final ValueChanged<SearchTrendingChip> onTapped;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

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
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          primary: false,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final chip = chips[index];
            return _KeywordChip(
              label: chip.label,
              style: _styles[index % _styles.length],
              onTap: () => onTapped(chip),
            );
          },
        ),
      ),
    );
  }
}

class _TrendingChipStyle {
  const _TrendingChipStyle({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
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

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final _TrendingChipStyle style;
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: style.border, width: 0.8),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ).copyWith(color: style.foreground),
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
  });

  final String query;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<RestaurantModel> onRestaurantSelected;

  @override
  Widget build(BuildContext context) {
    return RestaurantListScreen(
      query: query,
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      onViewPlace: onRestaurantSelected,
    );
  }
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
