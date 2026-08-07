import 'package:physiqo_ai/models/readiness_data.dart';
import 'package:physiqo_ai/widgets/physique_mini_card.dart';
import 'package:physiqo_ai/widgets/readiness_card.dart';
import 'package:physiqo_ai/widgets/today_session_card.dart';
import 'package:physiqo_ai/widgets/trend_card.dart';
import 'package:physiqo_ai/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the dashboard cards against RenderFlex overflow. Each card is
/// rendered at the narrowest phone width we support (320dp) and again at
/// 320dp with large system text, using worst-case content (long labels,
/// 4-5 digit numbers) — the combination that actually overflowed.
void main() {
  const narrow = Size(320, 900);

  /// Renders [child] the way TODAY does: inside the screen's 16dp horizontal
  /// page padding, and fails if the frame reported an overflow.
  Future<void> expectNoOverflow(
    WidgetTester tester,
    Widget child, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  // Worst case: 4-digit intake against a 4-digit target, 5-digit volume.
  Widget trendCard() => const TrendCard(
    goal: 'bulk',
    weightLbs: [180.4, 181.2, 182.8, 183.1, 184.6, 185.9, 187.2, 188.0],
    dailyCalories: [3480, 0, 4120, 3990, 2870, 4310, 3760],
    dayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    calorieTarget: 3200,
    weeklyVolume: [88400, 91200, 0, 104300, 98700, 112500, 121800, 133400],
    weeklyStrength: [305, 315, 0, 325, 330, 340, 355, 365],
  );

  Widget physiqueCard() => const PhysiqueMiniCard(
    bodyFat: 24.7,
    score: 100,
    scanCount: 12,
    delta: '-1.8% vs last scan',
    points: [28.4, 27.1, 26.3, 25.0, 24.7],
    // The longest muscle names, which is what the insight lines have to fit.
    focus: ['shoulders', 'hamstrings'],
    strong: ['quadriceps', 'shoulders'],
    muscles: [
      ('shoulders', 4),
      ('hamstrings', 5.5),
      ('chest', 7),
      ('quadriceps', 9),
    ],
  );

  Widget readinessCard() => const ReadinessCard(
    data: ReadinessData(
      score: 100,
      caloriesProgress: 1.0,
      proteinProgress: 1.0,
      sessionsProgress: 1.0,
      fueledValue: '100%',
      caloriesLabel: '4,310 kcal',
      loadValue: '133400',
      loadLabel: 'upper body day',
      proteinValue: '245g',
      proteinTarget: 'of 240g',
      bodyFatValue: '24.7%',
      bodyFatDelta: '-1.8%',
      trainingDetail: 'Trained today ✓',
      fuelDetail: '4,310 of 3,200 kcal today',
      proteinDetail: '245g of 240g today',
    ),
  );

  final cards = <String, Widget Function()>{
    'TrendCard': trendCard,
    'WeekStrip': () => const WeekStrip(
      activity: [true, false, true, true, false, true, true],
      streak: 365,
    ),
    'ReadinessCard': readinessCard,
    'PhysiqueMiniCard': physiqueCard,
    'TodaySessionCard': () => const TodaySessionCard(
      title: 'Upper Push Conditioning',
      meta: '~45 min · AI generated',
      note: 'Tuned to your physique scan',
    ),
  };

  cards.forEach((name, build) {
    testWidgets('$name does not overflow at 320dp', (tester) async {
      await expectNoOverflow(tester, build());
    });

    testWidgets('$name does not overflow at 320dp with large text', (
      tester,
    ) async {
      await expectNoOverflow(tester, build(), textScale: 1.3);
    });
  });

  // The two half-width cards share a row on TODAY, which is where the
  // narrowest constraints in the app come from.
  testWidgets('half-width card row does not overflow at 320dp', (tester) async {
    await expectNoOverflow(
      tester,
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: physiqueCard()),
            const SizedBox(width: 12),
            Expanded(
              child: const TodaySessionCard(
                title: 'Upper Push Conditioning',
                meta: '~45 min · AI generated',
                note: 'Tuned to your physique scan',
              ),
            ),
          ],
        ),
      ),
    );
  });

  // A brand-new account has no data at all — every card renders its empty
  // state, which is what a user actually sees right after onboarding.
  final emptyCards = <String, Widget Function()>{
    'TrendCard': () => const TrendCard(
      goal: 'maintain',
      weightLbs: [],
      dailyCalories: [0, 0, 0, 0, 0, 0, 0],
      dayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      calorieTarget: 2200,
      weeklyVolume: [0],
      weeklyStrength: [],
    ),
    'WeekStrip': () => const WeekStrip(
      activity: [false, false, false, false, false, false, false],
    ),
    'ReadinessCard': () => const ReadinessCard(
      data: ReadinessData(
        score: 0,
        caloriesProgress: 0,
        proteinProgress: 0,
        sessionsProgress: 0,
        fueledValue: '0%',
        caloriesLabel: '0 kcal',
        loadValue: '0',
        loadLabel: 'push day',
        proteinValue: '0g',
        proteinTarget: 'set a goal',
        bodyFatValue: '—',
        bodyFatDelta: '',
        trainingDetail: 'No workout yet today',
        fuelDetail: '0 of 2,200 kcal today',
        proteinDetail: '0g today',
      ),
    ),
    'PhysiqueMiniCard': () => const PhysiqueMiniCard(),
    'TodaySessionCard': () => const TodaySessionCard(
      title: 'Push Session',
      meta: '~45 min · AI generated',
      note: '',
    ),
  };

  emptyCards.forEach((name, build) {
    testWidgets('$name empty state does not overflow at 320dp', (tester) async {
      await expectNoOverflow(tester, build());
    });

    testWidgets('$name empty state does not overflow with large text', (
      tester,
    ) async {
      await expectNoOverflow(tester, build(), textScale: 1.3);
    });
  });

  // The half-width pair as a brand-new account sees it: the physique card has
  // no scan yet, so the two cards' natural heights are very different.
  testWidgets('empty half-width card row does not overflow', (tester) async {
    await expectNoOverflow(
      tester,
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: emptyCards['PhysiqueMiniCard']!()),
            const SizedBox(width: 12),
            Expanded(child: emptyCards['TodaySessionCard']!()),
          ],
        ),
      ),
    );
  });

  // The insight lines fill what was dead space under the sparkline, so they
  // must actually render — and only when the scan has something to say.
  testWidgets('physique card shows what the scan found', (tester) async {
    await expectNoOverflow(tester, physiqueCard());

    expect(find.textContaining('Focus', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('shoulders, hamstrings', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Strong', findRichText: true), findsOneWidget);
  });

  testWidgets('physique card omits insights when the scan has none', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      const PhysiqueMiniCard(bodyFat: 24.7, score: 80, scanCount: 2),
    );

    expect(find.textContaining('Focus', findRichText: true), findsNothing);
    expect(find.textContaining('Strong', findRichText: true), findsNothing);
  });

  // Muscle detail is what fills the card's lower half; the names must render
  // in full rather than being clipped to "should…".
  testWidgets('physique card lists muscle scores in full', (tester) async {
    await expectNoOverflow(tester, physiqueCard());

    expect(find.text('shoulders'), findsOneWidget);
    expect(find.text('hamstrings'), findsOneWidget);
    expect(find.text('quadriceps'), findsOneWidget);
  });

  // One weigh-in is a real answer — the card used to nag for a second entry
  // instead of showing the weight it already had.
  testWidgets('weight tab shows a single weigh-in instead of nagging', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      const TrendCard(
        goal: 'cut',
        weightLbs: [162.0],
        dailyCalories: [1, 1, 1, 1, 1, 1, 1],
        dayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        calorieTarget: 2200,
        weeklyVolume: [100],
      ),
    );

    await tester.tap(find.text('WEIGHT'));
    await tester.pumpAndSettle();

    expect(find.textContaining('162'), findsOneWidget);
    expect(find.textContaining('two entries'), findsNothing);
  });

  // Each trend tab renders a different chart+header combination.
  testWidgets('every TrendCard tab does not overflow at 320dp', (tester) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: trendCard(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in ['WEIGHT', 'VOLUME', 'STRENGTH', 'CALORIES']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tab tab overflowed');
    }
  });
}
