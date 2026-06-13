import 'package:flutter/material.dart';
import '../../calorie_scan_screen.dart';
import '../../log_workout_screen.dart';
import '../../physique_scan_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../workout_history_screen.dart';
import '../scan/photo_check_screen.dart';
import 'workout_setup_screen.dart';

class WorkoutsHubScreen extends StatelessWidget {
  const WorkoutsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Workouts',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [AppColors.textPrimary, AppColors.textSecondary],
                      ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    FeatureHubTile(
                      title: 'AI Workout Generator',
                      subtitle: 'Set intensity & duration, get a custom plan',
                      icon: Icons.bolt,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WorkoutSetupScreen()),
                      ),
                    ),
                    FeatureHubTile(
                      title: 'Log Workout',
                      subtitle: 'Track sets, reps, and weight',
                      icon: Icons.add_circle_outline,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LogWorkoutScreen()),
                      ),
                    ),
                    FeatureHubTile(
                      title: 'Workout History',
                      subtitle: 'Review past sessions and volume',
                      icon: Icons.history,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WorkoutHistoryScreen()),
                      ),
                    ),
                    FeatureHubTile(
                      title: 'Calorie Scanner',
                      subtitle: 'Snap food, get instant nutrition',
                      icon: Icons.camera_alt_outlined,
                      accentColor: AppColors.ringMove,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhotoCheckScreen(
                            title: 'Scan your meal',
                            subtitle:
                                'Take a clear photo of your food for AI analysis.',
                            onConfirm: (path) => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CalorieScanScreen(initialImagePath: path),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    FeatureHubTile(
                      title: 'Physique Scanner',
                      subtitle: 'AI body analysis from photos',
                      icon: Icons.accessibility_new,
                      accentColor: AppColors.ringStand,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhotoCheckScreen(
                            title: 'Check the photo',
                            subtitle:
                                'Add photos from different angles for accuracy.',
                            onConfirm: (path) => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PhysiqueScanScreen(initialImagePath: path),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }
}
