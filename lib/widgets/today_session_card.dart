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
        border: Border.all(color: kBorder),
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          Text(
            meta,
            style: const TextStyle(fontSize: 12, color: kTextSecondary),
          ),
          if (note.isNotEmpty)
            Text(
              note,
              style: const TextStyle(fontSize: 11, color: kTextMuted),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onStart,
            child: Container(
              decoration: BoxDecoration(
                color: kBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Text(
                'Start →',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
