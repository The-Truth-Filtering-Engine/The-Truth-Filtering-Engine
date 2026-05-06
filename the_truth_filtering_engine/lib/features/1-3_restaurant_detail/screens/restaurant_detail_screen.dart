import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../main.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../1-1_map/models/restaurant_model.dart';
import '../../1-1_map/providers/map_provider.dart';
import '../providers/blog_review.dart';
import '../../../core/providers/analysis_mode_provider.dart';
import '../widgets/restaurant_header_widget.dart';
import '../widgets/ai_analysis_card.dart';
import '../widgets/word_cloud_card.dart';
import '../widgets/no_data_card.dart';
import '../widgets/review_list_section.dart';

// ── 화면 상태 ─────────────────────────────────────────────────────────────────

enum _ScreenState {
  initial,
  checking,
  noData,
  analyzing,
  loaded,
}

// ── API: Supabase 캐시 조회 ───────────────────────────────────────────────────

Future<List<BlogReview>> _fetchCachedReviews(
    String name, String address, AnalysisMode mode) async {
  final uri = BackendConfig.apiUri('/search/cached', queryParameters: {
    'query': name,
    'address': address,
  });

  final res = await http.get(uri).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) return [];

  final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final list = body['reviews'] as List<dynamic>? ?? [];
  if (list.isEmpty) return [];

  return list
      .map((e) => BlogReview.fromApiWithMode(e as Map<String, dynamic>, mode))
      .toList();
}

// ── API: 신규 크롤링 + AI 분석 ────────────────────────────────────────────────

Future<List<BlogReview>> _fetchFreshReviews(
    String name, String address, AnalysisMode mode,
    {bool refresh = false}) async {
  final queryParameters = {
    'query': name,
    'address': address,
    'mode': mode.name,
  };
  if (refresh) queryParameters['refresh'] = 'true';

  final uri = BackendConfig.apiUri('/search', queryParameters: queryParameters);

  final res = await http.get(uri).timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) throw Exception('서버 오류 (${res.statusCode})');

  final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final list = body['reviews'] as List<dynamic>? ?? [];

  return list
      .map((e) => BlogReview.fromApiWithMode(e as Map<String, dynamic>, mode))
      .toList();
}

