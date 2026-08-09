import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/theme/app_widgets.dart';
import 'package:physiqo_ai/widgets/trend_card.dart';

/// A first weigh-in is real data, but one dot with no line to connect to
/// reads as a broken chart. These pin that the point is drawn, that the
/// explanation appears with it, and that both give way to the trend line as
/// soon as there is something to connect.
void main() {
  Widget card(List<double> weights) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TrendCard(
          goal: 'cut',
          weightLbs: weights,
          dailyCalories: const [1, 1, 1, 1, 1, 1, 1],
          dayLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          calorieTarget: 2200,
          weeklyVolume: const [100],
        ),
      ),
    ),
  );

  Future<void> openWeightTab(WidgetTester tester, List<double> w) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(card(w));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WEIGHT'));
    await tester.pumpAndSettle();
  }

  testWidgets('a single weigh-in still draws a chart, not just text', (
    tester,
  ) async {
    await openWeightTab(tester, [162.0]);

    // The chart has to render: hiding it made a saved log look like nothing
    // had happened. A zero-range series also used to collapse the grid
    // interval toward zero, so this catches that too.
    expect(tester.takeException(), isNull);
    expect(find.byType(ChartHint), findsOneWidget);
    expect(find.textContaining('162'), findsWidgets);
  });

  testWidgets('the first weigh-in explains what happens next', (tester) async {
    await openWeightTab(tester, [162.0]);

    expect(find.textContaining('check back'), findsOneWidget);
    expect(find.textContaining('trend'), findsWidgets);
  });

  testWidgets('the hint disappears once a line can be drawn', (tester) async {
    await openWeightTab(tester, [162.0, 161.4]);

    expect(
      find.byType(ChartHint),
      findsNothing,
      reason: 'with two points the line explains itself',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('identical weights do not break the chart', (tester) async {
    // Same value twice is still zero range — the degenerate case that would
    // pin the line to the axis and over-draw the grid.
    await openWeightTab(tester, [162.0, 162.0, 162.0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no weigh-ins shows the prompt and no chart hint', (
    tester,
  ) async {
    await openWeightTab(tester, const []);

    expect(find.byType(ChartHint), findsNothing);
    expect(find.textContaining('Log your bodyweight'), findsOneWidget);
  });
}
