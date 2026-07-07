import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/readiness_data.dart';
import '../theme/app_theme.dart';

/// Hero card on TODAY: three concentric progress rings (calories · protein ·
/// body composition) around the readiness score, with stats in each corner.
class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key, required this.data});

  final ReadinessData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Concentric rings + score, animated on load.
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _RingPainter(
                    calories: data.caloriesProgress * t,
                    protein: data.proteinProgress * t,
                    bodyFat: data.bodyFatProgress * t,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(data.score * t).round()}',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'READY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            color: kLime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Corner stats
          Positioned(
            left: 0,
            top: 0,
            child: _stat(
              value: data.fueledValue,
              label: 'FUELED',
              sub: data.caloriesLabel,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _stat(
              value: data.loadValue,
              label: 'LOAD',
              sub: data.loadLabel,
              valueColor: kGold,
              subColor: kGold,
              alignEnd: true,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: _stat(
              value: data.proteinValue,
              label: 'PROTEIN',
              sub: data.proteinTarget,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _stat(
              value: data.bodyFatValue,
              label: 'BODY FAT',
              sub: data.bodyFatDelta,
              valueColor: kPink,
              subColor: kPink,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat({
    required String value,
    required String label,
    required String sub,
    Color valueColor = kTextPrimary,
    Color subColor = kTextMuted,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        Text(label, style: kLabelSmall),
        Text(sub, style: TextStyle(fontSize: 11, color: subColor)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.calories,
    required this.protein,
    required this.bodyFat,
  });

  final double calories; // outer (lime)
  final double protein; // middle (cyan)
  final double bodyFat; // inner (pink)

  static const _stroke = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2 - _stroke / 2;
    _ring(canvas, center, outer, calories, kLime);
    _ring(canvas, center, outer - (_stroke + _gap), protein, kCyan);
    _ring(canvas, center, outer - 2 * (_stroke + _gap), bodyFat, kPink);
  }

  void _ring(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
    Color color,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = kBgHighlight;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      (progress.clamp(0.0, 1.0)) * 2 * math.pi,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.calories != calories ||
      old.protein != protein ||
      old.bodyFat != bodyFat;
}
