import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/widgets/trend_card.dart';

/// The 1RM chart follows a single lift and names it. An unlabelled number
/// tells the user nothing about what it measures, and a chart that mixed
/// lifts week to week made a squat week beside a curl week look like a
/// collapse in strength.
void main() {
  Future<void> openStrengthTab(
    WidgetTester tester, {
    required List<double> strength,
    String exercise = '',
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
              strengthExercise: exercise,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('STRENGTH'));
    await tester.pumpAndSettle();
  }

  testWidgets('names the lift the chart is following', (tester) async {
    await openStrengthTab(
      tester,
      strength: [225, 245, 315],
      exercise: 'Deadlift',
    );

    expect(find.textContaining('Deadlift'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to a plain title when no lift qualifies', (
    tester,
  ) async {
    // Nothing logged with both a weight and reps, so there is no lift to
    // name — but the card must still render rather than showing "· ".
    await openStrengthTab(tester, strength: [225, 245]);

    expect(find.textContaining('Estimated 1-Rep Max'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long exercise name does not overflow the card', (
    tester,
  ) async {
    await openStrengthTab(
      tester,
      strength: [225, 245],
      exercise: 'Bulgarian Split Squat (Rear Foot Elevated)',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a gap week renders without breaking the chart', (tester) async {
    // A week the tracked lift was not performed is a genuine zero.
    await openStrengthTab(
      tester,
      strength: [225, 0, 245],
      exercise: 'Bench Press',
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Bench Press'), findsOneWidget);
  });
}
