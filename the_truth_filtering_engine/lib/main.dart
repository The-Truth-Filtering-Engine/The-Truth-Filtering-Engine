import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/design_system/widgets/widgets.dart';
import 'core/theme/app_theme.dart';
import 'features/1-1_map/models/restaurant_model.dart';
import 'features/1-1_map/providers/map_provider.dart';
import 'features/1-1_map/screens/map_screen.dart';
import 'features/1-1_map/screens/bookmark_screen.dart';
import 'features/2_recent_analysis/screens/recent_analysis_screen.dart';
import 'features/3_ai_recommend/screens/ai_recommend_screen.dart';
import 'features/4_setting/screens/settings_screen.dart';
import 'features/0-1_auth/screens/login_screen.dart'; // ← 추가

final mainTabIndexProvider = StateProvider<int>((ref) => 0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  runApp(const ProviderScope(child: TruthMouthApp()));
}

class TruthMouthApp extends StatelessWidget {
  const TruthMouthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Truth Filtering Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginSignupScreen(), // ← MainShell() 에서 변경
    );
  }
}

// ── 로그인 성공 후 이동할 메인 화면 ─────────────────────────────────────────

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  void _showRestaurantOnMap(RestaurantModel restaurant) {
    ref.read(mapFocusRestaurantProvider.notifier).state = restaurant;
    ref.read(selectedRestaurantProvider.notifier).state = restaurant;
    ref.read(mainTabIndexProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: GestureDetector(
          onTap: () {
            // 탭 0번(탐색/홈)으로 이동
            ref.read(mainTabIndexProvider.notifier).state = 0;
          },
          child: const DsAppLogo(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.border),
        ),
      ),
      body: IndexedStack(
        index: ref.watch(mainTabIndexProvider),
        children: [
          MapScreen(
            onOpenSettings: () {
              ref.read(mainTabIndexProvider.notifier).state = 4;
            },
          ),
          BookmarkScreen(onViewPlace: _showRestaurantOnMap),
          RecentAnalysisScreen(onViewPlace: _showRestaurantOnMap),
          AiRecommendScreen(onViewPlace: _showRestaurantOnMap),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: ref.watch(mainTabIndexProvider),
          onTap: (index) =>
              ref.read(mainTabIndexProvider.notifier).state = index,
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
    );
  }
}
