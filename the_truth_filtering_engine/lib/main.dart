import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/map/screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 네이버 지도 SDK 초기화
  // ⚠️  AndroidManifest.xml / Info.plist에 클라이언트 ID 설정 필요
  await NaverMapSdk.instance.initialize(
    clientId: 'r4m59pfq3y', // <- 발급받은 ID로 교체
    onAuthFailed: (error) {
      debugPrint('NaverMap 인증 실패: $error');
    },
  );

  runApp(
    // Riverpod 루트 스코프
    const ProviderScope(child: TruthMapApp()),
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
