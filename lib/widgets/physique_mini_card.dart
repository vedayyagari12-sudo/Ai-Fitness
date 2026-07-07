import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PhysiqueMiniCard extends StatelessWidget {
  const PhysiqueMiniCard({
    super.key,
    this.bodyFat,
    this.delta,
    this.deltaPositive = true,
    this.points = const [],
  });

  /// Latest body fat %, null when the user has no scans yet.
  final double? bodyFat;
  final String? delta; // "-0.6% this week"
  final bool deltaPositive; // true = trending the right way
  final List<double> points; // body-fat sparkline (last scans)

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PHYSIQUE', style: kLabelSmall),
          const SizedBox(height: 4),
          if (bodyFat == null) ...[
            const Text(
              '—',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: kTextMuted,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Scan your physique to track body fat',
              style: TextStyle(fontSize: 11, color: kTextMuted),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 32),
          ] else ...[
            Text(
              '${bodyFat!.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kPink,
              ),
            ),
            if (delta != null)
              Text(
                delta!,
                style: TextStyle(
                  fontSize: 11,
                  color: deltaPositive ? AppColors.success : AppColors.danger,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: points.length >= 2
                  ? LineChart(_sparklineData())
                  : const SizedBox.shrink(),
            ),
          ],
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
      maxX: (points.length - 1).toDouble(),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < points.length; i++)
              FlSpot(i.toDouble(), points[i]),
          ],
          isCurved: true,
          preventCurveOverShooting: true,
          color: kPink,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}
