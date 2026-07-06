import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StreakChip extends StatelessWidget {
  const StreakChip({
    super.key,
    required this.count,
    required this.isKeptToday,
    this.onTap,
  });

  final int count;
  final bool isKeptToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              size: 14,
              color: isKeptToday ? kLime : kTextMuted,
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
