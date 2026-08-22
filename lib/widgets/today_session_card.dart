import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TodaySessionCard extends StatelessWidget {
  const TodaySessionCard({
    super.key,
    this.title = 'Upper Push',
    this.meta = '48 min · 7 moves',
    this.note = 'Tuned to your physique scan',
    this.startLabel = 'Start →',
    this.onStart,
    this.workoutDone = false,
    this.onLogMeal,
  });

  final String title;
  final String meta;
  final String note;
  final String startLabel;
  final VoidCallback? onStart;

  /// True once a session has been logged today — swaps the card to a
  /// "done, now log a meal" state instead of the workout CTA.
  final bool workoutDone;

  /// Called with a meal type ("Breakfast"/"Lunch"/"Dinner"/"Snack") when the
  /// user taps one of the quick-log chips in the [workoutDone] state.
  final ValueChanged<String>? onLogMeal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: workoutDone ? _doneContent() : _sessionContent(),
    );
  }

  Widget _sessionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TODAY'S SESSION", style: kLabelSmall),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
          ),
        ),
        Text(meta, style: kStatCaption),
        if (note.isNotEmpty)
          Text(note, style: TextStyle(fontSize: 13, color: kTextMuted)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onStart,
          child: Container(
            decoration: BoxDecoration(
              color: kBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              startLabel,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _doneContent() {
    const types = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TODAY'S SESSION", style: kLabelSmall),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 18, color: kLime),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Workout logged',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Fuel your recovery — log a meal',
          style: TextStyle(fontSize: 12, color: kTextMuted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in types)
              GestureDetector(
                onTap: () => onLogMeal?.call(t),
                child: Container(
                  decoration: BoxDecoration(
                    color: kBgHighlight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kBorder),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
