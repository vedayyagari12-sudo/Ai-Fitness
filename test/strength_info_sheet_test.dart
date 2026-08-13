import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/widgets/trend_card.dart';

/// The 1RM sheet is the only place the chart's behaviour is explained — that
/// it follows one lift, how that lift is chosen, and that an empty week is a
/// gap rather than lost strength. It is long, so it also has to survive a
/// short screen without overflowing.
void main() {
  Future<void> openInfoSheet(WidgetTester tester, {Size? screen}) async {
    tester.view.physicalSize = screen ?? const Size(360, 900);
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
              weeklyStrength: const [225, 245],
              strengthExercise: 'Bench Press',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('STRENGTH'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('explains how the tracked lift is chosen', (tester) async {
    await openInfoSheet(tester);

    expect(find.text('WHICH LIFT THIS CHART FOLLOWS'), findsOneWidget);
    // The selection rule, including the tie-break, so nobody has to guess
    // why it settled on the lift it did.
    expect(find.textContaining('most separate weeks'), findsOneWidget);
    expect(find.textContaining('follows the heavier one'), findsOneWidget);
    expect(find.textContaining('Log a different exercise'), findsOneWidget);
  });

  testWidgets('explains that an empty week is a gap, not lost strength', (
    tester,
  ) async {
    await openInfoSheet(tester);

    expect(find.text('READING THE CHART'), findsOneWidget);
    expect(find.textContaining('not that you got weaker'), findsOneWidget);
  });

  testWidgets('still explains the formula it is built on', (tester) async {
    await openInfoSheet(tester);

    expect(find.textContaining('Est. 1RM = Weight'), findsOneWidget);
    expect(find.text('EXAMPLE'), findsOneWidget);
  });

  testWidgets('scrolls instead of overflowing on a short screen', (
    tester,
  ) async {
    // The sheet grew well past half the screen; without scrolling the
    // closing sections would simply be cut off.
    await openInfoSheet(tester, screen: const Size(360, 560));

    expect(tester.takeException(), isNull);

    // The last section must be reachable by scrolling the sheet.
    await tester.dragUntilVisible(
      find.text('READING THE CHART'),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -80),
    );
    expect(find.text('READING THE CHART'), findsOneWidget);
  });
}
