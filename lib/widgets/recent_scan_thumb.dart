import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RecentScanThumb extends StatelessWidget {
  const RecentScanThumb({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tag,
    this.onTap,
  });

  final String title; // "Chicken Bowl" / "Scan #14"
  final String subtitle; // "642 kcal" / "18.2% BF"
  final String tag; // "meal" / "body"
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _card(),
    );
  }

  Widget _card() {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: kBgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 28,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kBgHighlight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: kBgHighlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(fontSize: 9, color: kTextMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}
