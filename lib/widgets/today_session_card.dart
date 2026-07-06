import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TodaySessionCard extends StatelessWidget {
  const TodaySessionCard({
    super.key,
    this.title = 'Upper Push',
    this.meta = '48 min · 7 moves',
    this.note = 'Tuned to your physique scan',
    this.onStart,
  });

  final String title;
  final String meta;
  final String note;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCyan.withValues(alpha: 0.4), width: 0.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S SESSION", style: kLabelSmall),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          Text(meta, style: kBodySmall),
          Text(note, style: kBodySmall),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onStart,
            child: Container(
              decoration: BoxDecoration(
                color: kCyan,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: const Text(
                'Start →',
                style: TextStyle(
                  color: kBgDeep,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
