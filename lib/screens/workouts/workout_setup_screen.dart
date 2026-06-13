import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../workout_generator_screen.dart';

class WorkoutSetupScreen extends StatefulWidget {
  const WorkoutSetupScreen({super.key});

  @override
  State<WorkoutSetupScreen> createState() => _WorkoutSetupScreenState();
}

class _WorkoutSetupScreenState extends State<WorkoutSetupScreen> {
  String intensity = 'Medium';
  int duration = 30;
  late final TextEditingController _customDurationCtrl;

  static const intensities = {
    'High': 'Training to failure, breathing heavily',
    'Medium': 'Breaking a sweat, many reps',
    'Low': 'Not breaking a sweat, giving little effort',
  };

  static const durations = [15, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _customDurationCtrl = TextEditingController(text: duration.toString());
  }

  @override
  void dispose() {
    _customDurationCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutGeneratorScreen(
          initialDuration: duration,
          initialIntensity: intensity,
        ),
      ),
    );
  }

  void _updateDuration(int value, {bool updateText = false}) {
    setState(() {
      duration = value;
    });
    if (updateText) {
      _customDurationCtrl.text = value.toString();
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Top ambient glow
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            child: Container(
              height: 360,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Workout Generator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subtitle header
                        Row(
                          children: [
                            const Icon(Icons.fitness_center, color: AppColors.accent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Weight lifting'.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set Intensity',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Select the level of physical exertion for this workout.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Intensity Selection Tiles
                        ...intensities.entries.map((e) {
                          IconData icon;
                          Color tileColor;
                          if (e.key == 'High') {
                            icon = Icons.whatshot_outlined;
                            tileColor = AppColors.ringMove;
                          } else if (e.key == 'Medium') {
                            icon = Icons.bolt_outlined;
                            tileColor = AppColors.accent;
                          } else {
                            icon = Icons.spa_outlined;
                            tileColor = AppColors.ringExercise;
                          }
                          return SelectionTile(
                            label: e.key,
                            subtitle: e.value,
                            icon: icon,
                            selected: intensity == e.key,
                            accentColor: tileColor,
                            onTap: () => setState(() => intensity = e.key),
                          );
                        }),
                        
                        const SizedBox(height: 32),
                        
                        // Duration Heading
                        const Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose how long you plan to train today.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Pill options
                        PillSelector<int>(
                          options: durations,
                          selected: durations.contains(duration) ? duration : null,
                          onSelected: (v) => _updateDuration(v, updateText: true),
                          labelBuilder: (d) => '$d mins',
                        ),
                        const SizedBox(height: 20),
                        
                        // Custom Input box
                        TextField(
                          controller: _customDurationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Custom duration (minutes)',
                            hintText: 'e.g. 45',
                            prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                            suffixText: 'mins',
                            suffixStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null && parsed > 0) {
                              _updateDuration(parsed);
                            }
                          },
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Generate Button
                        ContinueButton(
                          onPressed: _generate,
                          label: 'Generate Workout',
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
