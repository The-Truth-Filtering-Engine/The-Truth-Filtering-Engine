import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/1-1_map/screens/map_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TruthMouthApp(),
    ),
  );
}

class TruthMouthApp extends StatelessWidget {
  const TruthMouthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Truth Filtering Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MapScreen(),
    _PlaceholderScreen(icon: Icons.history_rounded,       label: '기록'),
    _PlaceholderScreen(icon: Icons.auto_awesome_outlined, label: 'AI 추천'),
    _PlaceholderScreen(icon: Icons.settings_outlined,     label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // ── 추가된 공통 앱바 ───────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // 좌측: 로고 마크 + 서비스명
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: CircleAvatar(
                  radius: 5,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '진실의 입',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary900,
              ),
            ),
          ],
        ),
        // 우측: 알림 버튼 + 프로필 아이콘
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {},
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary50,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: AppColors.primary500,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.border),
        ),
      ),
      // ── 여기까지 추가 ──────────────────────────

      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedLabelStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: '탐색',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: '기록',
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

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('$label 화면',
            style: const TextStyle(
              fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          const Text('준비 중이에요',
            style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        ],
      ),
    );
  }
}