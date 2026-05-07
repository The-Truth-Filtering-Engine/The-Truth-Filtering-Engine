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
import 'package:truth_mouth/models/blog_review_model.dart';
import '../../../core/providers/analysis_mode_provider.dart';
import '../widgets/restaurant_header_widget.dart';
import '../widgets/ai_analysis_card.dart';
import '../widgets/word_cloud_card.dart';
import '../widgets/no_data_card.dart';
import '../widgets/review_list_section.dart';

// ?Ä?Ä ?îÎ©¥ ?ÅÌÉú ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

enum _ScreenState {
  initial,
  checking,
  noData,
  analyzing,
  loaded,
}

// ?Ä?Ä API: Supabase Ï∫êÏãú Ï°∞Ìöå ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

Future<List<BlogReviewModel>> _fetchCachedReviews(
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
      .map((e) => BlogReviewModel.fromApiWithMode(e as Map<String, dynamic>, mode))
      .toList();
}

// ?Ä?Ä API: ?†Í∑ú ?¨Î°§Îß?+ AI Î∂ÑÏÑù ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

Future<List<BlogReviewModel>> _fetchFreshReviews(
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
  if (res.statusCode != 200) throw Exception('?úÎ≤Ñ ?§Î•ò (${res.statusCode})');

  final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final list = body['reviews'] as List<dynamic>? ?? [];

  return list
      .map((e) => BlogReviewModel.fromApiWithMode(e as Map<String, dynamic>, mode))
      .toList();
}

// ?Ä?Ä ?îÎ©¥ ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

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
  List<BlogReviewModel> _reviews = [];
  List<WordFreq> _wordFreqs = [];
  ShopInfo? _shopInfo;

  RestaurantModel get _r => widget.restaurant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDetailTap());
  }

  Future<void> _onDetailTap() async {
    setState(() => _state = _ScreenState.checking); // Î°úÎî© ?§Ìîº?àÎßå ?úÏãú

    try {
      final mode = ref.read(analysisModeProvider);
      final cached = await _fetchCachedReviews(_r.name, _r.address, mode);

      if (cached.isEmpty) {
        // _onAnalyzeTap() ?∏Ï∂ú ?Ä??ÏßÅÏ†ë ?∏Îùº??Ï≤òÎ¶¨ (noData/analyzing ?ÅÌÉú ?§ÌÇµ)
        try {
          final fresh = await _fetchFreshReviews(_r.name, _r.address, mode);
          _applyReviews(fresh);
        } catch (e) {
          setState(() => _state = _ScreenState.noData);
          _showError('Î∂ÑÏÑù Ï§??§Î•òÍ∞Ä Î∞úÏÉù?àÏñ¥?? $e');
        }
      } else {
        _applyReviews(cached);
      }
    } catch (e) {
      setState(() => _state = _ScreenState.noData);
      _showError('?∞Ïù¥??Ï°∞Ìöå Ï§??§Î•òÍ∞Ä Î∞úÏÉù?àÏñ¥?? $e');
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
      _showError('Î∂ÑÏÑù Ï§??§Î•òÍ∞Ä Î∞úÏÉù?àÏñ¥?? $e');
    }
  }

  void _applyReviews(List<BlogReviewModel> reviews) {
    final shopInfo = ShopInfo.fromApiResponse(
      name: _r.name,
      category: '${_r.category} ¬∑ ${_r.address}',
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

  // ?Ä?Ä ÎπåÎìú ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

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
              label: '?êÏÉâ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border_rounded),
              activeIcon: Icon(Icons.bookmark_rounded),
              label: 'Î∂ÅÎßà??,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome_rounded),
              label: 'AI Ï∂îÏ≤ú',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: '?§Ï†ï',
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ?Ä?Ä ?àÏä§?†Îûë ?§Îçî ?Ä?Ä
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

          // ?Ä?Ä ?ÅÌÉúÎ≥?ÏΩòÌÖêÏ∏??Ä?Ä
          ..._buildSliverBody(),

          // ?Ä?Ä ?òÎã® ?¨Î∞± ?Ä?Ä
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ?Ä?Ä Sliver Í∏∞Î∞ò ?ÅÌÉúÎ≥?Î≥∏Î¨∏ ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

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
          // ?Ä?Ä AI Î∂ÑÏÑù + ?åÎìú?¥Îùº?∞Îìú (Í∞ÄÎ°?Î∞∞Ïπò Î≥µÍµ¨) ?Ä?Ä
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ?ºÏ™Ω: AI ÏßÑÏã§ Î∂ÑÏÑù (40% ÎπÑÏú®)
                  Expanded(
                    flex: 4,
                    child: AiAnalysisCard(
                      truthScore: _shopInfo?.trustScore ?? _r.truthScore,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ?§Î•∏Ï™? Î¶¨Î∑∞ ?§Ïõå???åÎìú?¥Îùº?∞Îìú (60% ÎπÑÏú®)
                  Expanded(
                    flex: 6,
                    child: _wordFreqs.isNotEmpty
                        ? SizedBox(
                            height: 260, // AiAnalysisCard ?íÏù¥??ÎßûÏ∂§
                            child: WordCloudCard(wordFreqs: _wordFreqs),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ?Ä?Ä Î∏îÎ°úÍ∑?Î¶¨Ïä§??(?§ÌÅ¨Î°??¥Ïñ¥Ïß? ?Ä?Ä
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

  // ?Ä?Ä ?†Ìã∏ ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

  Future<void> _copyPhone() async {
    final phone = _r.phone?.trim();
    if (phone == null || phone.isEmpty) {
      _showSnack('?±Î°ù???ÑÌôîÎ≤àÌò∏Í∞Ä ?ÜÏäµ?àÎã§');
      return;
    }
    await Clipboard.setData(ClipboardData(text: phone));
    _showSnack('?ÑÌôîÎ≤àÌò∏Í∞Ä Î≥µÏÇ¨?òÏóà?µÎãà??);
  }

  void _toggleBookmark() {
    final previous = ref.read(bookmarkRestaurantsProvider);
    final alreadyBookmarked = previous.any((item) => item.id == _r.id);
    ref.read(bookmarkRestaurantsProvider.notifier).toggle(_r);
    _showSnack(alreadyBookmarked ? 'Î∂ÅÎßà?¨Ïóê???¥Ï†ú?òÏóà?µÎãà?? : 'Î∂ÅÎßà?¨Ïóê ?Ä?•Ìñà?µÎãà??);
  }

  Future<void> _copyPlaceUrl() async {
    final link = _r.placeUrl?.trim();
    if (link == null || link.isEmpty) {
      _showSnack('Í≥µÏú† Í∞Ä?•Ìïú ÎßÅÌÅ¨Í∞Ä ?ÜÏäµ?àÎã§');
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    _showSnack('ÎßÅÌÅ¨Í∞Ä Î≥µÏÇ¨?òÏóà?µÎãà??);
  }

  Future<void> _openPlaceUrl() async {
    final link = _r.placeUrl?.trim();
    if (link == null || link.isEmpty) {
      _showSnack('Í∏∏Ï∞æÍ∏?ÎßÅÌÅ¨Í∞Ä ?ÜÏäµ?àÎã§');
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

  // ?Ä?Ä AppBar ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

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

// ?Ä?Ä Î°úÎî© ?∏ÎîîÏºÄ?¥ÌÑ∞ ?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä?Ä

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

