import 'dart:math' as math;

/// Plot window for a line chart.
///
/// Kept here rather than inline in each chart because the degenerate cases
/// are easy to get wrong and were previously solved twice, differently, in
/// two files.
class ChartRange {
  const ChartRange(this.min, this.max);

  final double min;
  final double max;

  double get span => max - min;

  /// Gridline spacing that always divides the plot into [divisions] bands.
  /// Deriving this from the data's own range instead lets a flat series
  /// collapse it toward zero, which asks the chart for thousands of lines.
  double interval([int divisions = 3]) => span / divisions;
}

/// Vertical window for [values], padded so the line never touches the edges.
///
/// A single reading, or several identical ones, has zero range. Padding
/// proportionally alone would leave a flat window and pin the line to the
/// axis, so the padding also has a floor scaled to the magnitude of the
/// numbers — a few lbs for a bodyweight, a fraction of a percent for body
/// fat.
///
/// The floor is applied with max() rather than as an either/or branch: a
/// branch makes the window jump discontinuously the moment two readings stop
/// being bit-identical, so 162.0/162.0 and 162.0/162.1 would render at
/// wildly different zoom levels.
ChartRange paddedYRange(List<double> values, {double basePad = 0.5}) {
  if (values.isEmpty) return const ChartRange(0, 1);

  final min = values.reduce(math.min);
  final max = values.reduce(math.max);
  final range = max - min;

  final magnitude = math.max(min.abs(), max.abs());
  final floor = (magnitude * 0.03).clamp(0.5, 5.0);
  final pad = math.max(range * 0.25 + basePad, floor);

  return ChartRange(min - pad, max + pad);
}

/// Horizontal window for a series of [count] points plotted at x = 0..count-1.
///
/// With one point minX equals maxX, and fl_chart resolves that to x = 0 —
/// the plot's left border — so the dot is drawn half outside the chart and
/// its always-on value label further still. Giving a lone point a window
/// around itself centres it instead.
ChartRange xRangeFor(int count) {
  if (count <= 1) return const ChartRange(-0.5, 0.5);
  return ChartRange(0, (count - 1).toDouble());
}
