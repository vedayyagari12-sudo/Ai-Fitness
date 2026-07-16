import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/units.dart';

/// Dashboard trends card — three tabs, each with a headline number, a chart
/// and a one-line plain-English takeaway:
///  · CALORIES — 7-day bars vs a dashed daily target, color-coded by how
///    close each day landed (grey = nothing logged that day)
///  · WEIGHT   — bodyweight line (lbs) with started/now/total-change text,
///    colored by whether the trend matches the user's goal
///  · VOLUME   — weekly training volume (lbs lifted), last 8 weeks, with
///    week-over-week change
class TrendCard extends StatefulWidget {
  const TrendCard({
    super.key,
    required this.goal,
    required this.weightLbs,
    required this.dailyCalories,
    required this.dayLabels,
    required this.calorieTarget,
    required this.weeklyVolume,
  });

  final String goal; // "bulk" | "cut" | "maintain" | "athletic"
  final List<double> weightLbs; // 30d bodyweight in lbs, oldest → newest
  final List<double> dailyCalories; // last 7 days, index 6 = today
  final List<String> dayLabels; // matching day labels ("Mon"…)
  final double calorieTarget; // kcal/day
  final List<double> weeklyVolume; // lbs lifted per week, oldest → newest

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  int _selected = 0; // 0 CALORIES, 1 WEIGHT, 2 VOLUME
  static const _segments = ['CALORIES', 'WEIGHT', 'VOLUME'];

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
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < _segments.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selected = i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selected == i ? kBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _segments[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
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

  Widget _empty(String hint) {
    return SizedBox(
      height: 170,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            hint,
            style: const TextStyle(fontSize: 12, color: kTextMuted),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatThousands(today.round()),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '/ ${_formatThousands(target.round())} kcal today',
                style: const TextStyle(fontSize: 13, color: kTextSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          logged.isEmpty
              ? 'No calories logged yet this week'
              : 'Averaging $avgPct% of your target this week',
          style: const TextStyle(fontSize: 11, color: kTextMuted),
        ),
        const SizedBox(height: 14),
        SizedBox(height: 120, child: BarChart(_calorieBars())),
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

  BarChartData _calorieBars() {
    final cals = widget.dailyCalories;
    final target = widget.calorieTarget;
    final maxVal = [
      target * 1.25,
      ...cals,
    ].reduce((a, b) => a > b ? a : b);

    return BarChartData(
      maxY: maxVal * 1.1,
      minY: 0,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => kBgElevated,
          getTooltipItem: (group, _, rod, _) => BarTooltipItem(
            '${rod.toY.round()} kcal',
            const TextStyle(
              color: kTextPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= widget.dayLabels.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.dayLabels[i].toUpperCase(),
                  style: const TextStyle(fontSize: 8, color: kTextMuted),
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
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: kTextMuted),
        ),
      ],
    );
  }

  // ── WEIGHT ──────────────────────────────────────────────────────────────

  Widget _weightView() {
    final w = widget.weightLbs;
    if (w.length < 2) {
      return _empty(
        'Log your bodyweight on the BODY tab (tap the WEIGHT card) '
        'to start your trend — two entries and the line appears',
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
            style: const TextStyle(
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
        SizedBox(height: 120, child: LineChart(_weightLine(trendColor))),
      ],
    );
  }

  LineChartData _weightLine(Color color) {
    final w = widget.weightLbs;
    final minY = w.reduce((a, b) => a < b ? a : b);
    final maxY = w.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.25 + 0.5;

    return LineChartData(
      minY: minY - pad,
      maxY: maxY + pad,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: ((maxY - minY) / 3 + 0.001),
        getDrawingHorizontalLine: (v) => FlLine(
          color: Colors.white.withValues(alpha: 0.04),
          strokeWidth: 1,
        ),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => kBgElevated,
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(
                '${lbsLabel(s.y)} lbs',
                const TextStyle(
                  color: kTextPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < w.length; i++) FlSpot(i.toDouble(), w[i]),
          ],
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.18), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
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
        const Text(
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                  ),
                ),
              ),
            ),
            if (pctChange != null) ...[
              const SizedBox(width: 8),
              Text(
                '${pctChange >= 0 ? '▲ +' : '▼ '}$pctChange% vs last week',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: pctChange >= 0 ? kGreen : kPink,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(height: 120, child: BarChart(_volumeBars())),
      ],
    );
  }

  BarChartData _volumeBars() {
    final vols = widget.weeklyVolume;
    final maxVal = vols.reduce((a, b) => a > b ? a : b);

    return BarChartData(
      maxY: maxVal * 1.15 + 1,
      minY: 0,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => kBgElevated,
          getTooltipItem: (group, _, rod, _) => BarTooltipItem(
            '${_formatThousands(rod.toY.round())} lbs',
            const TextStyle(
              color: kTextPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              final weeksAgo = vols.length - 1 - i;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  weeksAgo == 0 ? 'NOW' : '-${weeksAgo}w',
                  style: const TextStyle(fontSize: 8, color: kTextMuted),
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
}
