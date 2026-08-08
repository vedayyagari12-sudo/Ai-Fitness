import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/utils/chart_labels.dart';

/// Charts carry always-on value labels, so the only thing stopping them
/// colliding is which points get labelled. The old rule was a fixed five —
/// independent of chart width and of how wide the numbers were — which is
/// why the BODY tab's trend ran its labels together once a few entries
/// existed.
void main() {
  const style = TextStyle(fontSize: 14, fontWeight: FontWeight.w800);

  /// The property that actually matters: no two labelled points sit closer
  /// than the widest label plus its gap.
  void expectNoOverlap(
    List<int> indices,
    List<String> labels,
    double spacing, {
    double minGap = 10,
  }) {
    final widest = widestLabelWidth(labels, style);
    for (var i = 1; i < indices.length; i++) {
      final apart = (indices[i] - indices[i - 1]) * spacing;
      expect(
        apart,
        greaterThanOrEqualTo(widest + minGap),
        reason:
            'labels at ${indices[i - 1]} and ${indices[i]} are ${apart}px '
            'apart but need ${widest + minGap}px',
      );
    }
  }

  List<String> weights(int n) => [
    for (var i = 0; i < n; i++) (160 + i * 0.4).toStringAsFixed(1),
  ];

  group('never overlaps', () {
    for (final count in [2, 3, 6, 7, 12, 30, 90, 365]) {
      test('$count points on a 290px line chart', () {
        final labels = weights(count);
        final spacing = linePointSpacing(290, count);
        final idx = fittingLabelIndices(
          labels: labels,
          style: style,
          pointSpacing: spacing,
        );
        expect(idx, isNotEmpty);
        expectNoOverlap(idx, labels, spacing);
      });
    }

    for (final width in [140.0, 200.0, 290.0, 400.0]) {
      test('12 points on a ${width}px chart', () {
        final labels = weights(12);
        final spacing = linePointSpacing(width, 12);
        final idx = fittingLabelIndices(
          labels: labels,
          style: style,
          pointSpacing: spacing,
        );
        expectNoOverlap(idx, labels, spacing);
      });
    }

    test('wide labels thin out more than narrow ones', () {
      final spacing = linePointSpacing(290, 20);
      final narrow = fittingLabelIndices(
        labels: [for (var i = 0; i < 20; i++) '5'],
        style: style,
        pointSpacing: spacing,
      );
      final wide = fittingLabelIndices(
        labels: [for (var i = 0; i < 20; i++) '12,480 lbs'],
        style: style,
        pointSpacing: spacing,
      );
      expect(narrow.length, greaterThan(wide.length));
    });
  });

  group('always keeps the newest value', () {
    for (final count in [1, 2, 5, 17, 100]) {
      test('$count points', () {
        final labels = weights(count);
        final idx = fittingLabelIndices(
          labels: labels,
          style: style,
          pointSpacing: linePointSpacing(290, count),
        );
        expect(
          idx.last,
          count - 1,
          reason: 'the latest reading is the one the card is about',
        );
      });
    }
  });

  test('labels every point when they all comfortably fit', () {
    final labels = ['12', '14', '16'];
    final idx = fittingLabelIndices(
      labels: labels,
      style: style,
      pointSpacing: linePointSpacing(400, 3),
    );
    expect(idx, [0, 1, 2]);
  });

  test('an unlaid-out chart labels only the newest point', () {
    // Width is 0 on the first build pass; anything else would divide by zero
    // or spray labels at the origin.
    final idx = fittingLabelIndices(
      labels: weights(8),
      style: style,
      pointSpacing: linePointSpacing(0, 8),
    );
    expect(idx, [7]);
  });

  test('an empty series produces no labels', () {
    expect(
      fittingLabelIndices(labels: const [], style: style, pointSpacing: 30),
      isEmpty,
    );
  });

  test('bar spacing gives each bar its own slot', () {
    // 8 bars across 240px is 30px per bar, not 240/7.
    expect(barPointSpacing(240, 8), 30);
    expect(linePointSpacing(240, 9), 30);
  });

  test('indices stay in range and ascend', () {
    final labels = weights(50);
    final idx = fittingLabelIndices(
      labels: labels,
      style: style,
      pointSpacing: linePointSpacing(290, 50),
    );
    expect(idx.first, greaterThanOrEqualTo(0));
    expect(idx.last, lessThan(50));
    for (var i = 1; i < idx.length; i++) {
      expect(idx[i], greaterThan(idx[i - 1]));
    }
  });
}
