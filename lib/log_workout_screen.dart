import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'services/nav_service.dart'
    show triggerTodayRefresh, triggerHistoryRefresh;
import 'services/today_cache.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'utils/snackbar.dart';
import 'widgets/exercise_picker.dart';

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final _setsCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  String? _exercise; // always a catalog/history value — no free text

  // 'idle' | 'saving' | 'success' | 'error'
  String _saveState = 'idle';

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExercise() async {
    final picked = await showExercisePicker(context);
    if (picked != null && mounted) setState(() => _exercise = picked);
  }

  void _clearForm() {
    _setsCtrl.clear();
    _repsCtrl.clear();
    _weightCtrl.clear();
    setState(() => _exercise = null);
  }

  Future<void> _saveWorkout() async {
    if (_exercise == null) {
      AppSnackbar.info(context, 'Choose an exercise first');
      return;
    }
    setState(() => _saveState = 'saving');

    final workout = {
      'exercise': _exercise,
      'sets': int.tryParse(_setsCtrl.text),
      'reps': int.tryParse(_repsCtrl.text),
      'weight': double.tryParse(_weightCtrl.text),
    };

    final success = await createWorkout(workout);

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      TodayCache.markTrainedToday();
      triggerTodayRefresh();
      triggerHistoryRefresh();
      setState(() => _saveState = 'success');
      AppSnackbar.success(context, 'Workout logged');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _clearForm();
          setState(() => _saveState = 'idle');
        }
      });
    } else {
      setState(() => _saveState = 'error');
      AppSnackbar.error(context, 'Failed to save workout. Tap to retry.');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _saveState = 'idle');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Log Workout')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + navBarClearance(context)),
        child: AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('EXERCISE', style: kLabelSmall),
              const SizedBox(height: 8),
              // Selection-only field — opens the exercise picker.
              InkWell(
                onTap: _pickExercise,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fitness_center_outlined,
                        size: 18,
                        color: _exercise == null ? AppColors.textMuted : kCyan,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _exercise ?? 'Choose exercise',
                          style: TextStyle(
                            color: _exercise == null
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: _exercise == null
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _setsCtrl,
                      decoration: const InputDecoration(labelText: 'Sets'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _repsCtrl,
                      decoration: const InputDecoration(labelText: 'Reps'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Weight (lbs)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _saveState == 'idle' ? _saveWorkout : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 56,
                  decoration: BoxDecoration(
                    color: switch (_saveState) {
                      'success' => AppColors.success,
                      'error' => AppColors.error,
                      _ => kLime,
                    },
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: switch (_saveState) {
                      'saving' => const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      ),
                      'success' => const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 28,
                      ),
                      'error' => const Text(
                        'Failed — tap to retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      _ => const Text(
                        'LOG WORKOUT',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
