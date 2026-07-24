import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Streak counter — always orange per design. When the streak is at risk
/// (no activity yet today), the chip pulses subtly to draw attention.
class StreakChip extends StatefulWidget {
  const StreakChip({
    super.key,
    required this.count,
    required this.isKeptToday,
    this.atRisk = false,
    this.onTap,
  });

  final int count;
  final bool isKeptToday;
  final bool atRisk;
  final VoidCallback? onTap;

  @override
  State<StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<StreakChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.atRisk) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StreakChip old) {
    super.didUpdateWidget(old);
    if (widget.atRisk && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.atRisk && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = widget.atRisk ? 0.15 + _pulse.value * 0.35 : 0.0;
          return Container(
            decoration: BoxDecoration(
              color: kBgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.atRisk
                    ? kOrange.withValues(alpha: 0.3 + _pulse.value * 0.4)
                    : kBorder,
              ),
              boxShadow: widget.atRisk
                  ? [
                      BoxShadow(
                        color: kOrange.withValues(alpha: glow),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: child,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              size: 14,
              color: widget.isKeptToday
                  ? kOrange
                  : kOrange.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 4),
            Text(
              widget.count.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
