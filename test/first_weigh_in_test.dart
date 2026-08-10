import 'package:fl_chart/fl_chart.dart';
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

    // Assert the chart itself, not the headline text — the old text-only
    // view also rendered "162", so a text assertion passes even with the
    // LineChart deleted, which is exactly the regression this pins.
    expect(
      find.byType(LineChart),
      findsOneWidget,
      reason: 'the single point must be drawn, not just described',
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ChartHint), findsOneWidget);
  });

  testWidgets('the lone point is centred, not pinned to the left edge', (
    tester,
  ) async {
    await openWeightTab(tester, [162.0]);

    // With one spot fl_chart derives minX == maxX and paints at x = 0 — the
    // plot's left border — putting the dot and its value label half outside
    // the chart. An explicit x window is what centres it.
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final data = chart.data;
    expect(data.minX, lessThan(0));
    expect(data.maxX, greaterThan(0));
    expect(
      (data.minX + data.maxX) / 2,
      closeTo(0, 0.001),
      reason: 'the single spot sits at x=0, so the window must straddle it',
    );
  });

  testWidgets('a flat series is not zoomed differently from a near-flat one', (
    tester,
  ) async {
    // Padding used to branch on range == 0, so 162.0/162.0 and 162.0/162.1
    // rendered at wildly different zoom levels.
    await openWeightTab(tester, [162.0, 162.0]);
    final flat = tester.widget<LineChart>(find.byType(LineChart)).data;
    final flatSpan = flat.maxY - flat.minY;

    await openWeightTab(tester, [162.0, 162.1]);
    final nearFlat = tester.widget<LineChart>(find.byType(LineChart)).data;
    final nearFlatSpan = nearFlat.maxY - nearFlat.minY;

    expect(nearFlatSpan, closeTo(flatSpan, flatSpan * 0.15));
  });

  testWidgets('the gridline interval never collapses', (tester) async {
    await openWeightTab(tester, [162.0]);
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    // Derived from the data's own range, this went to ~0.001 for a flat
    // series and asked for hundreds of gridlines.
    expect(data.gridData.horizontalInterval, greaterThan(0.1));
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
