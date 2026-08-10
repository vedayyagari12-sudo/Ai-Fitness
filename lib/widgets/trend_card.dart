import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../utils/chart_labels.dart';
import '../utils/chart_range.dart';
import '../utils/units.dart';

/// Dashboard trends card — four tabs, each with a headline number, a chart
/// and a one-line plain-English takeaway:
///  · CALORIES — 7-day bars vs a dashed daily target, color-coded by how
///    close each day landed (grey = nothing logged that day)
///  · WEIGHT   — bodyweight line (lbs) with started/now/total-change text,
///    colored by whether the trend matches the user's goal
///  · VOLUME   — weekly training volume (lbs lifted), last 8 weeks, with
///    week-over-week change
///  · STRENGTH — estimated 1-rep max (Epley) from your heaviest set each
///    week — a more direct "are you getting stronger" signal than volume
///    alone, since volume can climb from doing more reps at the same weight.
class TrendCard extends StatefulWidget {
  const TrendCard({
    super.key,
    required this.goal,
    required this.weightLbs,
    required this.dailyCalories,
    required this.dayLabels,
    required this.calorieTarget,
    required this.weeklyVolume,
    this.weeklyStrength = const [],
  });

  final String goal; // "bulk" | "cut" | "maintain" | "athletic"
  final List<double> weightLbs; // 30d bodyweight in lbs, oldest → newest
  final List<double> dailyCalories; // last 7 days, index 6 = today
  final List<String> dayLabels; // matching day labels ("Mon"…)
  final double calorieTarget; // kcal/day
  final List<double> weeklyVolume; // lbs lifted per week, oldest → newest
  final List<double> weeklyStrength; // est. 1RM (lbs) per week, oldest→newest

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  int _selected = 0; // 0 CALORIES, 1 WEIGHT, 2 VOLUME, 3 STRENGTH
  static const _segments = ['CALORIES', 'WEIGHT', 'VOLUME', 'STRENGTH'];

  ({String label, Color color}) get _goalBadge {
    final g = widget.goal.toLowerCase();
    if (g.contains('cut') || g.contains('lose')) {
      return (label: 'CUTTING', color: kPink);
    }
    if (g.contains('bulk') || g.contains('muscle')) {
      return (label: 'BULKING', color: kLime);
    }
    if (g.contains('athletic')) return (label: 'ATHLETIC', color: kCyan);
    return (label: 'MAINTAIN', color: kCyan);
  }

