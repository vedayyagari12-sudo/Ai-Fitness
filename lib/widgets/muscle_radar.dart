import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One muscle group's development, 0-10.
typedef MuscleReading = ({String label, double score});

/// Nine muscle scores as one shape, so imbalance is visible at a glance
/// rather than inferred by comparing nine numbers.
///
/// Hand-painted rather than fl_chart's RadarChart, which scales its web to
/// whatever the largest value in the data happens to be. That makes every
/// physique look equally developed: someone scoring 4 across the board draws
/// exactly the same shape as someone scoring 9. The axis here is pinned to
/// 0-10, so the size of the web means something and two scans are comparable.
class MuscleRadar extends StatelessWidget {
  const MuscleRadar({super.key, required this.readings, this.accent});

  final List<MuscleReading> readings;

  /// Single series, so a single hue — no series identity to encode.
  final Color? accent;

  /// A radar needs three axes to enclose any area at all; below that it is a
  /// line or a dot and says nothing.
  static const int minAxes = 3;

  bool get _canRender => readings.length >= minAxes;

  @override
  Widget build(BuildContext context) {
    if (!_canRender) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Square, and never taller than the space it is given.
        final side = math.min(
          constraints.maxWidth,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 260.0,
        );
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: MuscleRadarPainter(
                readings: readings,
                accent: accent ?? kPink,
                fill: ChartFill.pink,
                grid: kChartGrid,
                labelColour: kTextSecondary,
                surface: kBgCard,
              ),
              // The web carries no text of its own, so the shape needs a
              // spoken description for anyone not seeing it.
              child: Semantics(
                label: readings
                    .map(
                      (r) => '${r.label} ${r.score.toStringAsFixed(1)} of 10',
                    )
                    .join(', '),
                container: true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

@visibleForTesting
class MuscleRadarPainter extends CustomPainter {
  MuscleRadarPainter({
    required this.readings,
    required this.accent,
    required this.fill,
    required this.grid,
    required this.labelColour,
    required this.surface,
    this.maxScore = 10,
  });

  final List<MuscleReading> readings;
  final Color accent;
  final Color fill;
  final Color grid;
  final Color labelColour;
  final Color surface;
  final double maxScore;

  /// Room outside the web for the axis labels.
  static const double labelInset = 30;

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.length < MuscleRadar.minAxes) return;

    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - labelInset;
    if (radius <= 0) return;

    final n = readings.length;
    // Start at 12 o'clock and go clockwise, so the first muscle reads first.
    double angleAt(int i) => -math.pi / 2 + (2 * math.pi * i / n);
    Offset pointAt(int i, double t) => Offset(
      centre.dx + radius * t * math.cos(angleAt(i)),
      centre.dy + radius * t * math.sin(angleAt(i)),
    );

    // ── grid ────────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;

    // Rings at every quarter of the scale. Solid hairlines: a dashed grid
    // reads as a threshold, and none of these is one.
    for (final t in const [0.25, 0.5, 0.75, 1.0]) {
      final ring = Path();
      for (var i = 0; i < n; i++) {
        final p = pointAt(i, t);
        i == 0 ? ring.moveTo(p.dx, p.dy) : ring.lineTo(p.dx, p.dy);
      }
      ring.close();
      canvas.drawPath(ring, gridPaint);
    }

    for (var i = 0; i < n; i++) {
      canvas.drawLine(centre, pointAt(i, 1), gridPaint);
    }

    // ── the web ─────────────────────────────────────────────────────────
    final web = Path();
    for (var i = 0; i < n; i++) {
      // Clamped: a score outside 0-10 would otherwise draw outside the grid
      // and read as off the scale rather than as bad data.
      final t = (readings[i].score / maxScore).clamp(0.0, 1.0);
      final p = pointAt(i, t);
      i == 0 ? web.moveTo(p.dx, p.dy) : web.lineTo(p.dx, p.dy);
    }
    web.close();

    canvas.drawPath(web, Paint()..color = fill.withValues(alpha: 0.28));
    canvas.drawPath(
      web,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );

    // Vertex dots, each ringed in surface so they stay legible where the web
    // runs close to a grid line.
    for (var i = 0; i < n; i++) {
      final t = (readings[i].score / maxScore).clamp(0.0, 1.0);
      final p = pointAt(i, t);
      canvas.drawCircle(p, 4, Paint()..color = surface);
      canvas.drawCircle(p, 3, Paint()..color = accent);
    }

    // ── labels ──────────────────────────────────────────────────────────
    for (var i = 0; i < n; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: readings[i].label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: labelColour,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: labelInset * 2.4);

      final anchor = Offset(
        centre.dx + (radius + 15) * math.cos(angleAt(i)),
        centre.dy + (radius + 15) * math.sin(angleAt(i)),
      );
      // Centre the label on its spoke, then keep it inside the canvas — at
      // nine axes the left and right ones otherwise hang off the edge.
      final dx = (anchor.dx - painter.width / 2)
          .clamp(0.0, math.max(0.0, size.width - painter.width))
          .toDouble();
      final dy = (anchor.dy - painter.height / 2)
          .clamp(0.0, math.max(0.0, size.height - painter.height))
          .toDouble();
      painter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant MuscleRadarPainter old) =>
      old.readings != readings ||
      old.accent != accent ||
      old.fill != fill ||
      old.grid != grid ||
      old.labelColour != labelColour ||
      old.surface != surface ||
      old.maxScore != maxScore;
}
