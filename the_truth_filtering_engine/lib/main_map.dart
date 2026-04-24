import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/map/screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // Riverpod 루트 스코프
    const ProviderScope(
      child: TruthMapApp(),
    ),
  );
}

class TruthMapApp extends StatelessWidget {
  const TruthMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Truth Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A1A),
          brightness: Brightness.light,
        ),
        fontFamily: 'Pretendard', // pubspec.yaml에 폰트 추가 시 활성화
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MapScreen(),
    );
  }
}
