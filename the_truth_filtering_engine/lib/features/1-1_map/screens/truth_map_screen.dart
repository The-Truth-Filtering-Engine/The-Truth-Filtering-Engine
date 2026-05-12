import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/ai_recommend_item.dart';
import '../../../data/models/blog_review_model.dart';
import '../models/map_point.dart';
import '../models/restaurant_model.dart';
import '../../../services/api_service.dart';
import '../../../services/bookmark_service.dart';
import '../../../services/location_service.dart';
import '../widgets/action_button.dart';
import '../widgets/panel_header.dart';
import '../widgets/review_grade_badge.dart';
import '../../../core/theme/app_colors.dart';

enum LoadState { loading, ready, error }

enum DetailState { idle, loading, analyzing, loaded, noData, error }

enum ActivePanel { none, restaurant, detail, bookmarks, ai, profile }

enum ReviewSort { recommended, trust, latest }

enum AiRegionScope { si, gu, dong }

class TruthMapScreen extends StatefulWidget {
  const TruthMapScreen({super.key});

  @override
  State<TruthMapScreen> createState() => _TruthMapScreenState();
}

class _TruthMapScreenState extends State<TruthMapScreen> {
  final ApiService api = ApiService();
  final BookmarkService bookmarkService = BookmarkService();
  final LocationService locationService = LocationService();

  LoadState loadState = LoadState.loading;
  String errorMessage = '';
  String placesErrorMessage = '';
  ActivePanel activePanel = ActivePanel.none;
  RestaurantModel? selectedRestaurant;
  MapPoint? currentPosition;

  List<RestaurantModel> nearbyRestaurants = [];
  List<RestaurantModel> bookmarkedRestaurants = [];
  List<BlogReviewModel> detailReviews = [];
  List<AiRecommendItem> aiItems = [];

  DetailState detailState = DetailState.idle;
  String detailErrorMessage = '';
  ReviewSort reviewSort = ReviewSort.recommended;

  AiRegionScope aiRegionScope = AiRegionScope.si;
  int aiPage = 1;
  bool aiHasNext = false;
  bool aiLoading = false;
  String aiErrorMessage = '';
  String aiRegionLabel = '';
  String aiCurrentRegionLabel = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final bookmarks = await bookmarkService.loadBookmarks();
      final position = await locationService.getCurrentPosition();

      if (!mounted) return;
      setState(() {
        bookmarkedRestaurants = bookmarks;
        currentPosition = position;
        loadState = LoadState.ready;
      });

      await _loadNearbyRestaurants();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadState = LoadState.error;
        errorMessage = '위치 정보를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _loadNearbyRestaurants() async {
    final center = currentPosition ??
        const MapPoint(latitude: 37.5245, longitude: 127.037);

