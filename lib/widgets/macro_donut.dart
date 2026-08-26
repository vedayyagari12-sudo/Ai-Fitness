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

    return TweenAnimationBuilder<double>(
      // Grows in on first paint rather than snapping straight to the target
      // split — matches the readiness ring's own entrance so the two hero
      // cards on this screen open the same way. Section VALUES are what get
      // scaled by [t], never the isEmpty branch below: that has to stay
      // keyed to the real data the whole time, or a genuinely-full day would
      // read as "empty" for the first frame of its own entrance animation.
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        // fl_chart is unforgiving here in two different ways, so both are
        // handled rather than assumed away:
        //  · PieChartData.sumValue reduces over the section list, which
        //    throws outright on an empty one;
        //  · a list whose values sum to zero does not throw — it silently
        //    paints nothing, which is worse, because the card looks broken
        //    rather than empty. Hence a placeholder ring with a real
        //    positive value that does not depend on the animation clock.
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
                _slice(split.proteinKcal * t, proteinColor, ringThickness),
                _slice(split.carbsKcal * t, carbsColor, ringThickness),
                _slice(split.fatKcal * t, fatColor, ringThickness),
              ];

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A soft halo behind the ring, tinted to whichever macro is
              // carrying the most of today's energy — the one thing about
              // the day the ring itself is already the answer to, so the
              // glow doesn't invent a fourth colour meaning nothing.
              // Minimal by design: a wash, not a spotlight.
              if (!split.isEmpty)
                Container(
                  width: size * 0.94,
                  height: size * 0.94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _dominantColour.withValues(alpha: 0.30 * t),
                        blurRadius: size * 0.22,
                        spreadRadius: size * 0.01,
                      ),
                    ],
                  ),
                ),
              PieChart(
                PieChartData(
                  sections: sections,
                  // Finite and explicit. Left at its default of infinity,
                  // calculateCenterRadius reduces over the sections to
                  // derive one.
                  centerSpaceRadius: size * 0.34,
                  // A 2px gap of surface between fills, rather than a
                  // border drawn around each one.
                  sectionsSpace: 2,
                  startDegreeOffset: -90, // start at 12 o'clock
                  pieTouchData: PieTouchData(enabled: false),
                  borderData: FlBorderData(show: false),
                ),
                // fl_chart's own animation handles a data CHANGE (a meal
                // logged after first paint); the entrance itself is driven
                // by [t] above, which is why this can stay short.
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              ),
              // The hole is size*0.68 across, so the largest square that
              // fits inside it is that over root two. Staying under that,
              // and pinning the text scale, is what stops a large
              // accessibility text setting pushing the number out over the
              // ring.
              IgnorePointer(
                child: SizedBox(
                  width: size * 0.46,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          split.isEmpty
                              ? '—'
                              : (split.totalKcal * t).round().toString(),
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            // Scales with the ring, like the readiness
                            // score does with its — a bigger ring with a
                            // centre number pinned to the old fixed size
                            // just looks like the number shrank.
                            fontSize: size * 0.197,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: size * 0.015),
                        Text(
                          centreLabel,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: size * 0.068,
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
      },
    );
  }

  /// Whichever macro is contributing the most energy right now, for the
  /// glow only — not exposed on [MacroSplit] because nothing else needs it.
  /// Ties break protein > carbs > fat, the same stable order the ring
  /// itself draws in.
  Color get _dominantColour {
    final p = split.proteinKcal, c = split.carbsKcal, f = split.fatKcal;
    if (p >= c && p >= f) return proteinColor;
    if (c >= f) return carbsColor;
    return fatColor;
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
