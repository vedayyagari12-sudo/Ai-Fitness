import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One tabbed series for the trend card (WEIGHT / CALORIES / VOLUME).
class TrendSeries {
  const TrendSeries({
    required this.values,
    required this.unit,
    this.decimals = 1,
  });

  final List<double> values;
  final String unit; // "kg", "kcal", "kg vol"
  final int decimals;

  bool get hasData => values.length >= 2;
  double get latest => values.isEmpty ? 0 : values.last;
  double get total => values.length < 2 ? 0 : values.last - values.first;
  double get perWeek {
    if (values.length < 2) return 0;
    // Series span ≤ 30 days — approximate weekly rate from overall slope.
    final weeks = (values.length / 7).clamp(1, 5);
    return total / weeks;
  }
}

class TrendCard extends StatefulWidget {
  const TrendCard({
    super.key,
    required this.goal,
    required this.weight,
    required this.calories,
    required this.volume,
  });

  final String goal; // "bulk" | "cut" | "maintain" | "athletic"
  final TrendSeries weight;
  final TrendSeries calories;
  final TrendSeries volume;

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard>
    with SingleTickerProviderStateMixin {
  int _selected = 0;
  static const _segments = ['WEIGHT', 'CALORIES', 'VOLUME'];

  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  TrendSeries get _series => switch (_selected) {
        1 => widget.calories,
        2 => widget.volume,
        _ => widget.weight,
      };

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
    final s = _series;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('8-WEEK TREND', style: kLabelSmall),
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
          if (!s.hasData)
            _emptyState()
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${s.latest.toStringAsFixed(s.decimals)} ${s.unit}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${s.perWeek >= 0 ? '+' : ''}${s.perWeek.toStringAsFixed(s.decimals)} ${s.unit}/wk',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kPink,
                      ),
                    ),
                    Text(
                      '${s.total >= 0 ? '+' : ''}${s.total.toStringAsFixed(s.decimals)} ${s.unit} total',
                      style: const TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: AnimatedBuilder(
                animation: _draw,
                builder: (context, _) => LineChart(_chartData(s, _draw.value)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '● Actual',
                  style: TextStyle(fontSize: 10, color: kCyan),
                ),
                const SizedBox(width: 12),
                const Text(
                  '▪ Baseline',
                  style: TextStyle(fontSize: 10, color: kTextMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    final hints = [
      'Log your bodyweight to see your weight trend',
      'Scan a meal in the SCAN tab to track calories',
      'Log workouts in the TRAIN tab to track volume',
    ];
    return SizedBox(
      height: 148,
      child: Center(
        child: Text(
          hints[_selected],
          style: const TextStyle(fontSize: 12, color: kTextMuted),
          textAlign: TextAlign.center,
        ),
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
                onTap: () {
                  setState(() => _selected = i);
                  _draw.forward(from: 0);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selected == i ? kBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
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
        ],
      ),
    );
  }

  LineChartData _chartData(TrendSeries s, double t) {
    // Reveal points left → right as t goes 0 → 1.
    final count = (s.values.length * t).ceil().clamp(2, s.values.length);
    final shown = s.values.sublist(0, count);
    final minY = s.values.reduce((a, b) => a < b ? a : b);
    final maxY = s.values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.2 + 0.001;
    return LineChartData(
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
      lineTouchData: const LineTouchData(enabled: false),
      minX: 0,
      maxX: (s.values.length - 1).toDouble(),
      minY: minY - pad,
      maxY: maxY + pad,
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: s.values.first,
            color: kBorder,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < shown.length; i++)
              FlSpot(i.toDouble(), shown[i]),
          ],
          isCurved: true,
          preventCurveOverShooting: true,
          color: kCyan,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}
