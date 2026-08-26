import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/models/readiness_data.dart';
import 'package:physiqo_ai/widgets/readiness_card.dart';

/// Marks the ring's own CustomPaint. `find.byType(CustomPaint)` is not
/// enough to identify it — Material's internals (splashes, ink, shadows)
/// plant several CustomPaints of their own, and a bare `.first` can grab one
/// of those instead depending on tree order, which is what happened here
/// first: the "ancestor SizedBox" it found belonged to an unrelated widget.
Finder _ringPaint() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is ReadinessRingPainter,
);

/// The ring used to be a fixed 176dp regardless of card width, which left a
/// wide dead strip either side of it on anything wider than the narrowest
/// supported phone. It is now sized off the card's real width; these tests
/// pin that it actually grows, stays bounded, and never regresses the
/// narrow-phone case that used to be the only one tested.
void main() {
  const populated = ReadinessData(
    score: 68,
    caloriesProgress: 0.7,
    proteinProgress: 0.55,
    sessionsProgress: 1.0,
    fueledValue: '84%',
    caloriesLabel: '1,840 kcal',
    loadValue: '133400',
    loadLabel: 'upper body day',
    proteinValue: '142g',
    proteinTarget: 'of 160g',
    bodyFatValue: '18.2%',
    bodyFatDelta: '-0.6%',
    trainingDetail: '1 of 4 sessions this week',
    fuelDetail: '1,840 of 2,200 kcal today',
    proteinDetail: '142g of 160g today',
  );

  Widget host(double width, {double textScale = 1.0}) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: width - 32,
            child: const ReadinessCard(data: populated),
          ),
        ),
      ),
    ),
  );

  /// Reads the declared width straight off the SizedBox that sizes the
  /// ring, rather than measuring a rendered RenderBox — the SizedBox states
  /// the diameter build() computed as a property, so this can't be fooled
  /// by an unrelated widget of the same rendered size.
  double ringDiameter(WidgetTester tester) {
    final sizedBox = tester.widget<SizedBox>(
      find.ancestor(of: _ringPaint(), matching: find.byType(SizedBox)).first,
    );
    expect(sizedBox.width, sizedBox.height, reason: 'the ring is not square');
    return sizedBox.width!;
  }

  group('the ring grows with the card instead of leaving a dead strip', () {
    testWidgets(
      'at the narrowest supported phone it matches the old fixed size',
      (tester) async {
        // 320dp screen, 16dp page padding each side, 16dp card padding each
        // side -> 256dp of content. This is the floor: nothing above this
        // width should ever render a SMALLER ring than the card used to have
        // everywhere.
        await tester.pumpWidget(host(320));
        await tester.pumpAndSettle();
        expect(ringDiameter(tester), 176.0);
      },
    );

    testWidgets('a mid-size phone gets a visibly bigger ring', (tester) async {
      await tester.pumpWidget(host(390));
      await tester.pumpAndSettle();
      expect(ringDiameter(tester), greaterThan(176.0));
    });

    testWidgets('growth is capped rather than unbounded', (tester) async {
      // AmbientBackground caps page content at 560dp; even so, the ring must
      // not grow to dominate a very wide card the way it would on an
      // uncapped desktop window.
      await tester.pumpWidget(host(900));
      await tester.pumpAndSettle();
      expect(ringDiameter(tester), 224.0);
    });

    testWidgets('diameter increases monotonically with width', (tester) async {
      final widths = [320.0, 360.0, 420.0, 500.0, 700.0];
      final diameters = <double>[];
      for (final w in widths) {
        await tester.pumpWidget(host(w));
        await tester.pumpAndSettle();
        diameters.add(ringDiameter(tester));
      }
      for (var i = 1; i < diameters.length; i++) {
        expect(
          diameters[i],
          greaterThanOrEqualTo(diameters[i - 1]),
          reason: 'diameters were $diameters for widths $widths',
        );
      }
    });
  });

  group('overflow', () {
    testWidgets('the widest ring size does not overflow at 1.3x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(390, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a 6-digit LOAD value at the biggest stat font still fits at 320dp/1.3x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host(320, textScale: 1.3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('the takeaway line renders and stays on the card', (
    tester,
  ) async {
    await tester.pumpWidget(host(390));
    await tester.pumpAndSettle();
    // Trained (1.0), calories 0.7, protein 0.55 -> "only trained" branch.
    // The full sentence, not a substring: the ring-colour legend below
    // separately labels a ring "Trained today", so a loose match on that
    // phrase alone is satisfied by either one and proves nothing.
    expect(
      find.text('Trained today — food is the rest of the job.'),
      findsOneWidget,
    );
  });

  testWidgets('the score keeps its old value at the floor diameter', (
    tester,
  ) async {
    // The pre-responsive card hardcoded `fontSize: 52`. Asserting against
    // that literal, rather than against `176 * 0.295`, is what makes this a
    // real guard: the ratio version just restates the implementation and
    // would still pass if the ratio drifted.
    await tester.pumpWidget(host(320));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('68'));
    expect(text.style!.fontSize, closeTo(52, 0.5));
  });

  group('the centre score cannot grow into the rings', () {
    // Nothing throws when it does — a Text simply paints past its box — so
    // the overflow suite can't see this. It has to be measured.
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('a 3-digit score stays inside the hole at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(430, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 398,
                    // 100 is reachable — today_screen clamps the score to it.
                    child: const ReadinessCard(
                      data: ReadinessData(
                        score: 100,
                        caloriesProgress: 1,
                        proteinProgress: 1,
                        sessionsProgress: 1,
                        fueledValue: '100%',
                        caloriesLabel: '3,200 kcal',
                        loadValue: '246',
                        loadLabel: 'push day',
                        proteinValue: '190g',
                        proteinTarget: 'of 190g',
                        bodyFatValue: '18.2%',
                        bodyFatDelta: '-0.6%',
                        trainingDetail: 'Trained today',
                        fuelDetail: '3,200 of 3,200 kcal today',
                        proteinDetail: '190g of 190g today',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final ring = ringDiameter(tester);
        final hole = ReadinessRingPainter.holeDiameter(ring);
        // getRect, not getSize: the score sits in a FittedBox, and getSize
        // reports the child's pre-transform layout size — which stays large
        // while the paint is scaled down, so it would report an overlap that
        // is not on screen. getRect walks localToGlobal and so reflects the
        // scale actually applied.
        final score = tester.getRect(find.text('100')).width;
        expect(
          score,
          lessThanOrEqualTo(hole),
          reason:
              'score is ${score.toStringAsFixed(1)}dp wide against a '
              '${hole.toStringAsFixed(1)}dp hole — it is painting over the '
              'inner rings',
        );
      });
    }
  });

  group('the ring gradient reaches full colour at the end of ITS OWN arc', () {
    // A Shader is opaque once built — createShader() can't be inspected
    // after the fact — so this exercises the SweepGradient one step before
    // that, which is the only stage a test can actually see it at.
    const start = -math.pi / 2;

    test('a quarter-turn ring: gradient ends a quarter-turn from start', () {
      final sweep = math.pi / 2; // 90°, i.e. progress == 0.25
      final g = ReadinessRingPainter.arcGradient(Colors.red, start, sweep);
      expect(g.startAngle, start);
      expect(g.endAngle, closeTo(start + sweep, 1e-9));
      // The bug this guards: spanning the full circle regardless of sweep,
      // so a short arc only ever samples the pale end of the gradient.
      expect(g.endAngle, isNot(closeTo(2 * math.pi, 0.01)));
    });

    test('a full ring: gradient spans the whole circle, correctly', () {
      final sweep = 2 * math.pi; // progress == 1.0
      final g = ReadinessRingPainter.arcGradient(Colors.red, start, sweep);
      expect(g.endAngle - g.startAngle, closeTo(2 * math.pi, 1e-9));
    });

    test(
      'a barely-started ring: gradient span is tiny, not the full circle',
      () {
        final sweep = 0.05; // progress ~0.008
        final g = ReadinessRingPainter.arcGradient(Colors.red, start, sweep);
        expect(g.endAngle - g.startAngle, closeTo(sweep, 1e-9));
      },
    );

    test('the pale end sits at the arc start, full colour at the arc end', () {
      final g = ReadinessRingPainter.arcGradient(
        Colors.red,
        start,
        math.pi / 2,
      );
      expect(g.colors.first.a, lessThan(g.colors.last.a));
      expect(g.colors.last, Colors.red);
    });
  });
}
