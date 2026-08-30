import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/theme/app_theme.dart';
import 'package:physiqo_ai/widgets/trend_card.dart';

/// Each tab's chart form is a claim about what the data is: bars and a line
/// for series over time, and no ring anywhere, because "volume in week -3" is
/// not a share of a whole. This pins that, so a later restyle cannot quietly
/// swap a form — and so the macro ring stays on its own card.
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: TrendCard(
                goal: 'bulk',
                weightLbs: [180.4, 182.8, 184.6, 187.2],
                dailyCalories: [3480, 0, 4120, 3990, 2870, 4310, 3760],
                dayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                calorieTarget: 3200,
                weeklyVolume: [88400, 91200, 0, 104300],
                weeklyStrength: [305, 315, 0, 325],
                strengthExercise: 'Deadlift',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('the three count-over-time tabs are bar charts', (tester) async {
    await pump(tester);
    for (final tab in ['CALORIES', 'VOLUME', 'STRENGTH']) {
      await openTab(tester, tab);
      expect(
        find.byType(BarChart),
        findsOneWidget,
        reason: '$tab lost its bars',
      );
      expect(find.byType(PieChart), findsNothing, reason: '$tab grew a ring');
    }
  });

  testWidgets('weight stays a line chart', (tester) async {
    await pump(tester);
    await openTab(tester, 'WEIGHT');
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);
  });

  testWidgets('no tab carries a ring', (tester) async {
    // A part-to-whole ring belongs to the macro card. Here it would claim
    // these series sum to something meaningful, which they do not.
    await pump(tester);
    for (final tab in ['CALORIES', 'WEIGHT', 'VOLUME', 'STRENGTH']) {
      await openTab(tester, tab);
      expect(find.byType(PieChart), findsNothing, reason: tab);
    }
  });

  testWidgets('bars sit in a track so a short bar reads as short', (
    tester,
  ) async {
    // Without a track the bars float as scattered marks, and the stub that
    // means "nothing logged" is indistinguishable from no bar at all.
    await pump(tester);
    for (final tab in ['CALORIES', 'VOLUME', 'STRENGTH']) {
      await openTab(tester, tab);
      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      for (final group in data.barGroups) {
        for (final rod in group.barRods) {
          expect(
            rod.backDrawRodData.show,
            isTrue,
            reason: '$tab has a rod with no track',
          );
          // The track must stop at the data, not at maxY: maxY carries label
          // headroom, and a track drawn to it stands proud of every bar and
          // reads as though each one were failing a target.
          expect(
            rod.backDrawRodData.toY,
            lessThan(data.maxY),
            reason: '$tab track runs into the label headroom',
          );
        }
      }
    }
  });

  testWidgets('a day OVER its calorie target is coloured as on target', (
    tester,
  ) async {
    // The reported bug: with a 3,200 target, days at 3,480 / 3,990 / 4,310
    // were all marked as misses because the old rule scored distance from
    // the target in either direction. Beating a bulking goal is the goal
    // being met. This asserts the chart actually consults the shared rule —
    // testing calorieStatus alone cannot catch the chart ignoring it.
    await pump(tester);
    await openTab(tester, 'CALORIES');

    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    // Fixture: [3480, 0, 4120, 3990, 2870, 4310, 3760] against a 3200 target.
    const over = [0, 2, 3, 5, 6];
    for (final i in over) {
      final rod = data.barGroups[i].barRods.first;
      final colour = rod.gradient?.colors.last ?? rod.color;
      expect(
        colour,
        ChartFill.green,
        reason: 'bar $i is over target but is not coloured as on target',
      );
    }
  });

  testWidgets('a day well SHORT of target is still marked under', (
    tester,
  ) async {
    // The rule must not have become "everything is fine".
    await pump(tester);
    await openTab(tester, 'CALORIES');
    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    // Index 4 is 2,870 against 3,200 — 90%, so "close" rather than green.
    final rod = data.barGroups[4].barRods.first;
    final colour = rod.gradient?.colors.last ?? rod.color;
    expect(colour, isNot(ChartFill.green));
  });

  testWidgets('only the newest weight reading is dotted', (tester) async {
    await pump(tester);
    await openTab(tester, 'WEIGHT');

    final bar = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData
        .first;
    final shown = bar.spots
        .where((s) => bar.dotData.checkToShowDot(s, bar))
        .toList();
    expect(
      shown,
      hasLength(1),
      reason: 'a dot on every point turns a long history into a dotted band',
    );
    expect(shown.single.x, bar.spots.last.x);
  });

  testWidgets('value labels wear text ink, not the series colour', (
    tester,
  ) async {
    // The bar already carries the on/off-target signal; tinting the number
    // too spends legibility on information the chart has shown twice.
    await pump(tester);
    await openTab(tester, 'CALORIES');

    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    final colours = <Color?>{};
    for (final group in data.barGroups) {
      final item = data.barTouchData.touchTooltipData.getTooltipItem(
        group,
        0,
        group.barRods.first,
        0,
      );
      if (item != null) colours.add(item.textStyle.color);
    }
    expect(
      colours.length,
      lessThanOrEqualTo(2),
      reason: 'labels are taking one colour per status: $colours',
    );
  });
}
