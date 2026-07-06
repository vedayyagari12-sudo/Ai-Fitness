import 'package:flutter/material.dart';
import '../../log_workout_screen.dart';
import '../../workout_history_screen.dart';
import '../../exercise_stats_screen.dart';
import '../../theme/app_theme.dart';
import 'segmented_bar.dart';

/// Workouts tab — LOG / HISTORY segments (The Outsiders style).
class WorkoutsTabScreen extends StatefulWidget {
  const WorkoutsTabScreen({super.key});

  @override
  State<WorkoutsTabScreen> createState() => _WorkoutsTabScreenState();
}

class _WorkoutsTabScreenState extends State<WorkoutsTabScreen> {
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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Text(
                    'WORKOUTS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExerciseStatsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.query_stats, size: 20),
                    color: AppColors.textSecondary,
                    tooltip: 'Exercise stats',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SegmentedBar(
              labels: const ['LOG', 'HISTORY'],
              index: _seg,
              onChanged: (i) => setState(() => _seg = i),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: IndexedStack(
                index: _seg,
                children: const [
                  LogWorkoutScreen(embedded: true),
                  WorkoutHistoryScreen(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
