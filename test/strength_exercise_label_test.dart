import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/widgets/trend_card.dart';

/// A 1-rep max number on its own says nothing about which lift it describes,
/// and the estimate can come from a different exercise each week — so the
/// card names the lift behind the most recent bar.
void main() {
  Future<void> openStrengthTab(
    WidgetTester tester, {
    required List<double> strength,
    List<String> exercises = const [],
  }) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TrendCard(
              goal: 'bulk',
              weightLbs: const [180, 181],
              dailyCalories: const [1, 1, 1, 1, 1, 1, 1],
              dayLabels: const [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ],
              calorieTarget: 2200,
              weeklyVolume: const [100],
              weeklyStrength: strength,
              strengthExercises: exercises,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('STRENGTH'));
    await tester.pumpAndSettle();
  }

  testWidgets('names the lift behind the latest estimate', (tester) async {
    await openStrengthTab(
      tester,
      strength: [225, 245, 315],
      exercises: ['Bench Press', 'Squat', 'Deadlift'],
    );

    expect(find.textContaining('Deadlift'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says the bars are each week\'s best lift, not one exercise', (
    tester,
  ) async {
    // Without this the chart looks like a single lift's progression, and a
    // week topped by squats next to one topped by bench reads as a decline.
    await openStrengthTab(
      tester,
      strength: [225, 315],
      exercises: ['Bench Press', 'Deadlift'],
    );

    expect(find.textContaining('best lift each week'), findsOneWidget);
  });

  testWidgets('falls back to the plain value when no lift is known', (
    tester,
  ) async {
    // Older cached workout rows may carry no exercise name.
    await openStrengthTab(tester, strength: [225, 245], exercises: const []);

    expect(find.textContaining('lbs this week'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mismatched name list is ignored rather than mislabelling', (
    tester,
  ) async {
    // Showing the wrong lift is worse than showing none, so the guard is on
    // the whole list's length, not on an index.
    await openStrengthTab(
      tester,
      strength: [225, 245, 315],
      exercises: ['Bench Press'],
    );

    expect(find.textContaining('Bench Press'), findsNothing);
    expect(find.textContaining('lbs this week'), findsOneWidget);
  });

  testWidgets('an empty exercise name does not leave a dangling separator', (
    tester,
  ) async {
    await openStrengthTab(
      tester,
      strength: [225, 245],
      exercises: ['Bench Press', ''],
    );

    expect(find.textContaining('lbs ·'), findsNothing);
    expect(find.textContaining('lbs this week'), findsOneWidget);
  });
}
