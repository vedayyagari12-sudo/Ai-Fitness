import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/readiness_data.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../utils/readiness_takeaway.dart';

/// Hero card on TODAY: three concentric progress rings around the readiness
/// score, corner stats, a one-line verdict, a color legend, and an info
/// sheet explaining exactly how the number is calculated.
class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key, required this.data});

  final ReadinessData data;

  /// The ring at the narrowest phone this app supports (320dp, 16dp page
  /// padding, 16dp card padding — 256dp of content). Never shrinks below
  /// this, so nothing regresses versus before this card became responsive.
  static const double _minDiameter = 176.0;

  /// Cap on wide phones/tablets/desktop web. AmbientBackground already caps
  /// page content at 560dp, so this is the practical ceiling — without it
  /// the ring would grow to fill an unbounded desktop window and dwarf the
  /// stat rows around it.
  static const double _maxDiameter = 224.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: kHeroCardGradient(kSteel),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
        boxShadow: kGlassShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats sit in rows above and below the ring rather than at the
          // corners of a Stack — at readable sizes they'd collide with it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _stat(
                  value: data.fueledValue,
                  label: 'FUELED',
                  sub: data.caloriesLabel,
                  valueColor: kLime,
                ),
              ),
              Expanded(
                child: _stat(
                  value: data.loadValue,
                  label: 'LOAD',
                  sub: data.loadLabel,
                  valueColor: kGold,
                  subColor: kGold,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Concentric rings + score, animated on load. Sized off the card's
          // real width instead of a fixed 176 — on anything wider than the
          // narrowest supported phone that fixed size left a wide strip of
          // dead space either side of the ring; scaling it up closes that
          // gap by making the hero element actually fill its space, rather
          // than papering over the emptiness with more widgets.
          LayoutBuilder(
            builder: (context, constraints) {
              final diameter = (constraints.maxWidth * 0.64).clamp(
                _minDiameter,
                _maxDiameter,
              );
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => SizedBox(
                  width: diameter,
                  height: diameter,
                  child: CustomPaint(
                    painter: ReadinessRingPainter(
                      calories: data.caloriesProgress * t,
                      protein: data.proteinProgress * t,
                      sessions: data.sessionsProgress * t,
                    ),
                    child: Center(
                      // Pinned to the hole and to no text scaling, the same
                      // guard MacroDonut uses. The ring is fixed geometry, so
                      // an accessibility text setting cannot be allowed to
                      // grow the number into it: at 1.3x a three-digit score
                      // measured ~118dp against a ~102dp hole and painted
                      // straight over the inner rings. Nothing throws when
                      // that happens — the paragraph just overflows its box —
                      // so an overflow test cannot catch it.
                      child: SizedBox(
                        width:
                            ReadinessRingPainter.holeDiameter(diameter) * 0.86,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(data.score * t).round()}',
                                textScaler: TextScaler.noScaling,
                                style: kStatXLarge.copyWith(
                                  // Scales with the ring so the number keeps
                                  // the same visual weight relative to it,
                                  // instead of looking proportionally smaller
                                  // as the ring grows.
                                  fontSize: diameter * 0.295,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: kLime.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'READY',
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                    color: kLime,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          // The corner stats above/below give the three raw numbers; this
          // gives the one thing they don't — an overall verdict — which is
          // what actually fills the space around a bigger ring without
          // just repeating data already on the card.
          Text(
            readinessTakeaway(
              calories: data.caloriesProgress,
              protein: data.proteinProgress,
              sessions: data.sessionsProgress,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _stat(
                  value: data.proteinValue,
                  label: 'PROTEIN',
                  sub: data.proteinTarget,
                  valueColor: kCyan,
                ),
              ),
              Expanded(
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
          const SizedBox(height: 14),
          // Ring color legend — what each ring measures. The whole row is the
          // "how is this scored?" tap target (no floating icon to collide with
          // the corner stats).
          GestureDetector(
            onTap: () => _showInfoSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 6,
              children: [
                _legend(kLime, 'Calories'),
                _legend(kCyan, 'Protein'),
                _legend(kPink, 'Trained today'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'How it works',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: kTextSecondary)),
      ],
    );
  }

  void _showInfoSheet(BuildContext context) {
    showAppSheet<void>(
      context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOW YOUR DAILY SCORE WORKS', style: kLabelSmall),
            const SizedBox(height: 6),
            Text(
              'A fresh 100 is up for grabs every single day: train once, '
              'hit your calories, hit your protein. It resets to 0 each '
              'morning.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _componentRow(
              color: kPink,
              weight: '40%',
              name: 'Train today',
              detail: data.trainingDetail,
              progress: data.sessionsProgress,
            ),
            const SizedBox(height: 14),
            _componentRow(
              color: kLime,
              weight: '35%',
              name: 'Calories',
              detail: data.fuelDetail,
              progress: data.caloriesProgress,
            ),
            const SizedBox(height: 14),
            _componentRow(
              color: kCyan,
              weight: '25%',
              name: 'Protein',
              detail: data.proteinDetail,
              progress: data.proteinProgress,
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Score today: ${data.score} / 100',
                style: TextStyle(
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
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: kFillSubtle,
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
    Color? valueColor,
    Color? subColor,
    bool alignEnd = false,
  }) {
    valueColor ??= kTextPrimary;
    subColor ??= kTextMuted;
    final align = alignEnd ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            // Bumped from 29: this and the center score are the numbers the
            // card exists to show, so they carry the most visual weight on
            // it. The FittedBox already guards a 6-digit worst case (a raw
            // training-load value) from overflowing at 320dp/1.3x text.
            style: kStatSmall.copyWith(fontSize: 32, color: valueColor),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: kLabelSmall.copyWith(fontSize: 12),
          textAlign: align,
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: kStatCaption.copyWith(fontSize: 14, color: subColor),
          textAlign: align,
        ),
      ],
    );
  }
}

@visibleForTesting
class ReadinessRingPainter extends CustomPainter {
  ReadinessRingPainter({
    required this.calories,
    required this.protein,
    required this.sessions,
  });

  final double calories; // outer (lime)
  final double protein; // middle (cyan)
  final double sessions; // inner (pink)

  // Ratios rather than fixed pixels, because the ring is responsive: held at
  // a fixed 9/5 they looked proportionally thin once it grew past its old
  // fixed 176, the way a 9px line looks thinner on a bigger circle even
  // though nothing about it changed.
  static const double _strokeRatio = 0.051;
  static const double _gapRatio = 0.028;

  /// Diameter of the empty middle, given the ring's overall [size].
  ///
  /// Exposed so the card can size the score to the hole from the same
  /// numbers the painter draws with. Deriving it independently there is how
  /// a centre readout silently ends up overlapping the innermost ring the
  /// next time a ratio here changes.
  static double holeDiameter(double size) =>
      size - 6 * (_strokeRatio * size) - 4 * (_gapRatio * size);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * _strokeRatio;
    final gap = size.width * _gapRatio;
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2 - stroke / 2;
    final blur = size.width * 0.018;
    _ring(canvas, center, outer, stroke, blur, calories, kLime);
    _ring(canvas, center, outer - (stroke + gap), stroke, blur, protein, kCyan);
    _ring(
      canvas,
      center,
      outer - 2 * (stroke + gap),
      stroke,
      blur,
      sessions,
      kPink,
    );
  }

  void _ring(
    Canvas canvas,
    Offset center,
    double radius,
    double stroke,
    double blurSigma,
    double progress,
    Color color,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = kChartTrack;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (progress <= 0) return;
    final sweep = progress.clamp(0.0, 1.0) * 2 * math.pi;
    const start = -math.pi / 2;

    // A soft halo under the crisp stroke — the single biggest visual lift
    // for a ring on a near-black card. Its own arc, not a blur on the crisp
    // one: blurring the crisp stroke directly would soften its edge too and
    // make the ring itself look out of focus rather than lit from behind.
    // Width and blur both stay inside the ring pitch (stroke + gap). At the
    // old 2.1x width with a hardcoded 8px blur the lime glow reached the
    // cyan ring and the cyan glow reached the pink, blending exactly the
    // three colours the legend underneath is naming — and the blur being a
    // fixed constant while everything around it was a ratio meant it read
    // tighter at the 224dp cap than at the 176dp floor.
    final glowWidth = stroke * 1.4;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    canvas.drawArc(rect, start, sweep, false, glow);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = arcGradient(color, start, sweep).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arc);
  }

  /// The gradient painted along one ring's drawn arc.
  ///
  /// startAngle/endAngle are pinned to the arc's own `[start, start + sweep]`
  /// — NOT `[0, 2*pi]` — so stop 1.0 (full saturation) lands exactly at the
  /// arc's end regardless of how far it sweeps. Spanning the full circle was
  /// the wrong-looking first attempt: a short arc then only ever samples the
  /// pale end of the gradient and never reaches full colour, since its own
  /// endAngle is nowhere near 2*pi. SweepGradient's angle convention (0 =
  /// positive x-axis, clockwise) is the same one Canvas.drawArc already uses
  /// for [start] and [sweep], so the two line up without a transform.
  ///
  /// A standalone method — not inlined into the Paint chain — specifically
  /// so a test can construct one and assert on its angles: a `Shader` is
  /// opaque once built, so this is the only stage where the bug above is
  /// actually visible to a test.
  @visibleForTesting
  static SweepGradient arcGradient(Color color, double start, double sweep) {
    return SweepGradient(
      startAngle: start,
      endAngle: start + sweep,
      colors: [color.withValues(alpha: 0.55), color],
    );
  }

  @override
  bool shouldRepaint(ReadinessRingPainter old) =>
      old.calories != calories ||
      old.protein != protein ||
      old.sessions != sessions;
}
