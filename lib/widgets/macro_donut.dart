import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/macro_split.dart';

/// Today's protein / carbs / fat as one ring, with the day's energy in the
/// middle.
///
/// The only genuine part-to-whole dataset the app collects, which is why this
/// is the only pie-shaped chart in it: everything else on the dashboard is a
/// series over time, where a ring would imply a whole that does not exist.
///
/// Segments are sized by the calories each macro contributes, not by grams —
/// fat carries 9 kcal/g against 4, so a gram-weighted ring would show three
/// equal thirds for a day that is more than half fat.
class MacroDonut extends StatelessWidget {
  const MacroDonut({
    super.key,
    required this.split,
    this.size = 132,
    this.centreLabel = 'KCAL',
  });

  final MacroSplit split;
  final double size;
  final String centreLabel;

  /// The colour each macro carries here and in the legend beside it.
  ///
  /// These three are validated as a group: because every segment of a
  /// three-slice ring touches both others, they have to stay separable
  /// pairwise under protanopia and deuteranopia, not just as neighbours.
  /// Green and orange are the pair that collapses, so they are stepped apart
  /// in lightness rather than hue — see test/palette_test.dart.
  static Color get proteinColor => ChartFill.lime;
  static Color get carbsColor => ChartFill.blue;
  static Color get fatColor => ChartFill.orange;

  @override
  Widget build(BuildContext context) {
    final ringThickness = size * 0.16;

    // fl_chart is unforgiving here in two different ways, so both are handled
    // rather than assumed away:
    //  · PieChartData.sumValue reduces over the section list, which throws
    //    outright on an empty one;
    //  · a list whose values sum to zero does not throw — it silently paints
    //    nothing, which is worse, because the card looks broken rather than
    //    empty. Hence a placeholder ring with a real positive value.
    final sections = split.isEmpty
        ? [
            PieChartSectionData(
              value: 1,
              color: kChartTrack,
              radius: ringThickness,
              showTitle: false,
            ),
          ]
        : [
            _slice(split.proteinKcal, proteinColor, ringThickness),
            _slice(split.carbsKcal, carbsColor, ringThickness),
            _slice(split.fatKcal, fatColor, ringThickness),
          ];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              // Finite and explicit. Left at its default of infinity,
              // calculateCenterRadius reduces over the sections to derive one.
              centerSpaceRadius: size * 0.34,
              // A 2px gap of surface between fills, rather than a border drawn
              // around each one.
              sectionsSpace: 2,
              startDegreeOffset: -90, // start at 12 o'clock
              pieTouchData: PieTouchData(enabled: false),
              borderData: FlBorderData(show: false),
            ),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          ),
          // The hole is size*0.68 across, so the largest square that fits
          // inside it is that over root two. Staying under that, and pinning
          // the text scale, is what stops a large accessibility text setting
          // pushing the number out over the ring.
          IgnorePointer(
            child: SizedBox(
              width: size * 0.46,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      split.isEmpty ? '—' : split.totalKcal.round().toString(),
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      centreLabel,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: kTextMuted,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _slice(double kcal, Color colour, double thickness) =>
      PieChartSectionData(
        // Zero-valued slices are kept in the list rather than filtered out:
        // fl_chart skips painting them anyway, and holding the list length at
        // three keeps colours pinned to macros while the ring animates
        // between builds. Filtering would let a colour jump macro when a
        // meal is logged.
        value: kcal,
        color: colour,
        radius: thickness,
        showTitle: false,
      );
}