  @override
  Widget build(BuildContext context) {
    final badge = _goalBadge;
    return Container(
      decoration: BoxDecoration(
        gradient: kHeroCardGradient(kSteel),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
        boxShadow: kGlassShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('YOUR TRENDS', style: kLabelSmall)),
              Container(
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  badge.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: badge.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _segmentedControl(),
          const SizedBox(height: 16),
          switch (_selected) {
            1 => _weightView(),
            2 => _volumeView(),
            3 => _strengthView(),
            _ => _caloriesView(),
          },
        ],
      ),
    );
  }

  Widget _segmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: kBgElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (var i = 0; i < _segments.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selected = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  // Four words across a phone: the type has to be small and
                  // tight, or the labels touch and the pills have no room to
                  // breathe between them.
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _selected == i ? kBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _segments[i],
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: _selected == i ? Colors.white : kTextMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Charts need their real width to decide how many value labels fit, and
  /// only the layout knows it.
  Widget _chart(Widget Function(double width) build, {double? height}) =>
      SizedBox(
        height: height ?? _chartHeight,
        child: LayoutBuilder(builder: (_, c) => build(c.maxWidth)),
      );

  Widget _empty(String hint) {
    return SizedBox(
      // Roughly the height of a populated view, so switching tabs doesn't
      // make the card jump.
      height: 215,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            hint,
            style: TextStyle(fontSize: 13, color: kTextMuted),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _formatThousands(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  /// Short form for on-chart labels, so values stay readable in a narrow
  /// bar (12,480 → "12.5k").
  String _compact(num v) {
    final n = v.round();
    if (n.abs() >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  /// Plot height. The charts carry always-on value labels, so they need real
  /// vertical room — at the old 120 the bars were squeezed into the lower
  /// two-thirds and read as a cramped strip.
  static const double _chartHeight = 168;

  /// Headroom above the tallest bar, as a multiple of it, so the always-on
  /// value label has somewhere to sit without being clipped. Kept tight —
  /// every bit of extra headroom is height stolen from the bars themselves.
  static const double _labelHeadroom = 1.22;

  /// Value labels drawn permanently above each bar/point. Rendered as a
  /// tooltip with a transparent background so it reads as a plain number.
  /// Sized to fit a 7-bar week without neighbouring labels colliding.
  static TextStyle get _valueLabelStyle =>
      TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w800);

  // ── CALORIES ────────────────────────────────────────────────────────────

  Widget _caloriesView() {
    final cals = widget.dailyCalories;
    final target = widget.calorieTarget;
    if (cals.every((c) => c <= 0)) {
      return _empty('Scan a meal in the SCAN tab to start tracking calories');
    }

    final today = cals.isNotEmpty ? cals.last : 0.0;
    final logged = cals.where((c) => c > 0).toList();
    final avgPct = logged.isEmpty || target <= 0
        ? 0
        : (logged.reduce((a, b) => a + b) / logged.length / target * 100)
              .round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scaled as a unit rather than ellipsised — truncating this to
        // "2,562 kcal…" hid the word it was building to.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatThousands(today.round()),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '/ ${_formatThousands(target.round())} kcal today',
                  style: kStatCaption,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          logged.isEmpty
              ? 'No calories logged yet this week'
              : 'Averaging $avgPct% of your target this week',
          style: TextStyle(fontSize: 13, color: kTextMuted),
        ),
        const SizedBox(height: 14),
        _chart((w) => BarChart(_calorieBars(w))),
        const SizedBox(height: 8),
        // Scale the legend down instead of overflowing on narrow phones.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              _legendDot(kGreen, 'On target'),
              const SizedBox(width: 10),
              _legendDot(kGold, 'Close'),
              const SizedBox(width: 10),
              _legendDot(kPink, 'Off target'),
              const SizedBox(width: 10),
              _legendDot(kBgHighlight, 'Not logged'),
            ],
          ),
        ),
      ],
    );
  }

  Color _dayColor(double cal) {
    final target = widget.calorieTarget;
    if (cal <= 0 || target <= 0) return kBgHighlight;
    final off = (cal - target).abs() / target;
    if (off <= 0.10) return kGreen;
    if (off <= 0.20) return kGold;
    return kPink;
  }

  BarChartData _calorieBars(double width) {
    final cals = widget.dailyCalories;
    final target = widget.calorieTarget;
    final labelled = fittingLabelIndices(
      labels: [for (final c in cals) c > 0 ? _compact(c) : '—'],
      style: _valueLabelStyle,
      pointSpacing: barPointSpacing(width, cals.length),
    ).toSet();
    final maxVal = [target * 1.25, ...cals].reduce((a, b) => a > b ? a : b);

    return BarChartData(
      // Headroom so the always-on value labels aren't clipped.
      maxY: maxVal * _labelHeadroom,
      minY: 0,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      // Values are always visible above each bar — no tap-and-hold needed.
      barTouchData: BarTouchData(
        enabled: false,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.transparent,
          tooltipPadding: EdgeInsets.zero,
          tooltipMargin: 2,
          getTooltipItem: (group, _, rod, _) {
            final logged = cals[group.x] > 0;
            return BarTooltipItem(
              logged ? _compact(cals[group.x]) : '—',
              _valueLabelStyle.copyWith(
                color: logged ? _dayColor(cals[group.x]) : kTextMuted,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= widget.dayLabels.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.dayLabels[i].toUpperCase(),
                  // Chart geometry is fixed, so the axis must not grow with
                  // the system font — at large sizes 7 day labels ran
                  // together into one unreadable strip.
                  textScaler: TextScaler.noScaling,
                  style: kAxisLabel,
                ),
              );
            },
          ),
        ),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          if (target > 0)
            HorizontalLine(
              y: target,
              color: kTextSecondary,
              strokeWidth: 1,
              dashArray: [5, 4],
            ),
        ],
      ),
      barGroups: [
        for (var i = 0; i < cals.length; i++)
          BarChartGroupData(
            x: i,
            showingTooltipIndicators: labelled.contains(i)
                ? const [0]
                : const [],
            barRods: [
              BarChartRodData(
                // A visible grey stub marks "not logged" so it reads
                // differently from an actual low-calorie day.
                toY: cals[i] > 0 ? cals[i] : maxVal * 0.04,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: _dayColor(cals[i]),
              ),
            ],
          ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: kTextMuted)),
      ],
    );
  }

  // ── WEIGHT ──────────────────────────────────────────────────────────────

  Widget _weightView() {
    final w = widget.weightLbs;
    if (w.isEmpty) {
      return _empty(
        'Log your bodyweight on the BODY tab (tap the WEIGHT card) '
        'to start your trend',
      );
    }
    // One weigh-in is real data, not a failure. Draw the chart anyway so the
    // single dot confirms the log saved, and say what turns it into a trend —
    // a lone point with no line reads as a broken chart otherwise.
    if (w.length < 2) {
      // Mirrors the populated view's headline/takeaway/chart rhythm, with a
      // shorter plot to offset the hint — otherwise the card is ~60dp taller
      // here and visibly shrinks the day the second weigh-in arrives.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${lbsLabel(w.first)} lbs',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'First weigh-in recorded',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kCyan,
            ),
          ),
          const SizedBox(height: 14),
          _chart((width) => LineChart(_weightLine(kCyan, width)), height: 110),
          const ChartHint(kFirstWeighInHint),
        ],
      );
    }

    final start = w.first;
    final now = w.last;
    final change = now - start;
    final g = widget.goal.toLowerCase();
    final gaining = change > 0;
    final Color trendColor;
    if (change.abs() < 0.05) {
      trendColor = kCyan;
    } else if (g.contains('bulk') || g.contains('muscle')) {
      trendColor = gaining ? kGreen : kPink;
    } else if (g.contains('cut') || g.contains('lose')) {
      trendColor = gaining ? kPink : kGreen;
    } else {
      trendColor = kCyan;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Started ${lbsLabel(start)} lbs · Now ${lbsLabel(now)} lbs',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${change >= 0 ? '+' : ''}${lbsLabel(change)} lbs total '
          '(last 30 days)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: trendColor,
          ),
        ),
        const SizedBox(height: 14),
        _chart((w) => LineChart(_weightLine(trendColor, w))),
      ],
    );
  }

  LineChartData _weightLine(Color color, double width) {
    final w = widget.weightLbs;
    final labelled = fittingLabelIndices(
      labels: [for (final v in w) lbsLabel(v)],
      style: _valueLabelStyle,
      pointSpacing: linePointSpacing(width, w.length),
    );
    final yr = paddedYRange(w);
    final xr = xRangeFor(w.length);

    return LineChartData(
      minY: yr.min,
      maxY: yr.max,
      // Without an explicit window a lone point sits on the left border with
      // its value label half outside the plot.
      minX: xr.min,
      maxX: xr.max,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yr.interval(),
        getDrawingHorizontalLine: (v) =>
            FlLine(color: kGridline, strokeWidth: 1),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      // Values sit on the chart permanently — no tap-and-hold required.
      lineTouchData: LineTouchData(
        enabled: false,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.transparent,
          tooltipPadding: EdgeInsets.zero,
          tooltipMargin: 4,
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(
                lbsLabel(s.y),
                _valueLabelStyle.copyWith(color: color),
              ),
          ],
        ),
      ),
      showingTooltipIndicators: [
        for (final i in labelled)
          ShowingTooltipIndicators([
            LineBarSpot(_weightBar(w, color), 0, FlSpot(i.toDouble(), w[i])),
          ]),
      ],
      lineBarsData: [_weightBar(w, color)],
    );
  }

  LineChartBarData _weightBar(List<double> w, Color color) {
    return LineChartBarData(
      spots: [for (var i = 0; i < w.length; i++) FlSpot(i.toDouble(), w[i])],
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.18), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  // ── VOLUME ──────────────────────────────────────────────────────────────

  Widget _volumeView() {
    final vols = widget.weeklyVolume;
    if (vols.every((v) => v <= 0)) {
      return _empty(
        'Log workouts with sets, reps and weight in the TRAIN tab '
        'to track how much you lift each week',
      );
    }

    final current = vols.last;
    final previous = vols.length >= 2 ? vols[vols.length - 2] : 0.0;
    final pctChange = previous > 0
        ? ((current - previous) / previous * 100).round()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Training Volume (lbs lifted)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_formatThousands(current.round())} lbs this week',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                  ),
                ),
              ),
            ),
            if (pctChange != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${pctChange >= 0 ? '▲ +' : '▼ '}$pctChange% vs last week',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pctChange >= 0 ? kGreen : kPink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _chart((w) => BarChart(_volumeBars(w))),
      ],
    );
  }

  BarChartData _volumeBars(double width) {
    final vols = widget.weeklyVolume;
    final labelled = fittingLabelIndices(
      labels: [for (final v in vols) v > 0 ? _compact(v) : '—'],
      style: _valueLabelStyle,
      pointSpacing: barPointSpacing(width, vols.length),
    ).toSet();
    final maxVal = vols.reduce((a, b) => a > b ? a : b);

    return BarChartData(
      // Headroom for the always-on value labels.
      maxY: maxVal * _labelHeadroom + 1,
      minY: 0,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      // Always-on value labels above each week's bar.
      barTouchData: BarTouchData(
        enabled: false,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.transparent,
          tooltipPadding: EdgeInsets.zero,
          tooltipMargin: 2,
          getTooltipItem: (group, _, rod, _) {
            final logged = vols[group.x] > 0;
            return BarTooltipItem(
              logged ? _compact(vols[group.x]) : '—',
              _valueLabelStyle.copyWith(
                color: logged
                    ? (group.x == vols.length - 1 ? kCyan : kTextSecondary)
                    : kTextMuted,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              final weeksAgo = vols.length - 1 - i;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  weeksAgo == 0 ? 'NOW' : '-${weeksAgo}w',
                  textScaler: TextScaler.noScaling,
                  style: kAxisLabel,
                ),
              );
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < vols.length; i++)
          BarChartGroupData(
            x: i,
            showingTooltipIndicators: labelled.contains(i)
                ? const [0]
                : const [],
            barRods: [
              BarChartRodData(
                toY: vols[i] > 0 ? vols[i] : maxVal * 0.03,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: i == vols.length - 1
                    ? kCyan
                    : (vols[i] > 0
                          ? kCyan.withValues(alpha: 0.45)
                          : kBgHighlight),
              ),
            ],
          ),
      ],
    );
  }

  // ── STRENGTH ────────────────────────────────────────────────────────────

  Widget _strengthView() {
    final str = widget.weeklyStrength;
    if (str.isEmpty || str.every((v) => v <= 0)) {
      return _empty(
        'Log a few heavy sets in the TRAIN tab to start tracking your '
        'estimated 1-rep max',
      );
    }

    final current = str.last;
    final previous = str.length >= 2
        ? str.reversed.skip(1).firstWhere((v) => v > 0, orElse: () => 0.0)
        : 0.0;
    final pctChange = previous > 0
        ? ((current - previous) / previous * 100).round()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showStrengthInfoSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Estimated 1-Rep Max (lbs)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.info_outline_rounded, size: 14, color: kTextMuted),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_formatThousands(current.round())} lbs this week',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                  ),
                ),
              ),
            ),
            if (pctChange != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${pctChange >= 0 ? '▲ +' : '▼ '}$pctChange% vs last logged',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pctChange >= 0 ? kGreen : kPink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _chart((w) => BarChart(_strengthBars(w))),
      ],
    );
  }

  BarChartData _strengthBars(double width) {
    final str = widget.weeklyStrength;
    final labelled = fittingLabelIndices(
      labels: [for (final v in str) v > 0 ? _compact(v) : '—'],
      style: _valueLabelStyle,
      pointSpacing: barPointSpacing(width, str.length),
    ).toSet();
    final maxVal = str.reduce((a, b) => a > b ? a : b);

    return BarChartData(
      maxY: maxVal * _labelHeadroom + 1,
      minY: 0,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        enabled: false,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.transparent,
          tooltipPadding: EdgeInsets.zero,
          tooltipMargin: 2,
          getTooltipItem: (group, _, rod, _) {
            final logged = str[group.x] > 0;
            return BarTooltipItem(
              logged ? _compact(str[group.x]) : '—',
              _valueLabelStyle.copyWith(
                color: logged
                    ? (group.x == str.length - 1 ? kPurple : kTextSecondary)
                    : kTextMuted,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              final weeksAgo = str.length - 1 - i;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  weeksAgo == 0 ? 'NOW' : '-${weeksAgo}w',
                  textScaler: TextScaler.noScaling,
                  style: kAxisLabel,
                ),
              );
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < str.length; i++)
          BarChartGroupData(
            x: i,
            showingTooltipIndicators: labelled.contains(i)
                ? const [0]
                : const [],
            barRods: [
              BarChartRodData(
                toY: str[i] > 0 ? str[i] : maxVal * 0.03,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: i == str.length - 1
                    ? kPurple
                    : (str[i] > 0
                          ? kPurple.withValues(alpha: 0.45)
                          : kBgHighlight),
              ),
            ],
          ),
      ],
    );
  }

  void _showStrengthInfoSheet(BuildContext context) {
    showAppSheet<void>(
      context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHAT IS ESTIMATED 1-REP MAX?', style: kLabelSmall),
            const SizedBox(height: 6),
            Text(
              'Your 1-rep max (1RM) is the heaviest weight you could lift '
              'for exactly one rep. Actually testing that is slow and '
              'risky, so instead we estimate it from the sets you\'re '
              'already logging — no extra work, no maxing out.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPurple.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE FORMULA (Epley)',
                    style: kLabelSmall.copyWith(color: kPurple, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Est. 1RM = Weight × (1 + Reps ÷ 30)',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('EXAMPLE', style: kLabelSmall.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            Text(
              'You log 185 lbs for 8 reps.\n'
              '185 × (1 + 8 ÷ 30) = 185 × 1.27 ≈ 234 lbs\n'
              'That set is worth an estimated 234 lb 1RM — heavier weight '
              'for fewer reps, or lighter weight for more reps, can add up '
              'to a similar estimate.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Each week, we take your single heaviest estimate from '
              'anything you logged that week — not an average — so the '
              'chart tracks your peak strength, not a typical set. It\'s '
              'an estimate to watch trend over time, not a number to '
              'chase by itself.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
