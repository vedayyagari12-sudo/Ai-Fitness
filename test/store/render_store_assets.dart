import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:physiqo_ai/models/readiness_data.dart';
import 'package:physiqo_ai/theme/theme_controller.dart';
import 'package:physiqo_ai/widgets/readiness_card.dart';
import 'package:physiqo_ai/widgets/streak_chip.dart';
import 'package:physiqo_ai/widgets/trend_card.dart';
import 'package:physiqo_ai/widgets/week_strip.dart';

import 'store_fonts.dart';
import 'store_shell.dart';

/// Renders the two TODAY screenshots for the Play listing.
///
/// Only these two are rendered. The other four shots in store_assets/ are
/// genuine device captures, prepared by tool/process_real_screenshots.py —
/// real pixels beat a reproduction every time. These two are the exception
/// because the captures of them show an empty account (0 kcal, "Fresh start —
/// nothing logged yet"), and populating a readiness ring means redrawing it.
///
/// What is drawn here IS the app: ReadinessCard, TrendCard, WeekStrip and
/// StreakChip are the exact classes a device builds, inside the real
/// AmbientBackground, in the real theme and the real Outfit/Inter faces. Only
/// the data is sample data.
///
/// Regenerate with:  flutter test test/store/render_store_assets.dart --update-goldens
void main() {
  setUpAll(() async {
    await loadStoreFonts();
    ThemeController.mode.value = ThemeMode.dark;
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    bool light = false,
  }) async {
    tester.view.physicalSize = Size(
      kShotLogical.width * kShotDpr,
      kShotLogical.height * kShotDpr,
    );
    tester.view.devicePixelRatio = kShotDpr;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(storeApp(child, light: light));
    // Let the ring and chart entrance animations finish before capturing.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../store_assets/$name.png'),
    );
  }

  Widget page({
    required Widget header,
    required List<Widget> children,
    required int tab,
    double topGap = 14,
  }) => Column(
    children: [
      SizedBox(height: topGap),
      header,
      Expanded(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(children: children),
        ),
      ),
      ShotNavBar(activeIndex: tab),
    ],
  );

  const header = ShotGreetingHeader(
    dateLabel: 'THU · SEP 3',
    greeting: 'Good evening',
    avatarInitial: 'V',
    streak: StreakChip(count: 12, isKeptToday: true),
  );

  testWidgets('03 dashboard', (tester) async {
    const readiness = ReadinessData(
      score: 82,
      caloriesProgress: 0.86,
      proteinProgress: 0.91,
      sessionsProgress: 1.0,
      fueledValue: '86%',
      caloriesLabel: '2,380 kcal',
      loadValue: '14,850',
      loadLabel: 'push day',
      proteinValue: '164g',
      proteinTarget: 'of 180g',
      bodyFatValue: '16.4%',
      bodyFatDelta: '-0.8%',
      trainingDetail: '3 of 4 sessions this week',
      fuelDetail: '2,380 of 2,766 kcal today',
      proteinDetail: '164g of 180g today',
    );

    await shoot(
      tester,
      '03_screenshot_dashboard',
      page(
        header: header,
        tab: 0,
        // The readiness card alone fills a 640dp viewport; anything above it
        // pushed its bottom stat row off behind the nav bar. The streak still
        // shows, in the header chip.
        children: const [ReadinessCard(data: readiness)],
      ),
    );
  });

  testWidgets('04 trends', (tester) async {
    await shoot(
      tester,
      '04_screenshot_trends',
      light: true,
      page(
        // Dense header and almost no top gap: the chart leaves ~101dp below
        // it and the week strip needs ~127dp with its spacing. Reclaiming
        // that 26dp of padding is what lets the strip sit there whole,
        // instead of the shot ending in a 300px band of empty page.
        topGap: 2,
        header: const ShotGreetingHeader(
          dateLabel: 'THU · SEP 3',
          greeting: 'Good evening',
          avatarInitial: 'V',
          streak: StreakChip(count: 12, isKeptToday: true),
          dense: true,
        ),
        tab: 0,
        children: const [
          TrendCard(
            goal: 'bulk',
            weightLbs: [178.2, 179.6, 181.0, 182.4, 183.6],
            dailyCalories: [2840, 2610, 2960, 2740, 3050, 2380, 2880],
            dayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            calorieTarget: 2766,
            weeklyVolume: [82400, 88100, 91600, 96200],
            weeklyStrength: [295, 305, 310, 325],
            strengthExercise: 'Deadlift',
          ),
          SizedBox(height: 12),
          WeekStrip(
            activity: [true, true, false, true, true, false, true],
            streak: 12,
          ),
        ],
      ),
    );
  });
}
