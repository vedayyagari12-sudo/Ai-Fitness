import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Chooses which data points get an always-on value label so that labels can
/// never collide, whatever the series length or the chart's width.
///
/// The previous approach picked a fixed five labels (and labelled *every*
/// point for short series) with no regard for how wide the chart or the
/// numbers were — so "162.0lbs" six times over a narrow card ran the labels
/// straight through each other.
///
/// Here the spacing is derived instead of assumed: measure the widest label,
/// work out how many whole points apart two labels must sit to clear it, and
/// take every nth point. Selection runs backwards from the end so the most
/// recent value — the one the card is about — is always labelled.
///
/// [pointSpacing] is the horizontal distance between adjacent data points:
///   · line chart, points spread across the plot → width / (count - 1)
///   · bar chart, each bar centred in its slot   → width / count
/// Use [barPointSpacing] / [linePointSpacing] rather than working it out at
/// each call site.
List<int> fittingLabelIndices({
  required List<String> labels,
  required TextStyle style,
  required double pointSpacing,
  double minGap = 10,
}) {
  final count = labels.length;
  if (count == 0) return const [];
  if (count == 1) return const [0];
  // A zero or negative spacing means the chart has not been laid out yet;
  // labelling only the newest point is the safe answer.
  if (pointSpacing <= 0) return [count - 1];

  final widest = widestLabelWidth(labels, style);
  final stride = math.max(1, ((widest + minGap) / pointSpacing).ceil());

  final indices = <int>[];
  for (var i = count - 1; i >= 0; i -= stride) {
    indices.add(i);
  }
  return indices.reversed.toList();
}

/// Distance between adjacent points on a line chart whose series spans the
/// full plot width.
double linePointSpacing(double chartWidth, int count) =>
    count < 2 ? chartWidth : chartWidth / (count - 1);

/// Distance between adjacent bars, each centred in its own slot.
double barPointSpacing(double chartWidth, int count) =>
    count < 1 ? chartWidth : chartWidth / count;

/// Width of the widest label, measured rather than estimated — a guess based
/// on character count is wrong enough for proportional fonts to let labels
/// touch anyway.
double widestLabelWidth(List<String> labels, TextStyle style) {
  var widest = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
  }
  return widest;
}
