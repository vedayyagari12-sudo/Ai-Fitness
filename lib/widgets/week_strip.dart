import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Cal-AI-style "your week" strip: one circle per day for the last 7 days,
/// filled with a check on days the user logged a workout or a meal.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.activity, this.streak = 0});

  /// Last 7 days, index 0 = 6 days ago, index 6 = today.
  final List<bool> activity;
  final int streak;

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final activeCount = activity.where((a) => a).length;

    return Container(
      decoration: BoxDecoration(
        gradient: kHeroCardGradient(kSteel),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
        boxShadow: kGlassShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('YOUR WEEK', style: kLabelSmall),
              Flexible(
                child: Text(
                  streak > 0
                      ? '🔥 $streak day streak'
                      : '$activeCount/7 days active',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: streak > 0 ? kOrange : kTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Seven fixed 38px circles need 266px of card — more than a 320dp
          // phone has once padding is taken out, so the diameter is derived
          // from the width actually available.
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 4.0;
              final diameter = ((constraints.maxWidth - gap * 6) / 7).clamp(
                26.0,
                38.0,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    _day(
                      today.subtract(Duration(days: 6 - i)),
                      active: i < activity.length && activity[i],
                      isToday: i == 6,
                      diameter: diameter,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _day(
    DateTime date, {
    required bool active,
    required bool isToday,
    required double diameter,
  }) {
    return Column(
      children: [
        Text(
          _initials[date.weekday - 1],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isToday ? kLime : kTextMuted,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? kLime : kBgHighlight,
            border: isToday && !active
                ? Border.all(color: kLime, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: active
              ? Icon(
                  Icons.check_rounded,
                  size: diameter * 0.53,
                  color: Colors.black,
                )
              : Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: diameter * 0.42,
                    fontWeight: FontWeight.w700,
                    color: isToday ? kTextPrimary : kTextMuted,
                  ),
                ),
        ),
      ],
    );
  }
}
