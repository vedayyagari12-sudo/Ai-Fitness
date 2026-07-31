import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact physique summary on TODAY: body fat, latest scan score, change
/// vs the previous scan and a sparkline once there's enough history.
class PhysiqueMiniCard extends StatelessWidget {
  const PhysiqueMiniCard({
    super.key,
    this.bodyFat,
    this.score,
    this.scanCount = 0,
    this.delta,
    this.deltaPositive = true,
    this.points = const [],
  });

  /// Latest body fat %, null when the user has no scans yet.
  final double? bodyFat;
  final int? score; // latest overall physique score /100
  final int scanCount;
  final String? delta; // "-0.6% vs last scan"
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
          // Half-screen card: "PHYSIQUE" alongside "12 scans" doesn't fit at
          // full size and was breaking mid-word ("PHYSIQU / E"). Scale the
          // pair down together instead.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text('PHYSIQUE', maxLines: 1, style: kLabelSmall),
                if (scanCount > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$scanCount scan${scanCount == 1 ? '' : 's'}',
                    maxLines: 1,
                    style: TextStyle(fontSize: 12, color: kTextMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (bodyFat == null) ...[
            Text(
              '—',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: kTextMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan your physique in the SCAN tab to track body fat '
              'and your score',
              style: TextStyle(fontSize: 13, color: kTextMuted),
            ),
          ] else ...[
            // This card is half the screen wide, so the number + caption pair
            // is scaled down rather than allowed to run off the edge.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${bodyFat!.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: kPink,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: EdgeInsets.only(bottom: 1),
                    child: Text(
                      'body fat',
                      style: TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                  ),
                ],
              ),
            ),
            if (score != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: kLime),
                  const SizedBox(width: 3),
                  // Scaled rather than ellipsised — "Score 55…" hides the
                  // number, which is the whole point of the line.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Score $score/100',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kLime,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (delta != null) ...[
              const SizedBox(height: 2),
              Text(
                delta!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: deltaPositive ? kGreen : kPink,
                ),
              ),
            ],
            const SizedBox(height: 8),
            points.length >= 2
                ? SizedBox(height: 30, child: LineChart(_sparklineData()))
                : Text(
                    // Not height-capped: at 30px this two-line hint was
                    // clipped to "Scan again to".
                    scanCount <= 1
                        ? 'Scan again to unlock your trend'
                        : 'Trend appears after another scan',
                    style: TextStyle(fontSize: 12, color: kTextMuted),
                  ),
          ],
        ],
      ),
    );
  }

  LineChartData _sparklineData() {
    final minY = points.reduce((a, b) => a < b ? a : b);
    final maxY = points.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.3 + 0.3;
    return LineChartData(
      minY: minY - pad,
      maxY: maxY + pad,
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
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [kPink.withValues(alpha: 0.25), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}
