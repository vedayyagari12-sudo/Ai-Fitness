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

      expect(dataOf(tester).sections, hasLength(3));
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

      final v = dataOf(tester).sections.map((s) => s.value).toList();
      expect(v[0], 400);
      expect(v[1], 400);
      expect(v[2], 900);
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

      final sections = dataOf(tester).sections;
      expect(sections, isNotEmpty, reason: 'sumValue reduces over this list');
      expect(
        sections.fold<double>(0, (a, s) => a + s.value),
        greaterThan(0),
        reason: 'a zero sum paints nothing and the card looks broken',
      );
      expect(tester.takeException(), isNull);
    });

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

      final sections = dataOf(tester).sections;
      expect(sections, hasLength(3));
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
        expect(tester.takeException(), isNull, reason: 'grams were $bad');
        expect(
          dataOf(tester).sections.fold<double>(0, (a, s) => a + s.value),
          greaterThan(0),
        );
      }
    });
  });

  group('the card', () {
    testWidgets('reports grams and share for all three macros', (tester) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 180, carbsG: 210, fatG: 62)),
      );

      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FAT'), findsOneWidget);
      // 720 / 840 / 558 kcal of 2118.
      expect(find.text('180g · 34%'), findsOneWidget);
      expect(find.text('210g · 40%'), findsOneWidget);
      expect(find.text('62g · 26%'), findsOneWidget);
    });

    testWidgets('leads with the day energy the ring divides', (tester) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 180, carbsG: 210, fatG: 62)),
      );

      expect(find.text('2118'), findsOneWidget);
      expect(find.text('KCAL'), findsOneWidget);
    });

    testWidgets('an empty day prompts rather than showing a false zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 0, carbsG: 0, fatG: 0)),
      );

      expect(find.textContaining('Scan a meal'), findsOneWidget);
      // "0g · 0%" three times would read as a logged day of nothing.
      expect(find.textContaining('0g · 0%'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the takeaway follows the goal', (tester) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 67.5, carbsG: 125, fatG: 25.5)),
      );
      expect(find.textContaining('27%'), findsWidgets);
    });

    testWidgets('names each macro in text, not by colour alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const FuelCard(proteinG: 100, carbsG: 100, fatG: 100)),
      );
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
            // Worst case: three-digit grams in every row.
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