    try {
      final items = await api.fetchNearbyRestaurants(
        center: center,
        radius: 1200,
      );

      if (!mounted) return;
      setState(() {
        nearbyRestaurants = items;
        placesErrorMessage = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        placesErrorMessage = '주변 음식점을 불러오지 못했습니다.';
      });
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void goHome() {
    setState(() {
      selectedRestaurant = null;
      activePanel = ActivePanel.none;
    });
  }

  void handleBack() {
    setState(() {
      if (activePanel == ActivePanel.detail) {
        activePanel = ActivePanel.restaurant;
      } else {
        activePanel = ActivePanel.none;
        selectedRestaurant = null;
      }
    });
  }

  bool isCafe(RestaurantModel restaurant) {
    final category = restaurant.category.toLowerCase();
    return restaurant.category.contains('카페') || category.contains('cafe');
  }

  String formatDistance(double distance) {
    if (distance <= 0) return '거리 정보 없음';
    if (distance >= 1000) return '${(distance / 1000).toStringAsFixed(1)}km';
    return '${distance.round()}m';
  }

  bool isBookmarked(RestaurantModel restaurant) {
    return bookmarkedRestaurants.any(
      (item) => item.effectiveStoreId == restaurant.effectiveStoreId,
    );
  }

  Future<void> toggleBookmark(RestaurantModel restaurant) async {
    final wasBookmarked = bookmarkedRestaurants.any(
      (item) => item.effectiveStoreId == restaurant.effectiveStoreId,
    );
    final next = await bookmarkService.toggleBookmark(restaurant);

    if (!mounted) return;
    setState(() {
      bookmarkedRestaurants = next;
    });

    _showToast(wasBookmarked ? '북마크에서 삭제되었습니다.' : '북마크에 추가되었습니다.');
  }

  Future<void> openUrl(String? url, String emptyMessage) async {
    final safeUrl = url?.trim() ?? '';

    if (safeUrl.isEmpty) {
      _showToast(emptyMessage);
      return;
    }

    final uri = Uri.tryParse(safeUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showToast('URL을 열 수 없습니다.');
    }
  }

  Future<void> openDetailPanel(
    RestaurantModel restaurant, {
    bool forceFresh = false,
  }) async {
    setState(() {
      selectedRestaurant = restaurant;
      activePanel = ActivePanel.detail;
      detailState = forceFresh ? DetailState.analyzing : DetailState.loading;
      detailReviews = [];
      detailErrorMessage = '';
      reviewSort = ReviewSort.recommended;
    });

    try {
      List<BlogReviewModel> reviews = [];

      if (!forceFresh) {
        reviews = await api.fetchCachedReviews(restaurant.name);
      }

      if (reviews.isEmpty) {
        if (mounted) {
          setState(() {
            detailState = DetailState.analyzing;
          });
        }
        reviews = await api.fetchFreshReviews(restaurant.name);
      }

      if (!mounted) return;
      setState(() {
        detailReviews = reviews;
        detailState = reviews.isEmpty ? DetailState.noData : DetailState.loaded;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        detailState = DetailState.error;
        detailErrorMessage = error.toString();
      });
    }
  }

  Future<void> loadAiRecommendations({int page = 1}) async {
    setState(() {
      aiLoading = true;
      aiErrorMessage = '';
    });

    try {
      final response = await api.fetchAiRecommendations(
        page: page,
        regionScope: aiRegionScope.name,
        currentPosition: currentPosition,
      );

      if (!mounted) return;
      setState(() {
        aiItems = response.items;
        aiPage = response.page;
        aiHasNext = response.hasNext;
        aiRegionLabel = response.regionLabel;
        aiCurrentRegionLabel = response.currentRegionLabel;
        aiLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        aiLoading = false;
        aiErrorMessage = 'AI 추천 API 오류';
      });
    }
  }

  void openAiPanel() {
    setState(() {
      selectedRestaurant = null;
      activePanel =
          activePanel == ActivePanel.ai ? ActivePanel.none : ActivePanel.ai;
    });

    if (activePanel == ActivePanel.ai && aiItems.isEmpty) {
      loadAiRecommendations(page: 1);
    }
  }

  void focusRestaurant(RestaurantModel restaurant) {
    setState(() {
      selectedRestaurant = restaurant;
      activePanel = ActivePanel.restaurant;
    });
  }

  List<BlogReviewModel> get sortedDetailReviews {
    final items = [...detailReviews];

    switch (reviewSort) {
      case ReviewSort.recommended:
        items.sort(compareRecommendedReviews);
      case ReviewSort.trust:
        items.sort((a, b) => a.adProbability.compareTo(b.adProbability));
      case ReviewSort.latest:
        items.sort((a, b) => b.date.compareTo(a.date));
    }

    return items;
  }

  int compareRecommendedReviews(BlogReviewModel a, BlogReviewModel b) {
    final likeCompare = b.likeCount.compareTo(a.likeCount);
    if (likeCompare != 0) return likeCompare;

    final trustCompare = a.adProbability.compareTo(b.adProbability);
    if (trustCompare != 0) return trustCompare;

    return b.date.compareTo(a.date);
  }

  List<MapEntry<String, int>> get keywords {
    final counts = <String, int>{};

    const stopWords = {
      '입니다',
      '추천',
      '하려고',
      '오늘',
      '리뷰',
      '정말',
      '이렇게',
      '있는',
      '없는',
      '그리고',
      '여기서',
      '으로',
      '그래서',
      '맛있는',
      '방문',
      '위치',
    };

    for (final review in detailReviews) {
      final words = review.title
          .replaceAll(RegExp(r'[^가-힣a-zA-Z0-9\s]'), ' ')
          .split(RegExp(r'\s+'));

      for (final word in words) {
        final trimmed = word.trim();
        if (trimmed.length >= 2 && !stopWords.contains(trimmed)) {
          counts[trimmed] = (counts[trimmed] ?? 0) + 1;
        }
      }
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(14).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildMapArea(),
          _buildProfileTopButton(),
          if (loadState == LoadState.loading)
            const _StatusChip(message: '위치를 불러오는 중입니다.'),
          if (loadState == LoadState.error)
            _StatusChip(message: errorMessage, isError: true),
          if (placesErrorMessage.isNotEmpty)
            _StatusChip(message: placesErrorMessage, isError: true),
          if (activePanel != ActivePanel.none) _buildActivePanel(),
          _buildMapToolRail(),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    return Positioned.fill(
      child: Container(
        color: AppColors.mapTeal,
        child: Stack(
          children: [
            Center(
              child: Text(
                'Kakao Map 영역\n위치 권한 허용 후 표시됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.sheetSubtext,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...nearbyRestaurants.take(10).map((restaurant) {
              final index = nearbyRestaurants.indexOf(restaurant);

              return Positioned(
                left: 40.0 + (index % 4) * 70,
                top: 140.0 + (index ~/ 4) * 90,
                child: GestureDetector(
                  onTap: () => focusRestaurant(restaurant),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17B26A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: Center(
                      child: Text(isCafe(restaurant) ? '☕' : '🍽️'),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTopButton() {
    return Positioned(
      top: 14,
      right: 14,
      child: _MapToolButton(
        icon: Icons.person,
        onTap: () {
          setState(() {
            selectedRestaurant = null;
            activePanel = activePanel == ActivePanel.profile
                ? ActivePanel.none
                : ActivePanel.profile;
          });
        },
      ),
    );
  }

  Widget _buildMapToolRail() {
    return Positioned(
      top: 62,
      right: 14,
      child: Column(
        children: [
          _MapToolButton(
              icon: Icons.my_location, onTap: _loadNearbyRestaurants),
          const SizedBox(height: 6),
          _MapToolButton(
            icon: Icons.bookmark,
            onTap: () {
              setState(() {
                selectedRestaurant = null;
                activePanel = activePanel == ActivePanel.bookmarks
                    ? ActivePanel.none
                    : ActivePanel.bookmarks;
              });
            },
          ),
          const SizedBox(height: 6),
          _MapToolButton(icon: Icons.auto_awesome, onTap: openAiPanel),
          const SizedBox(height: 6),
          _MapToolButton(
            icon: Icons.settings,
            onTap: () => _showToast('설정 기능은 추후 추가될 예정입니다.'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePanel() {
    final width = MediaQuery.of(context).size.width;

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: width < 760 ? width * 0.92 : 420,
        child: Material(
          elevation: 18,
          color: Colors.white,
          child: switch (activePanel) {
            ActivePanel.restaurant => _buildRestaurantPanel(),
            ActivePanel.detail => _buildDetailPanel(),
            ActivePanel.bookmarks => _buildBookmarksPanel(),
            ActivePanel.ai => _buildAiPanel(),
            ActivePanel.profile => _buildProfilePanel(),
            ActivePanel.none => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  Widget _buildRestaurantPanel() {
    final restaurant = selectedRestaurant;
    if (restaurant == null) return const SizedBox.shrink();

    return Column(
      children: [
        PanelHeader(title: restaurant.name, onBack: goHome, onHome: goHome),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 168,
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 20),
                alignment: Alignment.bottomLeft,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF111827), Color(0xFF2A3447)],
                  ),
                ),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text(
                      isCafe(restaurant) ? '☕' : '🍽️',
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.category,
                      style: const TextStyle(
                        color: AppColors.markerVerified,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppColors.sheetSubtext,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${restaurant.address.isEmpty ? '주소 정보 없음' : restaurant.address} · ${formatDistance(restaurant.distance.toDouble())}',
                            style: const TextStyle(
                              color: AppColors.sheetSubtext,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ActionButton(
                          icon: Icons.phone,
                          label: 'Call',
                          onTap: () => _showToast(
                            (restaurant.phone?.isEmpty ?? true)
                                ? '등록된 전화번호가 없습니다.'
                                : restaurant.phone!,
                          ),
                        ),
                        ActionButton(
                          icon: isBookmarked(restaurant)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          label: 'Save',
                          onTap: () => toggleBookmark(restaurant),
                        ),
                        ActionButton(
                          icon: Icons.navigation,
                          label: 'Route',
                          onTap: () =>
                              openUrl(restaurant.placeUrl, '경로 URL이 없습니다.'),
                        ),
                        ActionButton(
                          icon: Icons.share,
                          label: 'Share',
                          onTap: () => openUrl(
                              restaurant.placeUrl, '공유할 수 있는 URL이 없습니다.'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () => openDetailPanel(restaurant),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('상세 보기'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailPanel() {
    final restaurant = selectedRestaurant;
    if (restaurant == null) return const SizedBox.shrink();

    return Column(
      children: [
        PanelHeader(title: restaurant.name, onBack: handleBack, onHome: goHome),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _RestaurantMiniCard(
                restaurant: restaurant,
                emoji: isCafe(restaurant) ? '☕' : '🍽️',
                distanceLabel: formatDistance(restaurant.distance.toDouble()),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ActionButton(
                    icon: Icons.phone,
                    label: 'Call',
                    onTap: () => _showToast(
                      (restaurant.phone?.isEmpty ?? true)
                          ? '등록된 전화번호가 없습니다.'
                          : restaurant.phone!,
                    ),
                  ),
                  ActionButton(
                    icon: isBookmarked(restaurant)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    label: 'Save',
                    onTap: () => toggleBookmark(restaurant),
                  ),
                  ActionButton(
                    icon: Icons.navigation,
                    label: 'Route',
                    onTap: () => openUrl(restaurant.placeUrl, '경로 URL이 없습니다.'),
                  ),
                  ActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: () =>
                        openUrl(restaurant.placeUrl, '공유할 수 있는 URL이 없습니다.'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (detailState == DetailState.loading ||
                  detailState == DetailState.analyzing)
                _StateCard(
                  icon: Icons.refresh,
                  title: detailState == DetailState.loading
                      ? '캐시된 리뷰를 확인하는 중입니다.'
                      : '새 리뷰를 수집하고 분석하는 중입니다.',
                  message: '처음에는 시간이 걸릴 수 있습니다. 최대 30초 정도 소요될 수 있습니다.',
                ),
              if (detailState == DetailState.noData)
                _StateCard(
                  icon: Icons.error_outline,
                  title: '아직 분석된 리뷰가 없습니다.',
                  message: '새 분석은 잠시 후 다시 시도할 수 있습니다.',
                  actionLabel: '다시 분석',
                  onAction: () => openDetailPanel(restaurant, forceFresh: true),
                ),
              if (detailState == DetailState.error)
                _StateCard(
                  icon: Icons.error_outline,
                  title: '상세 정보를 불러오지 못했습니다.',
                  message: detailErrorMessage,
                  actionLabel: '다시 시도',
                  onAction: () => openDetailPanel(restaurant, forceFresh: true),
                ),
              if (detailState == DetailState.loaded) ...[
                _SectionCard(
                  title: '리뷰 키워드',
                  icon: Icons.info_outline,
                  child: keywords.isEmpty
                      ? Text(
                          '표시할 키워드가 없습니다.',
                          style: TextStyle(color: AppColors.sheetSubtext),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: keywords
                              .map(
                                (entry) => Chip(
                                  label: Text(entry.key),
                                  backgroundColor: const Color(0xFFEEF2FF),
                                  labelStyle: const TextStyle(
                                    color: Color(0xFF26336B),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _buildReviewSection(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection() {
    return _SectionCard(
      title: '블로그 리뷰',
      icon: Icons.access_time,
      child: Column(
        children: [
          SegmentedButton<ReviewSort>(
            segments: const [
              ButtonSegment(
                value: ReviewSort.recommended,
                label: Text('추천순'),
              ),
              ButtonSegment(value: ReviewSort.trust, label: Text('신뢰순')),
              ButtonSegment(value: ReviewSort.latest, label: Text('최신순')),
            ],
            selected: {reviewSort},
            onSelectionChanged: (value) {
              setState(() {
                reviewSort = value.first;
              });
            },
          ),
          const SizedBox(height: 14),
          ...sortedDetailReviews.map(
            (review) => _ReviewCard(
              review: review,
              onTap: () => openUrl(review.url, '연결된 리뷰 URL이 없습니다.'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksPanel() {
    return Column(
      children: [
        PanelHeader(
          title: '북마크',
          subtitle: 'Saved Places',
          onBack: goHome,
          onHome: goHome,
        ),
        Expanded(
          child: bookmarkedRestaurants.isEmpty
              ? Center(
                  child: Text(
                    '저장된 장소가 없습니다.',
                    style: TextStyle(
                      color: AppColors.sheetSubtext,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(22),
                  itemCount: bookmarkedRestaurants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final restaurant = bookmarkedRestaurants[index];
                    return _BookmarkTile(
                      restaurant: restaurant,
                      emoji: isCafe(restaurant) ? '☕' : '🍽️',
                      onTap: () => focusRestaurant(restaurant),
                      onRemove: () => toggleBookmark(restaurant),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAiPanel() {
    return Column(
      children: [
        PanelHeader(
          title: 'AI 추천',
          subtitle: '$aiPage 페이지',
          onBack: goHome,
          onHome: goHome,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                '가게별로 광고 가능성이 낮게 감지된 리뷰입니다.',
                style: TextStyle(color: AppColors.sheetSubtext, height: 1.45),
              ),
              const SizedBox(height: 12),
              SegmentedButton<AiRegionScope>(
                segments: const [
                  ButtonSegment(value: AiRegionScope.si, label: Text('시')),
                  ButtonSegment(value: AiRegionScope.gu, label: Text('구')),
                  ButtonSegment(value: AiRegionScope.dong, label: Text('동')),
                ],
                selected: {aiRegionScope},
                onSelectionChanged: aiLoading
                    ? null
                    : (value) {
                        setState(() {
                          aiRegionScope = value.first;
                        });
                        loadAiRecommendations(page: 1);
                      },
              ),
              const SizedBox(height: 12),
              if (aiCurrentRegionLabel.isNotEmpty)
                _InfoBox(
                  title: '현재 지역',
                  value: aiCurrentRegionLabel,
                  caption: aiRegionLabel,
                ),
              if (aiLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (aiErrorMessage.isNotEmpty)
                _StateCard(
                  icon: Icons.error_outline,
                  title: aiErrorMessage,
                  message: '다시 시도해주세요.',
                ),
              if (!aiLoading && aiItems.isEmpty && aiErrorMessage.isEmpty)
                const _StateCard(
                  icon: Icons.auto_awesome,
                  title: '추천 결과가 없습니다.',
                  message: '지역 범위를 변경하여 다시 확인해 보세요.',
                ),
              ...aiItems.map(
                (item) => _AiRecommendCard(
                  item: item,
                  onFocus: () {
                    if (!item.hasLocation) {
                      _showToast('위치 정보가 없는 추천입니다.');
                      return;
                    }
                    focusRestaurant(item.toRestaurantModel());
                  },
                  onOpen: () => openUrl(item.reviewUrl, '연결된 리뷰 URL이 없습니다.'),
                ),
              ),
              if (aiItems.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: aiPage <= 1 || aiLoading
                            ? null
                            : () => loadAiRecommendations(page: aiPage - 1),
                        child: const Text('이전 10개'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: !aiHasNext || aiLoading
                            ? null
                            : () => loadAiRecommendations(page: aiPage + 1),
                        child: Text(aiLoading ? '로딩 중' : '다음 10개'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePanel() {
    return Column(
      children: [
        PanelHeader(
          title: '프로필',
          subtitle: 'My Account',
          onBack: goHome,
          onHome: goHome,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.person,
                    size: 40, color: AppColors.markerVerified),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  '사용자',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const Center(
                child: Text(
                  'user@example.com',
                  style: TextStyle(color: AppColors.sheetSubtext),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  _showToast('로그아웃 되었습니다.');
                  goHome();
                },
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE85C5C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 위젯들 ──────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusChip({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 24)],
          ),
          child: Text(
            message,
            style: TextStyle(
              color:
                  isError ? const Color(0xFFE85C5C) : const Color(0xFF172033),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapToolButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.94),
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 20, color: const Color(0xFF182238)),
        ),
      ),
    );
  }
}

class _RestaurantMiniCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final String emoji;
  final String distanceLabel;

  const _RestaurantMiniCard({
    required this.restaurant,
    required this.emoji,
    required this.distanceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.markerVerified,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${restaurant.address.isEmpty ? '주소 정보 없음' : restaurant.address} · $distanceLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.sheetSubtext, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _WhiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sheetDivider),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(icon, size: 26, color: AppColors.sheetSubtext),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.sheetSubtext,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final BlogReviewModel review;
  final VoidCallback onTap;

  const _ReviewCard({required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.sheetDivider),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      review.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  ReviewGradeBadge(status: review.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                review.preview,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${review.author}${review.date.isNotEmpty ? ' · ${review.date}' : ''}',
                style: const TextStyle(
                  color: AppColors.sheetSubtext,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '리뷰 열기',
                    style: TextStyle(
                      color: AppColors.markerVerified,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.open_in_new,
                      size: 13, color: AppColors.markerVerified),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final RestaurantModel restaurant;
  final String emoji;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BookmarkTile({
    required this.restaurant,
    required this.emoji,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${restaurant.category} · ${restaurant.address.isEmpty ? '주소 정보 없음' : restaurant.address}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.sheetSubtext,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            tooltip: '북마크 삭제',
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  final String caption;

  const _InfoBox({
    required this.title,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.markerVerified.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.sheetSubtext,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (caption.isNotEmpty)
            Text(
              caption,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _AiRecommendCard extends StatelessWidget {
  final AiRecommendItem item;
  final VoidCallback onFocus;
  final VoidCallback onOpen;

  const _AiRecommendCard({
    required this.item,
    required this.onFocus,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.placeName.isEmpty ? item.name : item.placeName;
    final meta = [item.bloggerName, item.postDate]
        .where((e) => e.isNotEmpty)
        .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.sheetDivider),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 16, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Chip(
                label: Text('광고 ${item.adPercent}%'),
                backgroundColor: const Color(0xFFEEF2FF),
                labelStyle: const TextStyle(
                  color: Color(0xFF26336B),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.reviewTitle.isEmpty ? '제목 없는 리뷰' : item.reviewTitle,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.reviewDescription.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              item.reviewDescription,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            meta.isEmpty ? '블로그 리뷰' : meta,
            style: const TextStyle(
              color: AppColors.sheetSubtext,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFocus,
                  icon: const Icon(Icons.location_on_outlined, size: 15),
                  label: const Text('위치 보기'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('리뷰 보기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
