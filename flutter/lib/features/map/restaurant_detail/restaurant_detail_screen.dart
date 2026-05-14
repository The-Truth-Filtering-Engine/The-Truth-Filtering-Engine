import 'dart:async';
import 'dart:convert';
import '../../../core/providers/recent_visit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/config/test_account_auth_config.dart';
import '../../../core/providers/current_user_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../bookmarks/bookmark_provider.dart';
import '../models/restaurant_model.dart';
import '../../recent_analysis/recent_analysis_provider.dart';
import 'providers/blog_review.dart';
import '../../../core/providers/analysis_mode_provider.dart';
import 'widgets/restaurant_header_widget.dart';
import 'widgets/ai_analysis_card.dart';
import 'widgets/word_cloud_card.dart';
import 'widgets/no_data_card.dart';
import 'widgets/review_list_section.dart';

// ── 화면 상태 ─────────────────────────────────────────────────────────────────

enum _ScreenState { initial, checking, noData, analyzing, loaded }

const int _reviewBatchSize = 100;
const int _maxReviewResults = 100;

class _ReviewFetchResult {
  final List<BlogReview> reviews;
  final bool hasMore;

  const _ReviewFetchResult({required this.reviews, required this.hasMore});
}

class _SseBatch {
  final List<BlogReview> reviews;
  final bool done;

  const _SseBatch({required this.reviews, required this.done});
}

class _AnalysisRequestException implements Exception {
  final String message;
  final int statusCode;

  const _AnalysisRequestException(this.message, this.statusCode);

  @override
  String toString() => message;
}

// ── API: Supabase 캐시 조회 ───────────────────────────────────────────────────

Future<_ReviewFetchResult> _fetchCachedReviews(
  RestaurantModel restaurant,
  AnalysisMode mode,
  Map<String, String> authHeaders,
) async {
  final uri = BackendConfig.apiUri(
    '/search/cached',
    queryParameters: _reviewQueryParameters(
      restaurant,
      limit: '$_maxReviewResults',
    ),
  );

  final res = await http
      .get(
        uri,
        headers: authHeaders.isEmpty ? null : authHeaders,
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 402) {
    throw _AnalysisRequestException(
      _readApiError(res) ?? '추가분석을 위해 코인을 충전해 주세요',
      res.statusCode,
    );
  }
  if (res.statusCode != 200) {
    return const _ReviewFetchResult(reviews: [], hasMore: false);
  }

  final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final list = body['reviews'] as List<dynamic>? ?? [];
  if (list.isEmpty) {
    return const _ReviewFetchResult(reviews: [], hasMore: false);
  }

  return _ReviewFetchResult(
    reviews: list
        .map((e) => BlogReview.fromApiWithMode(e as Map<String, dynamic>, mode))
        .toList(),
    hasMore: body['hasMore'] as bool? ?? list.length >= _reviewBatchSize,
  );
}

// ── API: SSE 스트리밍 ─────────────────────────────────────────────────────────

Stream<_SseBatch> _streamFreshReviews(
  RestaurantModel restaurant,
  AnalysisMode mode, {
  required Map<String, String> authHeaders,
  bool refresh = false,
  int naverStart = 1,
}) async* {
  final params = _reviewQueryParameters(
    restaurant,
    extra: {
      'mode': mode.name,
      'naverStart': '$naverStart',
      'limit': '$_reviewBatchSize',
      'maxResults': '$_maxReviewResults',
      if (refresh) 'refresh': 'true',
    },
  );

  final uri = BackendConfig.apiUri('/search/stream', queryParameters: params);
  final request = http.Request('GET', uri);
  if (authHeaders.isNotEmpty) {
    request.headers.addAll(authHeaders);
  }

  final client = http.Client();
  try {
    // 헤더 수신까지 타임아웃
    final response =
        await client.send(request).timeout(const Duration(seconds: 30));

    if (response.statusCode == 402) {
      final body = await response.stream.bytesToString();
      throw _AnalysisRequestException(
          _readApiErrorFromString(body) ?? '추가분석을 위해 코인을 충전해 주세요', 402);
    }
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw _AnalysisRequestException(
          _readApiErrorFromString(body) ?? '서버 오류 (${response.statusCode})',
          response.statusCode);
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final json = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      final done = json['done'] as bool? ?? false;
      final rawList = json['reviews'] as List<dynamic>? ?? [];
      final reviews = rawList
          .map((e) =>
              BlogReview.fromApiWithMode(e as Map<String, dynamic>, mode))
          .toList();
      yield _SseBatch(reviews: reviews, done: done);
      if (done) break;
    }
  } finally {
    client.close();
  }
}

String? _parseApiError(String text) {
  try {
    if (text.isEmpty) return null;
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      final detail = decoded['detail']?.toString().trim();
      if (detail != null && detail.isNotEmpty) return detail;
    }
  } catch (_) {}
  return null;
}

String? _readApiError(http.Response r) =>
    _parseApiError(utf8.decode(r.bodyBytes));

