import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:physiqo_ai/models/readiness_data.dart';
import 'package:physiqo_ai/theme/app_theme.dart';
import 'package:physiqo_ai/theme/theme_controller.dart';
import 'package:physiqo_ai/widgets/fuel_card.dart';
import 'package:physiqo_ai/widgets/muscle_radar.dart';
import 'package:physiqo_ai/widgets/readiness_card.dart';
import 'package:physiqo_ai/widgets/streak_chip.dart';
import 'package:physiqo_ai/widgets/trend_card.dart';

import 'store_cards.dart';
import 'store_fonts.dart';
import 'store_shell.dart';

/// Renders the Play Store screenshots from the app's OWN widgets.
///
/// These are not mockups. The readiness ring, the trend chart, the macro
/// donut, the muscle radar, the week strip and the streak chip are the exact
/// classes the app builds on a device, given sample data instead of a live
/// account, drawn by the real Flutter engine in the real dark theme.
///
/// Regenerate with:  flutter test test/store --update-goldens
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
    // Let the ring and donut entrance animations finish before capturing.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../store_assets/$name.png'),
    );
  }

  /// Page body taking a ready-made header widget — used by the TODAY shots,
  /// which carry the app's real greeting block rather than a plain title.
  Widget pageWithHeader({
    required Widget header,
    required List<Widget> children,
    required int tab,
  }) => Column(
    children: [
      const SizedBox(height: 14),
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

  /// Page body shared by the remaining shots: title, content, bottom nav.
  Widget page({
    required String title,
    Widget? trailing,
    required List<Widget> children,
    required int tab,
  }) => Column(
    children: [
      const SizedBox(height: 14),
      ShotHeader(title: title, trailing: trailing),
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
      pageWithHeader(
        header: const ShotGreetingHeader(
          dateLabel: 'THU · SEP 3',
          greeting: 'Good evening',
          avatarInitial: 'V',
          streak: StreakChip(count: 12, isKeptToday: true),
        ),
        tab: 0,
        children: const [
          // WeekStrip is deliberately absent. The readiness card runs the
          // full height of a 640dp viewport on its own, and with the strip
          // above it the card's bottom stat row was sliced off behind the
          // nav bar. The streak still shows, in the header chip.
          ReadinessCard(data: readiness),
        ],
      ),
    );
  });

  testWidgets('04 trends', (tester) async {
    await shoot(
      tester,
      '04_screenshot_trends',
      light: true,
      pageWithHeader(
        header: const ShotGreetingHeader(
          dateLabel: 'THU · SEP 3',
          greeting: 'Good evening',
          avatarInitial: 'V',
          streak: StreakChip(count: 12, isKeptToday: true),
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
          // Nothing below the chart. The FuelCard needs ~300dp and the
          // WeekStrip ~113dp against the ~85dp the chart leaves, so both
          // landed sliced. A focused single-card shot beats a cropped one.
        ],
      ),
    );
  });

  testWidgets('05 physique scan', (tester) async {
    await shoot(
      tester,
      '05_screenshot_physique_scan',
      page(
        title: 'Scan result',
        tab: 2,
        children: [
          const ShotScoreCard(),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              gradient: kHeroCardGradient(kSteel),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGlassBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MUSCLE BALANCE', style: kLabelSmall),
                const SizedBox(height: 8),
                const MuscleRadar(
                  readings: [
                    (label: 'Chest', score: 7.8),
                    (label: 'Back', score: 8.4),
                    (label: 'Shoulders', score: 7.1),
                    (label: 'Arms', score: 6.9),
                    (label: 'Core', score: 7.5),
                    (label: 'Legs', score: 6.2),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  });

  testWidgets('06 food scan', (tester) async {
    await shoot(
      tester,
      '06_screenshot_food_scan',
      page(
        title: 'Meal logged',
        tab: 1,
        children: const [
          ShotMealCard(),
          SizedBox(height: 14),
          FuelCard(
            proteinG: 52,
            carbsG: 64,
            fatG: 21,
            goal: 'bulk',
            loggedCalories: 653,
          ),
        ],
      ),
    );
  });

  testWidgets('07 workout', (tester) async {
    await shoot(
      tester,
      '07_screenshot_workout',
      page(
        title: 'Push day',
        tab: 3,
        children: const [
          ShotWorkoutMeta(),
          SizedBox(height: 12),
          ShotExerciseRow(
            name: 'Barbell Bench Press',
            sets: '4 x 8',
            load: '185 lb',
          ),
          ShotExerciseRow(
            name: 'Incline Dumbbell Press',
            sets: '3 x 10',
            load: '65 lb',
          ),
          ShotExerciseRow(
            name: 'Overhead Press',
            sets: '4 x 8',
            load: '115 lb',
          ),
          ShotExerciseRow(
            name: 'Cable Lateral Raise',
            sets: '3 x 12',
            load: '25 lb',
          ),
          // Five rows, not six: the sixth landed half-behind the nav bar.
          ShotExerciseRow(name: 'Dips', sets: '3 x 10', load: 'Bodyweight'),
        ],
      ),
    );
  });
}
