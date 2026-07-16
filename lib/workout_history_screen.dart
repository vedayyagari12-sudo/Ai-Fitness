import 'package:flutter/material.dart';

import 'api_service.dart';
import 'services/nav_service.dart' show historyTick;
import 'theme/app_theme.dart';
import 'utils/snackbar.dart';
import 'widgets/exercise_picker.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  List<dynamic> workouts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // TRAIN's sub-tabs live in an IndexedStack, so this screen stays mounted
    // while LOG / the AI session write workouts — reload when they tick.
    historyTick.addListener(loadWorkouts);
    loadWorkouts();
  }

  @override
  void dispose() {
    historyTick.removeListener(loadWorkouts);
    super.dispose();
  }

  Future<void> loadWorkouts() async {
    if (!mounted) return;
    final data = await getWorkouts();
    if (!mounted) return;
    setState(() {
      workouts = data;
      isLoading = false;
    });
  }

  /// Group workouts by calendar day, newest day first.
  List<(String, List<dynamic>)> get _grouped {
    final map = <String, List<dynamic>>{};
    for (final w in workouts) {
      final raw = (w['created_at'] as String?) ?? '';
      final key = raw.length >= 10 ? raw.substring(0, 10) : 'Earlier';
      map.putIfAbsent(key, () => []).add(w);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) (_dateLabel(k), map[k]!)];
  }

  String _dateLabel(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso.toUpperCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'TODAY';
    if (day == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[d.month - 1]} ${d.day}${d.year != now.year ? ' ${d.year}' : ''}';
  }

  Future<bool> _confirmDelete(dynamic w) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delete "${w['exercise']}"?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This removes the workout from your history permanently.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return false;

    final id = (w['id'] as num?)?.toInt();
    if (id == null) return false;
    final ok = await deleteWorkout(id);
    if (!mounted) return false;
    if (ok) {
      AppSnackbar.success(context, 'Workout deleted');
      return true;
    }
    AppSnackbar.error(context, 'Could not delete — try again');
    return false;
  }

  Future<void> _openEditSheet(dynamic w) async {
    var exercise = '${w['exercise'] ?? ''}';
    final setsCtrl = TextEditingController(text: '${w['sets'] ?? ''}');
    final repsCtrl = TextEditingController(text: '${w['reps'] ?? ''}');
    final weightCtrl = TextEditingController(text: '${w['weight'] ?? ''}');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('EDIT WORKOUT', style: kLabelSmall),
              const SizedBox(height: 16),
              // Selection-only exercise field — opens the picker.
              InkWell(
                onTap: () async {
                  final picked = await showExercisePicker(ctx);
                  if (picked != null) {
                    setSheetState(() => exercise = picked);
                  }
                },
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
                      Expanded(
                        child: Text(
                          exercise,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: setsCtrl,
                      decoration: const InputDecoration(labelText: 'Sets'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: repsCtrl,
                      decoration: const InputDecoration(labelText: 'Reps'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: weightCtrl,
                      decoration: const InputDecoration(labelText: 'Weight'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;
    if (exercise.trim().isEmpty) {
      // Legacy rows can carry an empty exercise name — don't persist it.
      AppSnackbar.info(context, 'Choose an exercise before saving');
      return;
    }
    final id = (w['id'] as num?)?.toInt();
    if (id == null) return;
    final ok = await updateWorkout(id, {
      'exercise': exercise.trim(),
      'sets': int.tryParse(setsCtrl.text),
      'reps': int.tryParse(repsCtrl.text),
      'weight': double.tryParse(weightCtrl.text),
    });
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Workout updated');
      loadWorkouts();
    } else {
      AppSnackbar.error(context, 'Could not update — try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Workout History')),
      body: RefreshIndicator(
        onRefresh: loadWorkouts,
        color: kLime,
        backgroundColor: AppColors.surface,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : workouts.isEmpty
            ? _emptyState()
            : _historyList(),
      ),
    );
  }

  Widget _historyList() {
    final groups = _grouped;
    final rows = <Widget>[];
    for (final (label, items) in groups) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(label, style: kLabelSmall),
        ),
      );
      for (var i = 0; i < items.length; i++) {
        rows.add(_dismissibleRow(items[i]));
        if (i != items.length - 1) {
          rows.add(Divider(height: 1, color: AppColors.divider));
        }
      }
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, widget.embedded ? 0 : 12, 20, 120),
      children: rows,
    );
  }

  Widget _dismissibleRow(dynamic w) {
    return Dismissible(
      key: ValueKey('workout_${w['id']}'),
      background: Container(
        // Swipe right → edit
        color: AppColors.surfaceElevated,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.edit_outlined, color: AppColors.accentCyan),
      ),
      secondaryBackground: Container(
        // Swipe left → delete
        color: AppColors.danger.withValues(alpha: 0.85),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _openEditSheet(w);
          return false;
        }
        return _confirmDelete(w);
      },
      onDismissed: (_) {
        setState(() => workouts.removeWhere((x) => x['id'] == w['id']));
      },
      child: _workoutRow(w),
    );
  }

  Widget _workoutRow(dynamic w) {
    final exercise = (w['exercise'] as String?) ?? '';
    final sets = w['sets'];
    final reps = w['reps'];
    final weight = w['weight'];
    final vol = w['volume'];

    final detail = <String>[];
    if (sets != null && reps != null) detail.add('$sets × $reps');
    if (weight != null) detail.add('@ $weight lbs');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail.join('   '),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (vol != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (vol as num).toStringAsFixed(0),
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'VOLUME',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(
          Icons.fitness_center,
          size: 56,
          color: AppColors.textMuted.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No workouts logged yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Log your first set in the LOG tab →',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
