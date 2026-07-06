import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TrendCard extends StatefulWidget {
  const TrendCard({super.key});

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  int _selected = 0; // 0 WEIGHT, 1 CALORIES, 2 VOLUME
  static const _segments = ['WEIGHT', 'CALORIES', 'VOLUME'];

  // Hardcoded 8-week weight sample (lb).
  static const _weight = <double>[
    184.4,
    184.0,
    183.3,
    183.0,
    182.4,
    182.1,
    181.5,
    181.0,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
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
                  color: kLime.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kLime, width: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                child: const Text(
                  'CUTTING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: kLime,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _segmentedControl(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '181.0 lb',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '-0.4 lb / wk',
                    style: TextStyle(fontSize: 12, color: kPink),
                  ),
                  Text('-3.2 lb total', style: kBodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 100, child: LineChart(_chartData())),
          const SizedBox(height: 8),
          _legend(),
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
                    color: _selected == i ? kTextPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _segments[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _selected == i ? kBgDeep : kTextMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  LineChartData _chartData() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      minX: 0,
      maxX: (_weight.length - 1).toDouble(),
      // Dashed horizontal "maintain zone" band.
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(
            y1: 180.5,
            y2: 181.5,
            color: kBorder.withValues(alpha: 0.25),
          ),
        ],
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 181.0,
            color: kBorder,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < _weight.length; i++)
              FlSpot(i.toDouble(), _weight[i]),
          ],
          isCurved: true,
          color: kCyan,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  Widget _legend() {
    return Row(
      children: [
        _legendDot(kCyan, '● Actual'),
        const SizedBox(width: 12),
        _legendDot(kBorder, '▪ Maintain zone'),
        const SizedBox(width: 12),
        Text(
          'Goal 174 lb',
          style: const TextStyle(fontSize: 10, color: kTextMuted),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 10, color: color),
    );
  }
}
