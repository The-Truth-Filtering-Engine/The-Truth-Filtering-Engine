import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/analysis_mode_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(analysisModeProvider);
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '광고 판별 방식',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.memory,
                      color: currentMode == AnalysisMode.model
                          ? color
                          : Colors.grey),
                  title: const Text('AI 모델'),
                  subtitle: const Text('파인튜닝된 언어 모델로 판별'),
                  trailing: currentMode == AnalysisMode.model
                      ? Icon(Icons.check_circle, color: color)
                      : const Icon(Icons.radio_button_unchecked,
                          color: Colors.grey),
                  onTap: () => ref.read(analysisModeProvider.notifier).state =
                      AnalysisMode.model,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.psychology,
                      color: currentMode == AnalysisMode.llm
                          ? color
                          : Colors.grey),
                  title: const Text('LLM (GPT)'),
                  subtitle: const Text('GPT로 판별'),
                  trailing: currentMode == AnalysisMode.llm
                      ? Icon(Icons.check_circle, color: color)
                      : const Icon(Icons.radio_button_unchecked,
                          color: Colors.grey),
                  onTap: () => ref.read(analysisModeProvider.notifier).state =
                      AnalysisMode.llm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
