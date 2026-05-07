import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/1-1_map/screens/truth_map_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TruthGuardApp(),
    ),
  );
}

class TruthGuardApp extends StatelessWidget {
  const TruthGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '진실의 입',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorSchemeSeed: const Color(0xFF2B54E8),
      ),
      home: const TruthMapScreen(),
    );
  }
}
