import 'package:fitness_app/screens/workouts/segmented_bar.dart';
import 'package:fitness_app/widgets/recent_scan_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regressions for overflows seen on a real 1080x2340 @3.0 device (360dp
/// wide). Each was reported in the console as "A RenderFlex overflowed by N
/// pixels", so they are all exercised at that width and at the larger system
/// font sizes phones ship with.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1.0,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  // Overflowed by 54px on the right: three labels plus 24dp gaps are wider
  // than a 360dp screen.
  for (final scale in [1.0, 1.3]) {
    testWidgets('BODY metric tabs do not overflow at ${scale}x text', (
      tester,
    ) async {
      await pump(
        tester,
        SegmentedBar(
          labels: const ['BODY FAT', 'WEIGHT', 'SCORE'],
          index: 0,
          onChanged: (_) {},
        ),
        textScale: scale,
      );
    });

    testWidgets('TRAIN segments do not overflow at ${scale}x text', (
      tester,
    ) async {
      await pump(
        tester,
        SegmentedBar(
          labels: const ['TODAY', 'LOG', 'HISTORY'],
          index: 0,
          onChanged: (_) {},
        ),
        textScale: scale,
      );
    });
  }

  // Overflowed by 22px on the bottom: the strip's height was hard-coded to
  // fit two lines of text at 1.0 only.
  for (final scale in [1.0, 1.15, 1.3]) {
    testWidgets('recent scans strip does not clip at ${scale}x text', (
      tester,
    ) async {
      await pump(
        tester,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                RecentScanThumb(
                  title: 'Watermelon and Mixed Fruit Bowl',
                  subtitle: '75 kcal',
                  tag: 'meal',
                ),
                SizedBox(width: 12),
                RecentScanThumb(
                  title: 'Dal (Lentil Curry)',
                  subtitle: '315 kcal',
                  tag: 'meal',
                ),
                SizedBox(width: 12),
                RecentScanThumb(
                  title: 'Scan #2',
                  subtitle: '18.0% BF',
                  tag: 'body',
                ),
              ],
            ),
          ),
        ),
        textScale: scale,
      );
    });
  }

  // The TRAIN exercise row: `repsRaw` is free text from the model, so a
  // prose value has to shrink the row rather than overflow it. This mirrors
  // the row's flex layout (name 3 : reps 2).
  for (final reps in ['12-15', '30-45 sec hold per arm', '8']) {
    testWidgets('exercise row fits reps "$reps"', (tester) async {
      await pump(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SizedBox(width: 24, child: Text('3')),
              const SizedBox(width: 4),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Suspended Hamstring Curls',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'ERECTOR SPINAE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 2,
                child: Text(
                  '4 × $reps',
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
        ),
        textScale: 1.3,
      );
    });
  }
}
