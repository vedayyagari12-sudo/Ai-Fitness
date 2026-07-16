import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/readiness_data.dart';
import '../theme/app_theme.dart';

/// Hero card on TODAY: three concentric progress rings around the readiness
/// score, corner stats, a color legend, and an info sheet explaining exactly
/// how the number is calculated.
class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key, required this.data});

  final ReadinessData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 236,
            child: Stack(
              children: [
                // Concentric rings + score, animated on load.
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => SizedBox(
                      width: 168,
                      height: 168,
                      child: CustomPaint(
                        painter: _RingPainter(
                          calories: data.caloriesProgress * t,
                          protein: data.proteinProgress * t,
                          sessions: data.sessionsProgress * t,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(data.score * t).round()}',
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: kTextPrimary,
                                  height: 1.0,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'READY',
                                style: TextStyle(
                                  fontSize: 10,
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
                // Info button — explains the score.
                Positioned(
                  right: 0,
                  top: 44,
                  child: GestureDetector(
                    onTap: () => _showInfoSheet(context),
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.textMuted,
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
                    valueColor: kLime,
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
                    valueColor: kCyan,
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
          ),
          const SizedBox(height: 10),
          // Ring color legend — what each ring measures.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                _legend(kLime, 'Calories'),
                const SizedBox(width: 14),
                _legend(kCyan, 'Protein'),
                const SizedBox(width: 14),
                _legend(kPink, 'Weekly sessions'),
                const SizedBox(width: 14),
                Text(
                  'Tap ⓘ for how it\'s scored',
                  style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
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
          style: const TextStyle(fontSize: 9, color: kTextSecondary),
        ),
      ],
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOW YOUR READINESS IS SCORED', style: kLabelSmall),
            const SizedBox(height: 6),
            Text(
              'Readiness blends three things — hitting your weekly training '
              'goal matters most, then today\'s fueling.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _componentRow(
              color: kPink,
              weight: '60%',
              name: 'Training',
              detail: data.trainingDetail,
              progress: data.sessionsProgress,
            ),
            const SizedBox(height: 14),
            _componentRow(
              color: kLime,
              weight: '25%',
              name: 'Calories',
              detail: data.fuelDetail,
              progress: data.caloriesProgress,
            ),
            const SizedBox(height: 14),
            _componentRow(
              color: kCyan,
              weight: '15%',
              name: 'Protein',
              detail: data.proteinDetail,
              progress: data.proteinProgress,
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Score today: ${data.score} / 100',
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _componentRow({
    required Color color,
    required String weight,
    required String name,
    required String detail,
    required double progress,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            weight,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ],
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
            fontSize: 19,
            fontWeight: FontWeight.w800,
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
    required this.sessions,
  });

  final double calories; // outer (lime)
  final double protein; // middle (cyan)
  final double sessions; // inner (pink)

  static const _stroke = 9.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2 - _stroke / 2;
    _ring(canvas, center, outer, calories, kLime);
    _ring(canvas, center, outer - (_stroke + _gap), protein, kCyan);
    _ring(canvas, center, outer - 2 * (_stroke + _gap), sessions, kPink);
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
      old.sessions != sessions;
}
