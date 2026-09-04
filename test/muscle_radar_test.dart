import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/widgets/muscle_radar.dart';

/// The radar is painted straight onto a canvas, so the widget tree says
/// nothing about whether it drew the right shape. Pixel readback is not
/// available headlessly, so this records the draw calls and asserts on their
/// geometry — the same approach the muscle map's tests use.
class _RecordingCanvas implements Canvas {
  final List<Path> paths = [];
  final List<({Offset centre, double radius})> circles = [];
  final List<({Offset a, Offset b})> lines = [];

  @override
  void drawPath(Path path, Paint paint) => paths.add(path);

  @override
  void drawCircle(Offset c, double r, Paint paint) =>
      circles.add((centre: c, radius: r));

  @override
  void drawLine(Offset a, Offset b, Paint paint) => lines.add((a: a, b: b));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const size = Size(240, 240);
  final centre = Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2 - MuscleRadarPainter.labelInset;

  MuscleRadarPainter painterFor(List<MuscleReading> readings) =>
      MuscleRadarPainter(
        readings: readings,
        accent: const Color(0xFFFF3B79),
        fill: const Color(0xFFCB0057),
        grid: const Color(0x22FFFFFF),
        labelColour: const Color(0xFF8A8A8A),
        surface: const Color(0xFF141414),
        // A literal style, not the app's kLabelSmall: that resolves through
        // google_fonts, which reaches the network and throws in a test.
        labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      );

  _RecordingCanvas record(List<MuscleReading> readings) {
    final canvas = _RecordingCanvas();
    painterFor(readings).paint(canvas, size);
    return canvas;
  }

  List<MuscleReading> flat(double score, {int n = 9}) => [
    for (var i = 0; i < n; i++) (label: 'm$i', score: score),
  ];

  /// Distance from centre of the outermost vertex dot — the drawn extent of
  /// the web, which is what "how developed" reads as.
  double webExtent(_RecordingCanvas canvas) {
    // Vertex dots are drawn in pairs (surface ring, then accent).
    final dots = canvas.circles.where((c) => c.radius <= 4);
    return dots
        .map((c) => (c.centre - centre).distance)
        .fold<double>(0, math.max);
  }

  group('the scale is absolute, not relative to the data', () {
    test('a weak physique draws a small web, a strong one a large web', () {
      // The reason this is not fl_chart's RadarChart: that scales to the
      // largest value present, so all-4s and all-9s draw the same shape and
      // the chart says nothing about development.
      final weak = webExtent(record(flat(4)));
      final strong = webExtent(record(flat(9)));

      expect(
        strong,
        greaterThan(weak * 1.5),
        reason: 'the web is scaling to its own max instead of to 10',
      );
    });

    test('a 10 reaches the outer ring', () {
      expect(webExtent(record(flat(10))), closeTo(radius, 0.5));
    });

    test('a 5 sits halfway out', () {
      expect(webExtent(record(flat(5))), closeTo(radius / 2, 0.5));
    });

    test('a 0 collapses to the centre', () {
      expect(webExtent(record(flat(0))), closeTo(0, 0.5));
    });
  });

  group('bad data cannot draw outside the grid', () {
    test('a score above 10 is clamped to the outer ring', () {
      expect(webExtent(record(flat(45))), closeTo(radius, 0.5));
    });

    test('a negative score is clamped to the centre', () {
      expect(webExtent(record(flat(-3))), closeTo(0, 0.5));
    });

    test('nothing is drawn past the canvas', () {
      final canvas = record([
        (label: 'chest', score: 10),
        (label: 'back', score: 0),
        (label: 'lats', score: 12),
        (label: 'traps', score: -1),
        (label: 'shoulders', score: 7),
      ]);
      final bounds = Offset.zero & size;
      for (final path in canvas.paths) {
        final b = path.getBounds();
        expect(
          bounds.inflate(0.5).contains(b.topLeft) &&
              bounds.inflate(0.5).contains(b.bottomRight),
          isTrue,
          reason: 'shape $b escapes the ${size.width}x${size.height} canvas',
        );
      }
    });
  });

  group('shape', () {
    test('draws one spoke per muscle', () {
      expect(record(flat(6, n: 9)).lines, hasLength(9));
      expect(record(flat(6, n: 5)).lines, hasLength(5));
    });

    test('an imbalance is visibly lopsided', () {
      // One strong muscle among weak ones must reach much further out than
      // the rest, or the chart is not doing its job.
      final canvas = record([
        (label: 'chest', score: 9),
        (label: 'back', score: 3),
        (label: 'legs', score: 3),
        (label: 'arms', score: 3),
      ]);
      final dots = canvas.circles
          .where((c) => c.radius <= 4)
          .map((c) => (c.centre - centre).distance)
          .toList();
      expect(dots.reduce(math.max), greaterThan(dots.reduce(math.min) * 2));
    });

    test('the recorder actually sees the draw calls', () {
      // Guards the harness: if noSuchMethod swallowed everything, every
      // assertion above would pass vacuously.
      final canvas = record(flat(7));
      expect(canvas.paths.length, greaterThan(4));
      expect(canvas.circles, isNotEmpty);
    });
  });

  group('too few axes', () {
    test('the painter draws nothing below three', () {
      for (final n in [0, 1, 2]) {
        final canvas = record(flat(7, n: n));
        expect(canvas.paths, isEmpty, reason: '$n axes');
        expect(canvas.lines, isEmpty, reason: '$n axes');
      }
    });

    testWidgets('the widget renders nothing below three', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MuscleRadar(readings: flat(7, n: 2))),
        ),
      );
      expect(tester.takeException(), isNull);
      // Scoped to this painter — Scaffold and MaterialApp bring their own
      // CustomPaints, so a bare byType finder would never have failed.
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MuscleRadarPainter,
        ),
        findsNothing,
      );
    });
  });

  testWidgets('lays out without overflowing a narrow card', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(height: 236, child: MuscleRadar(readings: flat(8))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shape is described for screen readers', (tester) async {
    // Nothing in the web is text, so without this the whole card is silent.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MuscleRadar(
            readings: const [
              (label: 'chest', score: 8.2),
              (label: 'back', score: 6.0),
              (label: 'legs', score: 7.4),
            ],
          ),
        ),
      ),
    );

    final described = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(MuscleRadar),
        matching: find.byType(Semantics),
      ),
    );
    expect(described.properties.label, contains('chest 8.2 of 10'));
    expect(described.properties.label, contains('back 6.0 of 10'));
  });
}
