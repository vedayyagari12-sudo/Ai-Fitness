import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/macro_split.dart';
import 'package:physiqo_ai/widgets/fuel_card.dart';
import 'package:physiqo_ai/widgets/macro_donut.dart';

/// fl_chart's pie is unforgiving in two separate ways, and only one of them
/// announces itself: an empty section list throws out of PieChartData.sumValue,
/// while a list whose values sum to zero paints nothing at all and leaves a
/// card that looks broken rather than empty. A day with no food logged is the
/// ordinary first-run state, so both paths are load-bearing.
///
/// The ring also now grows in over ~1s on first paint (see macro_donut.dart),
/// so every test that reads section values, the centre number, or the ring's
/// own size settles the animation first with pumpAndSettle() — otherwise it
/// is reading an in-between frame, not the widget's actual output.
void main() {
  Widget host(Widget child, {double width = 320, TextScaler? scaler}) =>
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: scaler ?? TextScaler.noScaling),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: width - 32, child: child),
              ),
            ),
          ),
        ),
      );

  PieChartData dataOf(WidgetTester tester) =>
      tester.widget<PieChart>(find.byType(PieChart)).data;

  group('the ring itself', () {
    testWidgets('draws one slice per macro', (tester) async {
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 180, carbsG: 210, fatG: 62),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Three macros plus the transparent reveal slice that drives the
      // entrance; it settles to zero but stays in the list.
      expect(dataOf(tester).sections, hasLength(4));
    });

    testWidgets('slices are sized by energy, not by grams', (tester) async {
      // 100g of each: fat contributes 900 kcal against 400, so its slice must
      // be more than twice either other. A gram-weighted ring would show
      // three equal thirds for a day that is more than half fat.
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 100, carbsG: 100, fatG: 100),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final v = dataOf(tester).sections.map((s) => s.value).toList();
      expect(v[0], closeTo(400, 0.01));
      expect(v[1], closeTo(400, 0.01));
      expect(v[2], closeTo(900, 0.01));
      expect(v[3], closeTo(0, 0.01), reason: 'reveal slice should be spent');
    });

    /// What fl_chart actually paints: the angle each slice occupies, as a
    /// fraction of a full turn. Asserting on raw section VALUES is what let
    /// a completely no-op entrance animation pass for a whole session — a
    /// common factor on every value cancels out of `value / sumValue`, so
    /// the values changed frame to frame while the drawn ring never did.
    List<double> sweepFractions(WidgetTester tester) {
      final sections = dataOf(tester).sections;
      final sum = sections.fold<double>(0, (a, s) => a + s.value);
      if (sum <= 0) return List<double>.filled(sections.length, 0);
      return [for (final s in sections) s.value / sum];
    }

    testWidgets('the visible arc actually sweeps open, not just its values', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 100, carbsG: 100, fatG: 100),
          ),
        ),
      );

      // Frame one: the three real slices occupy almost none of the circle.
      final start = sweepFractions(
        tester,
      ).take(3).fold<double>(0, (a, b) => a + b);
      expect(
        start,
        lessThan(0.5),
        reason: 'the ring painted its final shape immediately',
      );

      // Mid-flight: strictly more of the circle than at the start.
      await tester.pump(const Duration(milliseconds: 300));
      final mid = sweepFractions(
        tester,
      ).take(3).fold<double>(0, (a, b) => a + b);
      expect(mid, greaterThan(start));

      // Settled: the three real slices own the entire circle.
      await tester.pumpAndSettle();
      final end = sweepFractions(
        tester,
      ).take(3).fold<double>(0, (a, b) => a + b);
      expect(end, closeTo(1.0, 0.001));
      expect(end, greaterThan(mid));
    });

    testWidgets('the circle is never empty, including on frame one', (
      tester,
    ) async {
      // Scaling all three values by a t that starts at 0 makes sumValue 0,
      // and fl_chart then paints nothing at all — a blank card on the first
      // frame of every populated day.
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 180, carbsG: 210, fatG: 62),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        final sum = dataOf(
          tester,
        ).sections.fold<double>(0, (a, s) => a + s.value);
        expect(sum, greaterThan(0), reason: 'nothing would paint at frame $i');
        await tester.pump(const Duration(milliseconds: 130));
      }
    });

    testWidgets('the reveal slice is gone once the entrance finishes', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 180, carbsG: 210, fatG: 62),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(dataOf(tester).sections.last.value, closeTo(0, 0.001));
    });

    testWidgets('an empty day still yields a positive-valued section', (
      tester,
    ) async {
      // Both halves matter. Zero sections throws; three zero-valued sections
      // do not throw but paint an invisible ring.
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 0, carbsG: 0, fatG: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sections = dataOf(tester).sections;
      expect(sections, isNotEmpty, reason: 'sumValue reduces over this list');
      expect(
        sections.fold<double>(0, (a, s) => a + s.value),
        greaterThan(0),
        reason: 'a zero sum paints nothing and the card looks broken',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'an empty day stays a flat placeholder through the whole animation',
      (tester) async {
        // isEmpty must key off the real data, not the animation clock — a
        // moving `t` must never flip which branch this takes.
        await tester.pumpWidget(
          host(
            MacroDonut(
              split: MacroSplit.fromGrams(proteinG: 0, carbsG: 0, fatG: 0),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 150));
          expect(dataOf(tester).sections, hasLength(1));
          expect(dataOf(tester).sections.single.value, 1);
        }
      },
    );

    testWidgets('the centre radius is finite', (tester) async {
      // Left at its default of infinity, fl_chart derives one by reducing
      // over the sections — the same unguarded reduce again.
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 0, carbsG: 0, fatG: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dataOf(tester).centerSpaceRadius.isFinite, isTrue);
    });

    testWidgets('touch is disabled', (tester) async {
      // The touch handler reads sumValue, which is the throwing path.
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 10, carbsG: 0, fatG: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dataOf(tester).pieTouchData.enabled, isFalse);
    });

    testWidgets('colours stay pinned to their macro when one drops to zero', (
      tester,
    ) async {
      // The slice list keeps its length so fl_chart's implicit animation
      // lerps positionally. Filtering zero slices out would let carbs take
      // the protein colour the moment a fat-only meal was logged.
      await tester.pumpWidget(
        host(
          MacroDonut(
            split: MacroSplit.fromGrams(proteinG: 0, carbsG: 0, fatG: 40),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sections = dataOf(tester).sections;
      expect(sections, hasLength(4));
      expect(sections[0].color, MacroDonut.proteinColor);
      expect(sections[1].color, MacroDonut.carbsColor);
      expect(sections[2].color, MacroDonut.fatColor);
    });

    testWidgets('garbage grams cannot reach the chart', (tester) async {
      for (final bad in [double.nan, double.infinity, -50.0]) {
        await tester.pumpWidget(
          host(
            MacroDonut(
              split: MacroSplit.fromGrams(
                proteinG: bad,
                carbsG: bad,
                fatG: bad,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'grams were $bad');
        expect(
          dataOf(tester).sections.fold<double>(0, (a, s) => a + s.value),
          greaterThan(0),
        );
      }
    });
  });

  group('the ring closes the gap beside it', () {
    // The donut used to share a Row with a legend column beside it and was
    // pinned to a fixed 116dp regardless of card width, so any phone wider
    // than the narrowest one left a strip of untouched card down the side.
    // It is centred and sized off the card's own width now.

    double donutDiameter(WidgetTester tester) =>
        tester.getSize(find.byType(MacroDonut)).width;

    testWidgets('at the narrowest supported phone it holds the floor', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 180, carbsG: 210, fatG: 62), width: 320),
      );
      await tester.pumpAndSettle();
      expect(donutDiameter(tester), 160.0);
    });

    testWidgets('a wider phone gets a visibly bigger ring, not a bigger gap', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 180, carbsG: 210, fatG: 62), width: 420),
      );
      await tester.pumpAndSettle();
      expect(donutDiameter(tester), greaterThan(160.0));
    });

    testWidgets('growth is capped rather than unbounded', (tester) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 180, carbsG: 210, fatG: 62), width: 900),
      );
      await tester.pumpAndSettle();
      expect(donutDiameter(tester), 200.0);
    });

    testWidgets('nothing sits beside the ring wide enough to be a legend', (
      tester,
    ) async {
      // Regression guard for the actual bug report: the ring's own centre
      // (where it sits horizontally) should track the card centre, not be
      // pushed left by a column occupying the other half of the row.
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 180, carbsG: 210, fatG: 62), width: 400),
      );
      await tester.pumpAndSettle();

      final cardCentre = tester.getCenter(find.byType(FuelCard)).dx;
      final donutCentre = tester.getCenter(find.byType(MacroDonut)).dx;
      expect(donutCentre, closeTo(cardCentre, 1.0));
    });
  });

  group('the card', () {
    testWidgets('reports grams and share for all three macros', (tester) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 180, carbsG: 210, fatG: 62)),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FAT'), findsOneWidget);
      // 720 / 840 / 558 kcal of 2118.
      expect(find.text('180g'), findsOneWidget);
      expect(find.text('34%'), findsOneWidget);
      expect(find.text('210g'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('62g'), findsOneWidget);
      expect(find.text('26%'), findsOneWidget);
    });

    testWidgets('leads with the day energy the ring divides', (tester) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 180, carbsG: 210, fatG: 62)),
      );
      await tester.pumpAndSettle();

      expect(find.text('2118'), findsOneWidget);
      expect(find.text('KCAL'), findsOneWidget);
    });

    testWidgets('an empty day prompts rather than showing a false zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 0, carbsG: 0, fatG: 0)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan a meal'), findsOneWidget);
      // "0g" three times would read as a logged day of nothing.
      expect(find.text('0g'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the takeaway follows the goal', (tester) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 67.5, carbsG: 125, fatG: 25.5)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('27%'), findsWidgets);
    });

    testWidgets('names each macro in text, not by colour alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 100, carbsG: 100, fatG: 100)),
      );
      await tester.pumpAndSettle();
      for (final name in ['PROTEIN', 'CARBS', 'FAT']) {
        expect(find.text(name), findsOneWidget);
      }
    });
  });

  group('layout', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('fits a 320dp phone at ${scale}x text', (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            // Worst case: three-digit grams in every column.
            const FuelCard(proteinG: 245, carbsG: 512, fatG: 180),
            scaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('fits a 320dp phone when empty at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            const FuelCard(proteinG: 0, carbsG: 0, fatG: 0),
            scaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('fits a wide phone at the ring size cap at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(430, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            const FuelCard(proteinG: 245, carbsG: 512, fatG: 180),
            width: 430,
            scaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the centre number stays inside the ring at large text', (
      tester,
    ) async {
      // The hole is fixed geometry, so the centre text is pinned to no
      // scaling and wrapped in a FittedBox. Without that, a 1.3x setting
      // pushes the number out over the slices.
      await tester.pumpWidget(
        host(
          const FuelCard(proteinG: 400, carbsG: 400, fatG: 200),
          scaler: const TextScaler.linear(1.3),
        ),
      );
      await tester.pumpAndSettle();

      final donut = tester.getSize(find.byType(MacroDonut));
      final centre = tester.getSize(
        find.ancestor(of: find.text('KCAL'), matching: find.byType(FittedBox)),
      );
      expect(
        centre.width,
        lessThan(donut.width * 0.68),
        reason: 'centre content is wider than the hole',
      );
    });
  });
}
