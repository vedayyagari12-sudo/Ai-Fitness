import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'screens/today_screen.dart' show triggerTodayRefresh;
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'utils/fuzzy_search.dart';
import 'utils/snackbar.dart';

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final _exerciseCtrl = TextEditingController();
  final _setsCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _exerciseFocus = FocusNode();
  final _overlayLink = LayerLink();

  List<String> _allExercises = [];
  List<String> _suggestions = [];
  OverlayEntry? _overlay;

  // 'idle' | 'saving' | 'success' | 'error'
  String _saveState = 'idle';

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _exerciseCtrl.addListener(_onExerciseChanged);
    _exerciseFocus.addListener(() {
      if (!_exerciseFocus.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _exerciseCtrl.dispose();
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _exerciseFocus.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final list = await getUserExercises();
    if (mounted) setState(() => _allExercises = list);
  }

  void _onExerciseChanged() {
    final query = _exerciseCtrl.text.trim();
    final matches = topFuzzyMatches(query, _allExercises);
    setState(() => _suggestions = matches);
    if (matches.isNotEmpty && _exerciseFocus.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: MediaQuery.of(context).size.width - 64,
        child: CompositedTransformFollower(
          link: _overlayLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) => InkWell(
                  onTap: () {
                    _exerciseCtrl.text = _suggestions[i];
                    _exerciseCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _suggestions[i].length),
                    );
                    _removeOverlay();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      _suggestions[i],
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _clearForm() {
    _exerciseCtrl.clear();
    _setsCtrl.clear();
    _repsCtrl.clear();
    _weightCtrl.clear();
  }

  Future<void> _saveWorkout() async {
    final exerciseName = _exerciseCtrl.text.trim();
    if (exerciseName.isEmpty) return;
    setState(() => _saveState = 'saving');

    final workout = {
      'exercise': titleCaseExercise(exerciseName),
      'sets': int.tryParse(_setsCtrl.text),
      'reps': int.tryParse(_repsCtrl.text),
      'weight': double.tryParse(_weightCtrl.text),
    };

    final success = await createWorkout(workout);

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      triggerTodayRefresh();
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
        padding: const EdgeInsets.all(16),
        child: AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Exercise field with autocomplete overlay
              CompositedTransformTarget(
                link: _overlayLink,
                child: TextField(
                  controller: _exerciseCtrl,
                  focusNode: _exerciseFocus,
                  decoration: const InputDecoration(
                    labelText: 'Exercise',
                    hintText: 'e.g. Bench Press',
                    suffixIcon: Icon(Icons.fitness_center_outlined, size: 18),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _setsCtrl,
                decoration: const InputDecoration(labelText: 'Sets'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repsCtrl,
                decoration: const InputDecoration(labelText: 'Reps'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightCtrl,
                decoration: const InputDecoration(labelText: 'Weight (lbs)'),
                keyboardType: TextInputType.number,
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
