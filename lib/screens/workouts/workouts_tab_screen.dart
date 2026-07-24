import 'package:flutter/material.dart';
import '../../log_workout_screen.dart';
import '../../workout_history_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import 'ai_session_view.dart';
import 'segmented_bar.dart';

/// TRAIN tab — TODAY (AI session) / LOG / HISTORY segments.
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
      body: AmbientBackground(
        accent: kCyan,
        accent2: kPurple,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Text(
                  'TRAIN',
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
                labels: const ['TODAY', 'LOG', 'HISTORY'],
                index: _seg,
                // HISTORY reloads itself via historyTick whenever a workout is
                // written, so no refresh is needed on segment entry.
                onChanged: (i) => setState(() => _seg = i),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: IndexedStack(
                  index: _seg,
                  children: [
                    AiSessionView(
                      onViewHistory: () => setState(() => _seg = 2),
                    ),
                    const LogWorkoutScreen(embedded: true),
                    const WorkoutHistoryScreen(embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
