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
  final ValueChanged<int>? onSelectTab;

  const AiRecommendScreen({
    super.key,
    required this.onViewPlace,
    this.onSelectTab,
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
                    onPriceRangeChanged: notifier.changePriceRange,
                    onPartySizeChanged: notifier.changePartySize,
                    onTransportModeChanged: notifier.changeTransportMode,
                    onLocationQuerySubmitted:
                        notifier.changePlanningLocationQuery,
                    onUseCurrentLocation: notifier.useCurrentLocation,
                    onPickFromMap: () {
                      ref.read(aiRecommendMapPickModeProvider.notifier).state =
                          true;
                      onSelectTab?.call(0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('지도에서 위치를 맞춘 뒤 AI 추천 위치로 적용해 주세요'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
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

class _Header extends StatefulWidget {
  final AiRecommendState state;
  final MapPoint? currentLocation;
  final ValueChanged<AiPriceRange> onPriceRangeChanged;
  final ValueChanged<AiPartySize> onPartySizeChanged;
  final ValueChanged<AiTransportMode> onTransportModeChanged;
  final ValueChanged<String> onLocationQuerySubmitted;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPickFromMap;

  const _Header({
    required this.state,
    required this.currentLocation,
    required this.onPriceRangeChanged,
    required this.onPartySizeChanged,
    required this.onTransportModeChanged,
    required this.onLocationQuerySubmitted,
    required this.onUseCurrentLocation,
    required this.onPickFromMap,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

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
          '사용자 취향은 별도 모델로 반영하고, 가격대/인원/이동은 이번 탐색 조건으로 걸러요.',
          style: AppText.body().copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        _LocationPlannerCard(
          state: state,
          onSubmit: widget.onLocationQuerySubmitted,
          onUseCurrentLocation: widget.onUseCurrentLocation,
          onPickFromMap: widget.onPickFromMap,
        ),
        if (state.currentRegionLabel.isEmpty)
          Text(
            _locationStatusText,
            style: AppText.caption().copyWith(color: AppColors.textHint),
          ),
        const SizedBox(height: 14),
        _CollapsibleFilterPanel(
          expanded: _filtersExpanded,
          summary: _filterSummary(state),
          onToggle: () {
            setState(() {
              _filtersExpanded = !_filtersExpanded;
            });
          },
          children: [
            _FilterGroup(
              title: '가격대',
              children: AiPriceRange.values
                  .map(
                    (range) => _FilterChipButton(
                      label: range.label,
                      selected: state.priceRange == range,
                      enabled: !state.isLoading,
                      onSelected: () => widget.onPriceRangeChanged(range),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _FilterGroup(
              title: '인원',
              children: AiPartySize.values
                  .map(
                    (partySize) => _FilterChipButton(
                      label: partySize.label,
                      selected: state.partySize == partySize,
                      enabled: !state.isLoading,
                      onSelected: () => widget.onPartySizeChanged(partySize),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _FilterGroup(
              title: '이동',
              children: AiTransportMode.values
                  .map(
                    (mode) => _FilterChipButton(
                      label: mode.label,
                      selected: state.transportMode == mode,
                      enabled: !state.isLoading,
                      onSelected: () => widget.onTransportModeChanged(mode),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ],
    );
  }

  String _filterSummary(AiRecommendState state) {
    return [
      state.priceRange.label,
      state.partySize.label,
      state.transportMode.label,
    ].join(' · ');
  }

  String get _locationStatusText {
    if (widget.currentLocation == null) {
      return '위치를 확인하면 지역별 추천이 적용됩니다.';
    }
    if (widget.state.isLoading) {
      return '위치를 확인하는 중입니다.';
    }
    return '위치의 지역을 확인하지 못해 전체 추천을 보여줍니다.';
  }
}

class _CollapsibleFilterPanel extends StatelessWidget {
  final bool expanded;
  final String summary;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _CollapsibleFilterPanel({
    required this.expanded,
    required this.summary,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '탐색 필터',
                          style: AppText.caption().copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption().copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState:
                expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}

class _LocationPlannerCard extends StatefulWidget {
  final AiRecommendState state;
  final ValueChanged<String> onSubmit;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPickFromMap;

  const _LocationPlannerCard({
    required this.state,
    required this.onSubmit,
    required this.onUseCurrentLocation,
    required this.onPickFromMap,
  });

  @override
  State<_LocationPlannerCard> createState() => _LocationPlannerCardState();
}

class _LocationPlannerCardState extends State<_LocationPlannerCard> {
  // 대한민국 주요 행정구역 계층 데이터 (샘플 및 주요 지역 구성)
  static const Map<String, Map<String, List<String>>> _koreaRegions = {
    '서울특별시': {
      '강남구': ['역삼동', '삼성동', '논현동', '대치동', '신사동', '청담동'],
      '서초구': ['서초동', '반포동', '방배동', '양재동', '잠원동'],
      '송파구': ['잠실동', '방이동', '가락동', '문정동', '신천동'],
      '마포구': ['서교동', '동교동', '연남동', '망원동', '공덕동', '상암동'],
      '용산구': ['이태원동', '한남동', '갈월동', '남영동', '보광동'],
      '성동구': ['성수동1가', '성수동2가', '행당동', '금호동', '옥수동'],
      '종로구': ['관철동', '혜화동', '삼청동', '인사동', '평창동'],
      '중구': ['명동', '을지로1가', '충무로1가', '소공동', '신당동'],
      '영등포구': ['여의도동', '영등포동', '당산동', '문래동', '양평동'],
      '강서구': ['마곡동', '가양동', '화곡동', '등촌동', '방화동'],
      '관악구': ['신림동', '봉천동', '남현동'],
    },
    '부산광역시': {
      '해운대구': ['우동', '중동', '좌동', '송정동', '재송동'],
      '수영구': ['광안동', '민락동', '남천동', '망미동'],
      '부산진구': ['부전동', '전포동', '양정동', '가야동', '개금동'],
      '중구': ['남포동', '광복동', '중앙동', '보수동'],
      '동래구': ['명륜동', '온천동', '사직동', '안락동'],
      '기장군': ['기장읍', '일광읍', '장안읍', '정관읍'],
    },
    '인천광역시': {
      '연수구': ['송도동', '연수동', '동춘동', '청학동'],
      '남동구': ['구월동', '간석동', '만수동', '논현동'],
      '중구': ['신포동', '영종동', '운서동', '을왕동'],
      '부평구': ['부평동', '산곡동', '청천동', '삼산동'],
    },
    '대구광역시': {
      '중구': ['동성로1가', '삼덕동1가', '봉산동', '대봉동'],
      '수성구': ['범어동', '두산동', '황금동', '만촌동', '상동'],
      '동구': ['신천동', '효목동', '불로동', '방촌동'],
    },
    '대전광역시': {
      '유성구': ['봉명동', '궁동', '어은동', '도룡동', '지족동'],
      '서구': ['둔산동', '탄방동', '갈마동', '월평동', '관저동'],
      '중구': ['은행동', '대흥동', '선화동', '문화동'],
    },
    '광주광역시': {
      '동구': ['충장로1가', '동명동', '산수동', '지산동'],
      '서구': ['치평동', '상무동', '풍암동', '금호동'],
      '광산구': ['수완동', '첨단동', '신가동', '월계동'],
    },
    '울산광역시': {
      '남구': ['삼산동', '달동', '무거동', '신정동'],
      '중구': ['성남동', '우정동', '태화동', '혁신도시'],
    },
    '경기도': {
      '성남시 분당구': ['서현동', '정자동', '야탑동', '판교동', '백현동', '삼평동'],
      '수원시 팔달구': ['인계동', '행궁동', '매산로1가', '우만동'],
      '수원시 영통구': ['영통동', '이의동', '매탄동', '원천동'],
      '고양시 일산동구': ['장항동', '정발산동', '백석동', '마두동', '식사동'],
      '용인시 수지구': ['풍덕천동', '죽전동', '동천동', '상현동'],
      '부천시': ['중동', '상동', '심곡동', '송내동'],
      '화성시': ['동탄동', '반송동', '청계동', '오산동', '향남읍'],
    },
    '강원특별자치도': {
      '춘천시': ['명동', '퇴계동', '석사동', '온의동', '효자동'],
      '원주시': ['무실동', '단구동', '단계동', '반곡동'],
      '강릉시': ['교동', '포남동', '유천동', '초당동', '경포동'],
      '속초시': ['동명동', '조양동', '영랑동', '청학동'],
    },
    '제주특별자치도': {
      '제주시': ['노형동', '연동', '이도2동', '애월읍', '조천읍', '한림읍', '구좌읍'],
      '서귀포시': ['서귀동', '중문동', '강정동', '성산읍', '안덕면', '표선면'],
    },
  };

  String _selectedSido = '경기도';
  String _selectedGugun = '수원시 영통구';
  String _selectedDong = '이의동';

  @override
  void initState() {
    super.initState();
    _syncSelectionFromState(widget.state);
  }

  @override
  void didUpdateWidget(covariant _LocationPlannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.planningLocationQuery !=
            widget.state.planningLocationQuery ||
        oldWidget.state.currentRegionSi != widget.state.currentRegionSi ||
        oldWidget.state.currentRegionGu != widget.state.currentRegionGu ||
        oldWidget.state.currentRegionDong != widget.state.currentRegionDong) {
      setState(() {
        _syncSelectionFromState(widget.state);
      });
    }
  }

  void _syncSelectionFromState(AiRecommendState state) {
    if (state.planningLocationQuery.trim().isNotEmpty) {
      _parseInitialQuery(state.planningLocationQuery);
      return;
    }

    _selectKnownRegion(
      sido: state.currentRegionSi,
      gugun: state.currentRegionGu,
      dong: state.currentRegionDong,
    );
  }

  void _selectKnownRegion({
    required String sido,
    required String gugun,
    required String dong,
  }) {
    final nextSido = sido.trim();
    if (nextSido.isEmpty || !_koreaRegions.containsKey(nextSido)) return;

    final guguns = _koreaRegions[nextSido]!;
    final nextGugun =
        guguns.containsKey(gugun.trim()) ? gugun.trim() : guguns.keys.first;
    final dongs = guguns[nextGugun]!;
    final nextDong = dongs.contains(dong.trim()) ? dong.trim() : dongs.first;

    _selectedSido = nextSido;
    _selectedGugun = nextGugun;
    _selectedDong = nextDong;
  }

  void _parseInitialQuery(String query) {
    if (query.trim().isEmpty) return;
    final parts = query.trim().split(' ');
    if (parts.isNotEmpty) {
      final sido = parts[0];
      if (_koreaRegions.containsKey(sido)) {
        _selectedSido = sido;
        final guguns = _koreaRegions[sido]!;
        if (parts.length > 1) {
          // 성남시 분당구 처럼 구군이 2어절인 경우 처리
          String gugunCand = parts[1];
          if (parts.length > 2 &&
              guguns.containsKey('${parts[1]} ${parts[2]}')) {
            gugunCand = '${parts[1]} ${parts[2]}';
          }
          if (guguns.containsKey(gugunCand)) {
            _selectedGugun = gugunCand;
            final dongs = guguns[gugunCand]!;
            final dongIdx = parts.length > (gugunCand.contains(' ') ? 3 : 2)
                ? (gugunCand.contains(' ') ? 3 : 2)
                : -1;
            if (dongIdx != -1 && dongs.contains(parts[dongIdx])) {
              _selectedDong = parts[dongIdx];
            } else if (dongs.isNotEmpty) {
              _selectedDong = dongs.first;
            }
          } else if (guguns.isNotEmpty) {
            _selectedGugun = guguns.keys.first;
            _selectedDong = guguns.values.first.first;
          }
        } else if (guguns.isNotEmpty) {
          _selectedGugun = guguns.keys.first;
          _selectedDong = guguns.values.first.first;
        }
      }
    }
  }

  void _onSidoChanged(String? newSido) {
    if (newSido == null || newSido == _selectedSido) return;
    setState(() {
      _selectedSido = newSido;
      final guguns = _koreaRegions[_selectedSido]!;
      _selectedGugun = guguns.keys.first;
      _selectedDong = guguns[_selectedGugun]!.first;
    });
    _submitCurrentSelection();
  }

  void _onGugunChanged(String? newGugun) {
    if (newGugun == null || newGugun == _selectedGugun) return;
    setState(() {
      _selectedGugun = newGugun;
      final dongs = _koreaRegions[_selectedSido]![_selectedGugun]!;
      _selectedDong = dongs.first;
    });
    _submitCurrentSelection();
  }

  void _onDongChanged(String? newDong) {
    if (newDong == null || newDong == _selectedDong) return;
    setState(() {
      _selectedDong = newDong;
    });
    _submitCurrentSelection();
  }

  void _submitCurrentSelection() {
    final query = '$_selectedSido $_selectedGugun $_selectedDong';
    widget.onSubmit(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isPlanningLocation = state.hasPlanningLocation;

    final currentGugunMap = _koreaRegions[_selectedSido] ?? {};
    final currentDongList = currentGugunMap[_selectedGugun] ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppColors.primary500,
              ),
              const SizedBox(width: 6),
              Text(
                '탐색 지역 선택',
                style: AppText.caption().copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isPlanningLocation)
                TextButton.icon(
                  onPressed:
                      state.isLoading ? null : widget.onUseCurrentLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 14),
                  label: const Text('내 위치로 리셋'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // ── 3단 드롭다운 선택 영역 ──
          Row(
            children: [
              // 시/도 드롭다운
              Expanded(
                flex: 5,
                child: _buildDropdown<String>(
                  value: _selectedSido,
                  items: _koreaRegions.keys.toList(),
                  onChanged: state.isLoading ? null : _onSidoChanged,
                  hint: '시/도',
                ),
              ),
              const SizedBox(width: 8),
              // 시/군/구 드롭다운
              Expanded(
                flex: 5,
                child: _buildDropdown<String>(
                  value: _selectedGugun,
                  items: currentGugunMap.keys.toList(),
                  onChanged: state.isLoading ? null : _onGugunChanged,
                  hint: '시/군/구',
                ),
              ),
              const SizedBox(width: 8),
              // 읍/면/동 드롭다운
              Expanded(
                flex: 5,
                child: _buildDropdown<String>(
                  value: _selectedDong,
                  items: currentDongList,
                  onChanged: state.isLoading ? null : _onDongChanged,
                  hint: '읍/면/동',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.isLoading ? null : widget.onPickFromMap,
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('지도에서 직접 위치 선택하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?>? onChanged,
    required String hint,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value)
              ? value
              : (items.isNotEmpty ? items.first : null),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.textHint),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          style: AppText.body().copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          hint: Text(hint,
              style: AppText.body()
                  .copyWith(color: AppColors.textHint, fontSize: 14)),
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FilterGroup({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.tune_rounded,
              size: 13,
              color: AppColors.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: AppText.caption().copyWith(
                color: AppColors.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onSelected() : null,
      selectedColor: AppColors.primary50,
      checkmarkColor: AppColors.primary700,
      labelStyle: AppText.caption().copyWith(
        color: selected ? AppColors.primary700 : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary200 : AppColors.border,
      ),
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
