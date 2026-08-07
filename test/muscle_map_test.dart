import 'package:physiqo_ai/screens/body/body_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The muscle map is drawn straight onto a canvas, so the widget tree says
/// nothing about whether a region landed where it should. Pixel readback
/// isn't available headlessly (both toImage and toByteData wait on a
/// rasterizer that flutter_test never starts), so instead this records the
/// draw calls and asserts on their geometry.
class _RecordingCanvas implements Canvas {
  final List<Rect> shapes = [];

  @override
  void drawPath(Path path, Paint paint) => shapes.add(path.getBounds());

  @override
  void drawRRect(RRect rrect, Paint paint) => shapes.add(rrect.outerRect);

  @override
  void drawOval(Rect rect, Paint paint) => shapes.add(rect);

  @override
  void drawRect(Rect rect, Paint paint) => shapes.add(rect);

  // Divider strokes are detail lines inside a region, not regions themselves.
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const w = 200.0;
  const h = 360.0; // matches the card's 0.55 aspect ratio
  const canvasBounds = Rect.fromLTWH(0, 0, w, h);

  List<Rect> shapesOf(CustomPainter painter) {
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(w, h));
    return canvas.shapes;
  }

  /// True when some drawn shape covers the given fractional point.
  bool covers(List<Rect> shapes, double fx, double fy) =>
      shapes.any((r) => r.contains(Offset(fx * w, fy * h)));

  final scored = <String, double?>{
    'chest': 8,
    'back': 6,
    'lats': 4,
    'mid back': 9,
    'traps': 5,
    'shoulders': 7,
    'arms': 6,
    'legs': 8,
    'core': 7,
  };

  /// A point that must fall inside each named back-view region.
  const backProbes = {
    'traps': (0.50, 0.17),
    'left rear delt': (0.265, 0.185),
    'right rear delt': (0.735, 0.185),
    'left lat': (0.36, 0.34),
    'right lat': (0.64, 0.34),
    'mid back': (0.50, 0.31),
    'lower back': (0.50, 0.42),
    'left glute': (0.44, 0.52),
    'right glute': (0.56, 0.52),
    'left hamstring': (0.425, 0.64),
    'left calf': (0.425, 0.85),
    'left arm': (0.265, 0.28),
    'right arm': (0.735, 0.28),
  };

  test('back map draws every region it claims to show', () {
    final shapes = shapesOf(BackMuscleMapPainterForTest(scores: scored));

    backProbes.forEach((name, p) {
      expect(
        covers(shapes, p.$1, p.$2),
        isTrue,
        reason: 'nothing drawn over $name at $p',
      );
    });
  });

  test('back map stays inside the canvas', () {
    final shapes = shapesOf(BackMuscleMapPainterForTest(scores: scored));
    final allowed = canvasBounds.inflate(0.5);

    for (final shape in shapes) {
      // A region spilling past the edge is silently clipped on screen, which
      // reads as a lopsided figure rather than as an error.
      expect(
        allowed.contains(shape.topLeft) && allowed.contains(shape.bottomRight),
        isTrue,
        reason: 'shape $shape falls outside the ${w}x$h canvas',
      );
    }
  });

  test('back map is left/right symmetric', () {
    final shapes = shapesOf(BackMuscleMapPainterForTest(scores: scored));

    // Anything covering a point on the left needs a mirror on the right, or
    // the figure looks broken.
    for (final p in [
      (0.265, 0.185),
      (0.36, 0.34),
      (0.44, 0.52),
      (0.425, 0.64),
      (0.425, 0.85),
      (0.265, 0.28),
    ]) {
      expect(
        covers(shapes, 1 - p.$1, p.$2),
        covers(shapes, p.$1, p.$2),
        reason: 'no mirror for $p',
      );
    }
  });

  test('front and back agree on head, neck and leg placement', () {
    final front = shapesOf(MuscleMapPainterForTest(scores: scored));
    final back = shapesOf(BackMuscleMapPainterForTest(scores: scored));

    // Flipping the view should read as turning one figure around, so the
    // parts that aren't side-specific have to line up.
    for (final p in [(0.5, 0.055), (0.5, 0.105), (0.425, 0.85)]) {
      expect(covers(front, p.$1, p.$2), isTrue, reason: 'front misses $p');
      expect(covers(back, p.$1, p.$2), isTrue, reason: 'back misses $p');
    }
  });

  test('unscored back regions still draw the silhouette', () {
    // A front-only scan leaves every back region null. The figure must still
    // be drawn in grey rather than disappearing.
    final shapes = shapesOf(
      BackMuscleMapPainterForTest(
        scores: const {'lats': null, 'mid back': null, 'traps': null},
      ),
    );

    for (final key in ['traps', 'left lat', 'mid back', 'lower back']) {
      final p = backProbes[key]!;
      expect(
        covers(shapes, p.$1, p.$2),
        isTrue,
        reason: '$key disappeared when unscored',
      );
    }
  });

  test('the canvas recorder actually sees the draw calls', () {
    // Guards the harness: if _RecordingCanvas swallowed everything through
    // noSuchMethod, every assertion above would pass vacuously.
    expect(
      shapesOf(BackMuscleMapPainterForTest(scores: scored)).length,
      greaterThan(10),
    );
  });
}
