import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/chart_range.dart';

/// A single reading, or several identical ones, has zero range. Every
/// degenerate case here produced a visible defect before this helper existed:
/// a dot pinned to the axis, a gridline every thousandth of a unit, or the
/// same two readings rendering at wildly different zoom levels.
void main() {
  group('vertical window', () {
    test('a single reading still gets a window to sit inside', () {
      final r = paddedYRange([162.0]);
      expect(r.span, greaterThan(0));
      expect(r.min, lessThan(162));
      expect(r.max, greaterThan(162));
    });

    test('identical readings are not pinned to the axis', () {
      final r = paddedYRange([162.0, 162.0, 162.0]);
      expect(r.min, lessThan(162));
      expect(r.max, greaterThan(162));
    });

    test('flat and near-flat render at comparable zoom', () {
      // The old rule branched on range == 0, so one gram of difference
      // swapped a ~9.7 lb window for a ~1.1 lb one — the same two weigh-ins
      // reading as "no movement" or "a dramatic swing" depending on whether
      // they happened to be bit-identical.
      final flat = paddedYRange([162.0, 162.0]).span;
      final nearFlat = paddedYRange([162.0, 162.1]).span;
      expect(nearFlat, closeTo(flat, flat * 0.15));
    });

    test('the window grows with a genuinely spread series', () {
      final tight = paddedYRange([162.0, 163.0]).span;
      final wide = paddedYRange([140.0, 200.0]).span;
      expect(wide, greaterThan(tight));
    });

    test('the padding floor scales with the magnitude of the numbers', () {
      // A few lbs of headroom suits a bodyweight; the same absolute padding
      // around a body-fat percentage would swamp the data.
      final weight = paddedYRange([180.0]).span;
      final bodyFat = paddedYRange([18.0]).span;
      expect(weight, greaterThan(bodyFat));
    });

    test('an empty series produces a usable window rather than throwing', () {
      expect(() => paddedYRange([]), returnsNormally);
      expect(paddedYRange([]).span, greaterThan(0));
    });

    test('negative values are handled', () {
      final r = paddedYRange([-5.0, -2.0]);
      expect(r.min, lessThan(-5));
      expect(r.max, greaterThan(-2));
    });
  });

  group('gridline interval', () {
    test('never collapses toward zero', () {
      // Derived from the data's own range this went to ~0.001 for a flat
      // series, asking fl_chart for hundreds of gridlines.
      for (final values in [
        [162.0],
        [162.0, 162.0],
        [18.0],
        <double>[],
      ]) {
        expect(
          paddedYRange(values).interval(),
          greaterThan(0.05),
          reason: 'interval collapsed for $values',
        );
      }
    });

    test('divides the plot into the requested number of bands', () {
      final r = paddedYRange([100.0, 200.0]);
      expect(r.interval(4) * 4, closeTo(r.span, 0.0001));
    });
  });

  group('horizontal window', () {
    test('a lone point is centred, not pinned to the left border', () {
      // fl_chart resolves minX == maxX to x = 0, drawing the dot and its
      // always-on label half outside the plot.
      final r = xRangeFor(1);
      expect(r.min, lessThan(0));
      expect(r.max, greaterThan(0));
      expect((r.min + r.max) / 2, closeTo(0, 0.0001));
    });

    test('an empty series is treated like a lone point', () {
      expect(xRangeFor(0).span, greaterThan(0));
    });

    test('a normal series spans its indices exactly', () {
      expect(xRangeFor(5).min, 0);
      expect(xRangeFor(5).max, 4);
      expect(xRangeFor(30).max, 29);
    });
  });
}
