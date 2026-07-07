import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../api_service.dart';
import '../../services/app_state_service.dart';
import '../../theme/app_theme.dart';

/// Single-question first launch: pick a goal, get to the app.
/// Everything else is optional and editable later in Profile.
class GoalPickerScreen extends StatefulWidget {
  const GoalPickerScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<GoalPickerScreen> createState() => _GoalPickerScreenState();
}

class _GoalPickerScreenState extends State<GoalPickerScreen> {
  String? _saving;

  static const _goals = [
    ('BUILD MUSCLE', 'bulk', kLime, Icons.fitness_center_rounded),
    ('LOSE FAT', 'cut', kPink, Icons.local_fire_department_rounded),
    ('STAY FIT', 'maintain', kCyan, Icons.favorite_rounded),
    ('PERFORM', 'athletic', kGold, Icons.bolt_rounded),
  ];

  Future<void> _pick(String value) async {
    if (_saving != null) return;
    setState(() => _saving = value);
    await upsertUserProfile({'goal': value});
    await AppStateService.markOnboardingComplete();
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('WELCOME TO FITAI', style: kLabelSmall),
              const SizedBox(height: 10),
              const Text(
                "What's your main goal?",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This tunes your AI sessions and nutrition targets. '
                'You can change it anytime.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 28),
              for (var i = 0; i < _goals.length; i++) ...[
                _goalButton(_goals[i])
                    .animate()
                    .fadeIn(duration: 250.ms, delay: (i * 80).ms)
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      duration: 250.ms,
                      delay: (i * 80).ms,
                    ),
                const SizedBox(height: 12),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalButton((String, String, Color, IconData) goal) {
    final (label, value, color, icon) = goal;
    final saving = _saving == value;
    return GestureDetector(
      onTap: () => _pick(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: saving ? color.withValues(alpha: 0.15) : kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: saving ? color : kBorder,
            width: saving ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: kTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            if (saving)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
