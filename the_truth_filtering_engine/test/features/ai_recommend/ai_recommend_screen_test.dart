import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truth_mouth/core/theme/app_theme.dart';
import 'package:truth_mouth/features/1-1_map/models/map_point.dart';
import 'package:truth_mouth/features/1-1_map/providers/map_provider.dart';
import 'package:truth_mouth/features/3_ai_recommend/providers/ai_recommend_provider.dart';
import 'package:truth_mouth/features/3_ai_recommend/screens/ai_recommend_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows current region labels as scope buttons', (tester) async {
    late FakeAiRecommendNotifier notifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLocationProvider.overrideWith(
            (ref) => const MapPoint(latitude: 37.3, longitude: 127.0),
          ),
          aiRecommendProvider.overrideWith((ref) {
            notifier = FakeAiRecommendNotifier(
              ref,
              const AiRecommendState(
                isLoading: false,
                currentRegionSi: '경기도',
                currentRegionGu: '수원시 영통구',
                currentRegionDong: '이의동',
                currentRegionLabel: '경기도 수원시 영통구 이의동',
                isRegionFiltered: true,
              ),
            );
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AiRecommendScreen(onViewPlace: (_) {}),
          ),
        ),
      ),
    );

    expect(find.text('경기도'), findsOneWidget);
    expect(find.text('수원시 영통구'), findsOneWidget);
    expect(find.text('이의동'), findsOneWidget);

    await tester.tap(find.text('이의동'));
    await tester.pump();

    expect(notifier.selectedScope, AiRegionScope.dong);
    expect(notifier.state.regionScope, AiRegionScope.dong);
    expect(notifier.state.page, 1);
  });

  testWidgets('hides scope buttons when current region is unavailable',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLocationProvider.overrideWith((ref) => null),
          aiRecommendProvider.overrideWith(
            (ref) => FakeAiRecommendNotifier(
              ref,
              const AiRecommendState(isLoading: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AiRecommendScreen(onViewPlace: (_) {}),
          ),
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('현재 위치를 확인하면 지역별 추천이 적용됩니다.'), findsOneWidget);
  });
}

class FakeAiRecommendNotifier extends AiRecommendNotifier {
  AiRegionScope? selectedScope;

  FakeAiRecommendNotifier(super.ref, AiRecommendState initialState) {
    state = initialState;
  }

  @override
  Future<void> changeRegionScope(AiRegionScope regionScope) async {
    selectedScope = regionScope;
    state = state.copyWith(regionScope: regionScope, page: 1);
  }

  @override
  Future<void> reloadForCurrentLocation() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNextPage() async {}

  @override
  Future<void> loadPreviousPage() async {}
}
