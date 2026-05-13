import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AnalysisMode { model, llm }

final analysisModeProvider = StateProvider<AnalysisMode>(
  (ref) => AnalysisMode.model, // 기본값
);