String? _readApiErrorFromString(String body) => _parseApiError(body);

Map<String, String> _reviewQueryParameters(
  RestaurantModel restaurant, {
  String? limit,
  Map<String, String> extra = const {},
}) {
  final params = <String, String>{
    'query': restaurant.name,
    'address': restaurant.address,
    ...extra,
  };
  if (limit != null) params['limit'] = limit;

  void addIfNotBlank(String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) params[key] = trimmed;
  }

  addIfNotBlank('storeId', restaurant.effectiveStoreId);
  addIfNotBlank('categoryName', restaurant.category);
  addIfNotBlank('phone', restaurant.phone);
  addIfNotBlank('addressName', restaurant.address);
  addIfNotBlank('roadAddressName', restaurant.address);
  addIfNotBlank('placeUrl', restaurant.placeUrl);

  return params;
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
  bool _hasMoreReviewBatches = false;
  bool _isLoadingReviewBatch = false;
  StreamSubscription<_SseBatch>? _streamSub;

  RestaurantModel get _r => widget.restaurant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onDetailTap();
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _onDetailTap() async {
    if (!mounted) return;
    setState(() => _state = _ScreenState.checking);

    try {
      final mode = ref.read(analysisModeProvider);
      final authHeaders = _currentAuthHeaders();
      final cached = await _fetchCachedReviews(_r, mode, authHeaders);
      if (!mounted) return;

      // hasMore: false이면 캐시가 완전한 상태 (리뷰가 적은 가게도 포함)
      final shouldLoadFirstBatch = cached.reviews.isEmpty || cached.hasMore;

      if (!shouldLoadFirstBatch) {
        _applyReviews(cached);
        return;
      }

      setState(() => _state = _ScreenState.analyzing);
      _startStream(mode, refresh: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _ScreenState.noData);
      _showError('데이터 조회 중 오류가 발생했어요: $e');
    }
  }

  Future<void> _onAnalyzeTap() async {
    if (!mounted) return;
    setState(() => _state = _ScreenState.analyzing);
    _startStream(ref.read(analysisModeProvider), refresh: true);
  }

  void _startStream(AnalysisMode mode, {required bool refresh}) {
    _streamSub?.cancel();
    final authHeaders = _currentAuthHeaders();
    _streamSub = _streamFreshReviews(
      _r,
      mode,
      authHeaders: authHeaders,
      refresh: refresh,
    )
        // 이벤트 간 90초 타임아웃 (총 스트림 시간이 아니라 이벤트 간 간격 기준)
        .timeout(const Duration(seconds: 90))
        .listen(
      (batch) {
        if (batch.done) {
          _finalizeStream();
        } else {
          _appendBatch(batch.reviews);
        }
      },
      onError: (e) {
        if (!mounted) return;
        if (_isUsageRequiredError(e)) {
          setState(() => _state = _ScreenState.noData);
          _showError(_errorMessage(e, '분석 중 오류가 발생했어요'));
          return;
        }
        if (_reviews.isNotEmpty) {
          _refreshRecentAnalyses(); // 부분 성공 시에도 이력 갱신
          _showError('추가 리뷰를 불러오지 못했습니다: $e');
        } else {
          setState(() => _state = _ScreenState.noData);
          _showError('분석 중 오류가 발생했어요: $e');
        }
      },
      onDone: () {
        // done: true 없이 스트림이 닫힌 경우 방어 처리
        if (mounted && _shopInfo == null && _reviews.isNotEmpty) {
          _finalizeStream();
        }
      },
    );
  }

  // 중간 배치: 리뷰 누적 + 목록 즉시 표시
  void _appendBatch(List<BlogReview> incoming) {
    if (!mounted || incoming.isEmpty) return;
    setState(() {
      _reviews = _mergeReviews(_reviews, incoming);
      _state = _ScreenState.loaded;
    });
  }

  // 스트림 완료: 요약 정보 최종 계산
  void _finalizeStream() {
    if (!mounted || _reviews.isEmpty) return;
    final shopInfo = ShopInfo.fromApiResponse(
      name: _r.name,
      category: '${_r.category} · ${_r.address}',
      reviews: _reviews,
    );
    final wordFreqs =
        WordFreqBuilder.build(_reviews.map((r) => r.title).toList());
    setState(() {
      _shopInfo = shopInfo;
      _wordFreqs = wordFreqs;
      _hasMoreReviewBatches = false;
      _isLoadingReviewBatch = false;
    });
    _refreshRecentAnalyses();
  }

  List<BlogReview> _mergeReviews(
    List<BlogReview> current,
    List<BlogReview> incoming,
  ) {
    final byKey = <String, BlogReview>{};
    for (final review in current) {
      byKey[review.url.isNotEmpty ? review.url : 'id:${review.id}'] = review;
    }
    for (final review in incoming) {
      byKey[review.url.isNotEmpty ? review.url : 'id:${review.id}'] = review;
    }
    return byKey.values.toList();
  }

  void _applyReviews(_ReviewFetchResult result) {
    if (!mounted) return;
    final reviews = result.reviews;

    if (reviews.isEmpty) {
      setState(() {
        _reviews = const [];
        _shopInfo = null;
        _wordFreqs = const [];
        _hasMoreReviewBatches = false;
        _isLoadingReviewBatch = false;
        _state = _ScreenState.noData;
      });
      return;
    }

    final merged = _mergeReviews(_reviews, reviews);

    final shopInfo = ShopInfo.fromApiResponse(
      name: _r.name,
      category: '${_r.category} · ${_r.address}',
      reviews: merged,
    );
    final wordFreqs = WordFreqBuilder.build(
      merged.map((r) => r.title).toList(),
    );

    setState(() {
      _reviews = merged;
      _shopInfo = shopInfo;
      _wordFreqs = wordFreqs;
      _hasMoreReviewBatches =
          result.hasMore && merged.length < _maxReviewResults;
      _isLoadingReviewBatch = false;
      _state = _ScreenState.loaded;
    });
    _refreshRecentAnalyses();
  }

  void _refreshRecentAnalyses() {
    if (!mounted) return;
    Future.microtask(() => ref.read(recentAnalysesProvider.notifier).load());
  }

  Map<String, String> _currentAuthHeaders() {
    final authState = ref.read(appAuthProvider);
    return TestAccountAuthConfig.headers(
      isTestAccountLogin: authState.isTestAccountLogin,
    );
  }

  Future<bool> _recordRecentReviewOpen(BlogReview review) async {
    final reviewId = review.reviewId?.trim();
    if (reviewId == null || reviewId.isEmpty) {
      debugPrint('Recent visit save skipped: reviewId is required');
      _showSnack('리뷰 id가 없어 최근 기록에 저장하지 못했습니다');
      return false;
    }

    try {
      await ref.read(recentVisitProvider.notifier).addReview(
            reviewId: reviewId,
            name: _r.name,
            reviewUrl: review.url,
            reviewTitle: review.title,
            reviewDescription:
                review.content.isNotEmpty ? review.content : review.preview,
          );
      return true;
    } catch (error) {
      debugPrint('Recent visit save failed: $error');
      _showSnack('최근 기록에 저장하지 못했습니다');
      return false;
    }
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

  bool _isUsageRequiredError(Object error) {
    return error is _AnalysisRequestException && error.statusCode == 402;
  }

  String _errorMessage(Object error, String fallbackPrefix) {
    if (error is _AnalysisRequestException) {
      return error.message;
    }
    return '$fallbackPrefix: $error';
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bookmarkedRestaurants = ref.watch(bookmarkRestaurantsProvider);
    final isBookmarked = bookmarkedRestaurants.any(
      (item) => item.effectiveStoreId == _r.effectiveStoreId,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: ref.watch(mainTabIndexProvider),
          onTap: (index) {
            ref.read(mainTabIndexProvider.notifier).state = index;
            Navigator.popUntil(context, (route) => route.isFirst);
          },
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
        return [const SliverToBoxAdapter(child: _LoadingIndicator())];

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
              child: NoDataCard(isAnalyzing: true, onAnalyzeTap: _onAnalyzeTap),
            ),
          ),
        ];

      case _ScreenState.loaded:
        return [
          // ── AI 분석 + 워드클라우드 (스크롤하면 사라짐) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final aiCard = AiAnalysisCard(
                    truthScore: _shopInfo?.trustScore ?? _r.truthScore,
                  );
                  final wordCloud = _wordFreqs.isNotEmpty
                      ? WordCloudCard(wordFreqs: _wordFreqs)
                      : const _WordCloudSkeleton();
                  final isNarrow = constraints.maxWidth < 640;

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [aiCard, const SizedBox(height: 12), wordCloud],
                    );
                  }

                  return SizedBox(
                    height: 220,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: aiCard),
                        const SizedBox(width: 12),
                        Expanded(flex: 6, child: wordCloud),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── 블로그 리스트 (스크롤 이어짐) ──
          if (_reviews.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ReviewListSection(
                  shopInfo: _shopInfo,
                  blogs: _reviews,
                  hasMoreReviews: _hasMoreReviewBatches,
                  isLoadingReviewBatch: _isLoadingReviewBatch,
                  onRequestReviewBatch: null,
                  onReviewTap: _recordRecentReviewOpen,
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
    final alreadyBookmarked = previous.any(
      (item) => item.effectiveStoreId == _r.effectiveStoreId,
    );
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
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.primary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      leadingWidth: 40,
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

// ── 워드클라우드 스켈레톤 ──────────────────────────────────────────────────────

class _WordCloudSkeleton extends StatelessWidget {
  const _WordCloudSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
          160, // narrow 레이아웃 점프 방지. wide는 SizedBox(height:220)+stretch로 자동 조정
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4EC), width: 0.5),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
