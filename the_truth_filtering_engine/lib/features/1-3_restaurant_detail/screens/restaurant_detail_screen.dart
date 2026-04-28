import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
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
  initial, // 첫 진입
  checking, // Supabase 조회 중
  noData, // 데이터 없음
  analyzing, // 분석하기 눌러서 API 호출 중
  loaded, // 데이터 표시 완료
}

// ── API: Supabase 캐시 조회 ───────────────────────────────────────────────────

Future<List<BlogReview>> _fetchCachedReviews(
    String name, AnalysisMode mode) async {
  final uri = Uri.parse('http://localhost:8000/api/search/cached')
      .replace(queryParameters: {'query': name});

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
    String name, AnalysisMode mode) async {
  final uri =
      Uri.parse('http://localhost:8000/api/search').replace(queryParameters: {
    'query': name,
    'mode': mode.name,
  });

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

  // ── 화면 진입 즉시 Supabase 조회 시작 ────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDetailTap());
  }

  // ── 상세보기 버튼 탭: Supabase 조회 ─────────────────────────────────────────
  Future<void> _onDetailTap() async {
    setState(() => _state = _ScreenState.checking);

    try {
      final mode = ref.read(analysisModeProvider);
      final cached = await _fetchCachedReviews(_r.name, mode);

      if (cached.isEmpty) {
        setState(() => _state = _ScreenState.noData);
      } else {
        _applyReviews(cached);
      }
    } catch (e) {
      setState(() => _state = _ScreenState.noData);
      _showError('데이터 조회 중 오류가 발생했어요: $e');
    }
  }

  // ── 분석하기 버튼 탭: 신규 크롤링 + AI ──────────────────────────────────────
  Future<void> _onAnalyzeTap() async {
    setState(() => _state = _ScreenState.analyzing);

    try {
      final mode = ref.read(analysisModeProvider);
      final fresh = await _fetchFreshReviews(_r.name, mode);
      _applyReviews(fresh);
    } catch (e) {
      setState(() => _state = _ScreenState.noData);
      _showError('분석 중 오류가 발생했어요: $e');
    }
  }

  // ── 공통: 리뷰 데이터 적용 ───────────────────────────────────────────────────
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

  // ── 빌드 ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bookmarkedRestaurants = ref.watch(bookmarkRestaurantsProvider);
    final isBookmarked = bookmarkedRestaurants.any((item) => item.id == _r.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 (항상 표시) ──
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

            // ── 상태별 콘텐츠 ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildBody(),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── 상태별 본문 ───────────────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_state) {
      // 첫 진입 or Supabase 조회 중 → 로딩 표시
      case _ScreenState.initial:
      case _ScreenState.checking:
        return const _LoadingIndicator();

      // 데이터 없음
      case _ScreenState.noData:
        return NoDataCard(
          isAnalyzing: false,
          onAnalyzeTap: _onAnalyzeTap,
        );

      // 분석하기 진행 중
      case _ScreenState.analyzing:
        return NoDataCard(
          isAnalyzing: true,
          onAnalyzeTap: _onAnalyzeTap,
        );

      // 데이터 로드 완료
      case _ScreenState.loaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI 진실 분석 카드
            AiAnalysisCard(truthScore: _shopInfo?.trustScore ?? _r.truthScore),
            const SizedBox(height: 16),

            // 워드클라우드 카드 (단어가 있을 때만)
            if (_wordFreqs.isNotEmpty) ...[
              WordCloudCard(wordFreqs: _wordFreqs),
              const SizedBox(height: 16),
            ],

            // 블로그 리뷰 리스트
            if (_shopInfo != null)
              ReviewListSection(
                shopInfo: _shopInfo!,
                blogs: _reviews,
              ),
          ],
        );
    }
  }

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

    await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
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

  // ── AppBar ────────────────────────────────────────────────────────────────────
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
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              size: 20, color: AppColors.primary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.person_outline_rounded,
              size: 20, color: AppColors.primary),
          onPressed: () {},
        ),
      ],
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFFEEEEEE)),
      ),
    );
  }
}

// ── 로딩 인디케이터 ───────────────────────────────────────────────────────────

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
