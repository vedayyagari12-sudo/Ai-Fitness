import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Decorative, code-drawn illustrations (no image assets) used to give
/// empty states and highlight cards some visual life — a scanner motif,
/// an EKG-style pulse wave, and ghost chart bars.

// ── Scanner motif ───────────────────────────────────────────────────────────

/// A circular "scanner" illustration: soft glow, dashed ring, a center icon
/// and small orbiting dots in the macro colors. Sized via [size].
class ScanMotif extends StatefulWidget {
  const ScanMotif({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 150,
    this.showDots = true,
  });

  final IconData icon;
  final Color accent;
  final double size;
  final bool showDots;

  @override
  State<ScanMotif> createState() => _ScanMotifState();
}

class _ScanMotifState extends State<ScanMotif>
    with SingleTickerProviderStateMixin {
  // Slow rotation of the dashed ring — quiet life, not a spinner.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient glow
          Container(
            width: s * 0.62,
            height: s * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accent.withValues(alpha: 0.10),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.22),
                  blurRadius: s * 0.28,
                  spreadRadius: s * 0.04,
                ),
              ],
            ),
          ),
          // Rotating dashed ring
          AnimatedBuilder(
            animation: _spin,
            builder: (context, _) => Transform.rotate(
              angle: _spin.value * 2 * math.pi,
              child: CustomPaint(
                size: Size.square(s),
                painter: _DashedRingPainter(
                  color: widget.accent.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          // Center icon
          Container(
            width: s * 0.44,
            height: s * 0.44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBgElevated,
              border: Border.all(
                color: widget.accent.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(widget.icon, size: s * 0.22, color: widget.accent),
          ),
          // Orbiting macro dots (protein / carbs / fat colors)
          if (widget.showDots) ...[
            _dot(s, angleDeg: 25, color: kLime),
            _dot(s, angleDeg: 145, color: kCyan),
            _dot(s, angleDeg: 265, color: kGold),
          ],
        ],
      ),
    );
  }

  Widget _dot(double s, {required double angleDeg, required Color color}) {
    final rad = angleDeg * math.pi / 180;
    final r = s * 0.38;
    return Transform.translate(
      offset: Offset(math.cos(rad) * r, math.sin(rad) * r),
      child: Container(
        width: s * 0.075,
        height: s * 0.075,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const segments = 20;
    const gapRatio = 0.45;
    final sweep = 2 * math.pi / segments * (1 - gapRatio);
    for (var i = 0; i < segments; i++) {
      final start = 2 * math.pi / segments * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => old.color != color;
}

// ── Pulse wave ──────────────────────────────────────────────────────────────

/// An EKG-style squiggle (flat → bump → spike → flat), like the waveform on
/// activity-tracker cards. Purely decorative.
class PulseWave extends StatelessWidget {
  const PulseWave({
    super.key,
    required this.color,
    this.width = 120,
    this.height = 44,
    this.strokeWidth = 2.5,
  });

  final Color color;
  final double width;
  final double height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _PulsePainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h * 0.55;

    final path = Path()
      ..moveTo(0, mid)
      ..lineTo(w * 0.22, mid)
      // small bump
      ..quadraticBezierTo(w * 0.28, mid - h * 0.18, w * 0.34, mid)
      ..lineTo(w * 0.42, mid)
      // main spike
      ..lineTo(w * 0.50, mid - h * 0.48)
      ..lineTo(w * 0.58, mid + h * 0.34)
      ..lineTo(w * 0.64, mid)
      ..lineTo(w * 0.76, mid)
      // trailing wave
      ..quadraticBezierTo(w * 0.84, mid - h * 0.14, w * 0.90, mid)
      ..lineTo(w, mid);

    // Soft glow underlay
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// ── Ghost bars ──────────────────────────────────────────────────────────────

/// Faint placeholder bars for empty chart states — hints at what the chart
/// will look like instead of leaving a blank void behind the hint text.
class GhostBars extends StatelessWidget {
  const GhostBars({super.key, this.height = 90, this.color});

  final double height;
  final Color? color;

  static const _heights = [0.35, 0.6, 0.45, 0.8, 0.55, 0.7, 0.4];

  @override
  Widget build(BuildContext context) {
    // Default must resolve here, not in the constructor — theme tokens are
    // getters and a default parameter value has to be a compile-time constant.
    final c = color == null ? kFillMuted : color!.withValues(alpha: 0.05);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final f in _heights)
            Container(
              width: 18,
              height: height * f,
              decoration: BoxDecoration(
                color: c,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
