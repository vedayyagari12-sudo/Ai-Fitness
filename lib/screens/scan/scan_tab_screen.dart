import 'package:flutter/material.dart';
import '../../calorie_scan_screen.dart';
import '../../physique_scan_screen.dart';
import '../../theme/app_theme.dart';
import '../workouts/segmented_bar.dart';

/// Scan tab — FOOD / PHYSIQUE segments (The Outsiders style).
class ScanTabScreen extends StatefulWidget {
  const ScanTabScreen({super.key});

  @override
  State<ScanTabScreen> createState() => _ScanTabScreenState();
}

class _ScanTabScreenState extends State<ScanTabScreen> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Text(
                'SCAN',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedBar(
              labels: const ['FOOD', 'PHYSIQUE'],
              index: _seg,
              onChanged: (i) => setState(() => _seg = i),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: IndexedStack(
                index: _seg,
                children: const [
                  CalorieScanScreen(embedded: true),
                  PhysiqueScanScreen(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
