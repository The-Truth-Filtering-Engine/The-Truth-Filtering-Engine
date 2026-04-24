import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/search_screen.dart';
import 'widgets/common_widgets.dart';

void main() {
  runApp(const TruthMouthApp());
}

class TruthMouthApp extends StatelessWidget {
  const TruthMouthApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '진실의 입',
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

  // 탭별 화면 (현재 구현된 것: 검색 / 나머지는 준비 중 플레이스홀더)
  final _screens = const [
    SearchScreen(),
    _PlaceholderScreen(icon: Icons.map_outlined,     label: 'AI Insights'),
    _PlaceholderScreen(icon: Icons.bar_chart_rounded, label: 'Feed'),
    _PlaceholderScreen(icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          selectedLabelStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              label: 'AI Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Feed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderScreen({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: AppBarLogo()),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('$label 화면',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text('준비 중이에요',
              style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}
