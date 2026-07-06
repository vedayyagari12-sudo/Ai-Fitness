import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PhysiqueMiniCard extends StatelessWidget {
  const PhysiqueMiniCard({
    super.key,
    this.value = '18.2%',
    this.delta = '-0.6% this week',
  });

  final String value;
  final String delta;

  // Hardcoded sparkline sample (descending body-fat trend).
  static const _points = <double>[19.4, 19.1, 19.0, 18.8, 18.6, 18.4, 18.3, 18.2];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PHYSIQUE', style: kLabelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          Text(delta, style: const TextStyle(fontSize: 11, color: kPink)),
          const SizedBox(height: 8),
          SizedBox(height: 32, child: LineChart(_sparklineData())),
        ],
      ),
    );
  }

  LineChartData _sparklineData() {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      minX: 0,
      maxX: (_points.length - 1).toDouble(),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < _points.length; i++)
              FlSpot(i.toDouble(), _points[i]),
          ],
          isCurved: true,
          color: kPink,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}