// ── 화면 ─────────────────────────────────────────────────────────────────────

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState
    extends ConsumerState<RestaurantDetailScreen> {
  _ScreenState _state = _ScreenState.initial;
  List<BlogReview> _reviews = [];
  List<WordFreq> _wordFreqs = [];
  ShopInfo? _shopInfo;

  RestaurantModel get _r => widget.restaurant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDetailTap());
  }

  Future<void> _onDetailTap() async {
    setState(() => _state = _ScreenState.checking); // 로딩 스피너만 표시

    try {
      final mode = ref.read(analysisModeProvider);
      final cached = await _fetchCachedReviews(_r.name, _r.address, mode);

      if (cached.isEmpty) {
        // _onAnalyzeTap() 호출 대신 직접 인라인 처리 (noData/analyzing 상태 스킵)
        try {
          final fresh = await _fetchFreshReviews(_r.name, _r.address, mode);
          _applyReviews(fresh);
        } catch (e) {
          setState(() => _state = _ScreenState.noData);
          _showError('분석 중 오류가 발생했어요: $e');
        }
      } else {
        _applyReviews(cached);
      }
    } catch (e) {
      setState(() => _state = _ScreenState.noData);
      _showError('데이터 조회 중 오류가 발생했어요: $e');
    }
  }

  Future<void> _onAnalyzeTap() async {
    setState(() => _state = _ScreenState.analyzing);

    try {
      final mode = ref.read(analysisModeProvider);
      final fresh = await _fetchFreshReviews(
        _r.name,
        _r.address,
        mode,
        refresh: true,
      );
      _applyReviews(fresh);
    } catch (e) {
      setState(() => _state = _ScreenState.noData);
      _showError('분석 중 오류가 발생했어요: $e');
    }
  }

  void _applyReviews(List<BlogReview> reviews) {
    final shopInfo = ShopInfo.fromApiResponse(
      name: _r.name,
      category: '${_r.category} · ${_r.address}',
      reviews: reviews,
    );
    final wordFreqs =
        WordFreqBuilder.build(reviews.map((r) => r.title).toList());

    setState(() {
      _reviews = reviews;
      _shopInfo = shopInfo;
      _wordFreqs = wordFreqs;
      _state = _ScreenState.loaded;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE85C5C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bookmarkedRestaurants = ref.watch(bookmarkRestaurantsProvider);
    final isBookmarked = bookmarkedRestaurants.any((item) => item.id == _r.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: ref.watch(mainTabIndexProvider),
          onTap: (index) {
            ref.read(mainTabIndexProvider.notifier).state = index;
            Navigator.popUntil(context, (route) => route.isFirst);
          },
          selectedLabelStyle:
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
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
      ),
      body: CustomScrollView(
        slivers: [
          // ── 레스토랑 헤더 ──
          SliverToBoxAdapter(
            child: Column(
              children: [
                RestaurantHeaderWidget(
                  restaurant: _r,
                  isBookmarked: isBookmarked,
                  onCallTap: _copyPhone,
                  onBookmarkTap: _toggleBookmark,
                  onRouteTap: _openPlaceUrl,
                  onShareTap: _copyPlaceUrl,
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── 상태별 콘텐츠 ──
          ..._buildSliverBody(),

          // ── 하단 여백 ──
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Sliver 기반 상태별 본문 ──────────────────────────────────────────────────

  List<Widget> _buildSliverBody() {
    switch (_state) {
      case _ScreenState.initial:
      case _ScreenState.checking:
        return [
          const SliverToBoxAdapter(child: _LoadingIndicator()),
        ];

      case _ScreenState.noData:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: NoDataCard(
                isAnalyzing: false,
                onAnalyzeTap: _onAnalyzeTap,
              ),
            ),
          ),
        ];

      case _ScreenState.analyzing:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: NoDataCard(
                isAnalyzing: true,
                onAnalyzeTap: _onAnalyzeTap,
              ),
            ),
          ),
        ];

      case _ScreenState.loaded:
        return [
          // ── AI 분석 + 워드클라우드 (스크롤하면 사라짐) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 200, // 고정 높이 → 워드클라우드 충분한 공간 확보
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 왼쪽: AI 진실 분석 (40%)
                    Expanded(
                      flex: 4,
                      child: AiAnalysisCard(
                        truthScore: _shopInfo?.trustScore ?? _r.truthScore,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 오른쪽: 리뷰 키워드 워드클라우드 (60%)
                    Expanded(
                      flex: 6,
                      child: _wordFreqs.isNotEmpty
                          ? WordCloudCard(wordFreqs: _wordFreqs)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── 블로그 리스트 (스크롤 이어짐) ──
          if (_shopInfo != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ReviewListSection(
                  shopInfo: _shopInfo!,
                  blogs: _reviews,
                ),
              ),
            ),
        ];
    }
  }

  // ── 유틸 ──────────────────────────────────────────────────────────────────

  Future<void> _copyPhone() async {
    final phone = _r.phone?.trim();
    if (phone == null || phone.isEmpty) {
      _showSnack('등록된 전화번호가 없습니다');
      return;
    }
    await Clipboard.setData(ClipboardData(text: phone));
    _showSnack('전화번호가 복사되었습니다');
  }

  void _toggleBookmark() {
    final previous = ref.read(bookmarkRestaurantsProvider);
    final alreadyBookmarked = previous.any((item) => item.id == _r.id);
    ref.read(bookmarkRestaurantsProvider.notifier).toggle(_r);
    _showSnack(alreadyBookmarked ? '북마크에서 해제되었습니다' : '북마크에 저장했습니다');
  }

  Future<void> _copyPlaceUrl() async {
    final link = _r.placeUrl?.trim();
    if (link == null || link.isEmpty) {
      _showSnack('공유 가능한 링크가 없습니다');
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    _showSnack('링크가 복사되었습니다');
  }

  Future<void> _openPlaceUrl() async {
    final link = _r.placeUrl?.trim();
    if (link == null || link.isEmpty) {
      _showSnack('길찾기 링크가 없습니다');
      return;
    }
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.primary),
        onPressed: () => Navigator.pop(context),
      ),
      leadingWidth: 40,
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.home_outlined,
                size: 20, color: AppColors.primary),
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      centerTitle: true,
      flexibleSpace: Center(
        child: Text(
          _r.name,
          style: AppTextStyles.restaurantName.copyWith(fontSize: 16),
        ),
      ),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFFEEEEEE)),
      ),
    );
  }
}

// ── 로딩 인디케이터 ────────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
