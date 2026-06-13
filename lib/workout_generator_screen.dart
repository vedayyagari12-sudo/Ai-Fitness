import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';

const String generatorBaseUrl = 'https://fitness-app-xayv.onrender.com';

class WorkoutGeneratorScreen extends StatefulWidget {
  const WorkoutGeneratorScreen({
    super.key,
    this.initialDuration = 60,
    this.initialIntensity = 'Medium',
  });

  final int initialDuration;
  final String initialIntensity;

  @override
  State<WorkoutGeneratorScreen> createState() => _WorkoutGeneratorScreenState();
}

class _GeneratedExercise {
  _GeneratedExercise({
    required this.exercise,
    required this.sets,
    required this.repsRaw,
    required this.reps,
    this.weight,
    this.muscleGroup,
    this.instructions,
  });

  final String exercise;
  final int sets;
  final dynamic repsRaw;
  final int reps;
  double? weight;
  final String? muscleGroup;
  final String? instructions;
  bool checked = false;
}

class _WorkoutGeneratorScreenState extends State<WorkoutGeneratorScreen> {
  Map<String, dynamic>? workout;
  bool isLoading = false;
  bool isSaving = false;
  String message = '';
  List<_GeneratedExercise> mainExercises = [];

  String selectedGoal = 'Build Muscle';
  String selectedEquipment = 'Full Gym';
  String selectedFocus = 'Full Body';
  late int selectedDuration;
  late String selectedIntensity;

  @override
  void initState() {
    super.initState();
    selectedDuration = widget.initialDuration;
    selectedIntensity = widget.initialIntensity;
  }

  final goals = [
    'Build Muscle',
    'Lose Weight',
    'Improve Endurance',
    'General Fitness',
    'Athletic Performance',
  ];
  final equipment = [
    'Full Gym',
    'Home No Equipment',
    'Dumbbells Only',
    'Resistance Bands',
    'Barbell Only',
  ];
  final focusAreas = [
    'Full Body',
    'Upper Body',
    'Lower Body',
    'Push',
    'Pull',
    'Legs',
    'Core',
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
  ];
  final durations = [30, 45, 60, 75, 90];

  void _parseMainExercises(Map<String, dynamic> data) {
    final list = data['main_workout'] as List? ?? [];
    mainExercises = list.map((e) {
      final weight = e['weight'];
      return _GeneratedExercise(
        exercise: e['exercise'] ?? '',
        sets: (e['sets'] as num?)?.toInt() ?? 0,
        repsRaw: e['reps'],
        reps: parseReps(e['reps']),
        weight: weight is num ? weight.toDouble() : null,
        muscleGroup: e['muscle_group'] as String?,
        instructions: e['instructions'] as String?,
      );
    }).toList();
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final e in mainExercises) {
        e.checked = value;
      }
    });
  }

  Future<void> generateWorkout() async {
    setState(() {
      isLoading = true;
      message = 'Generating your workout...';
      workout = null;
      mainExercises = [];
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken ?? '';

      final response = await http.post(
        Uri.parse('$generatorBaseUrl/workouts/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'goal': selectedGoal,
          'equipment': selectedEquipment,
          'focus': selectedFocus,
          'duration': selectedDuration,
          'intensity': selectedIntensity,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          workout = data;
          _parseMainExercises(data);
          message = '';
        });
      } else {
        setState(() {
          message = 'Could not generate workout. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        message = 'Error: ${e.toString()}';
      });
    }

    setState(() => isLoading = false);
  }

  Future<void> saveSession() async {
    final checked = mainExercises.where((e) => e.checked).toList();
    if (checked.isEmpty) return;

    setState(() {
      isSaving = true;
      message = '';
    });

    final payload = checked
        .map((e) => {
              'exercise': e.exercise,
              'sets': e.sets,
              'reps': e.reps,
              if (e.weight != null) 'weight': e.weight,
            })
        .toList();

    final ok = await saveWorkoutBatch(payload);
    if (!mounted) return;
    setState(() {
      isSaving = false;
      message = ok
          ? 'Session saved (${checked.length} exercises)'
          : 'Failed to save session';
    });
  }

  @override
  Widget build(BuildContext context) {
    final anyChecked = mainExercises.any((e) => e.checked);
    final allChecked =
        mainExercises.isNotEmpty && mainExercises.every((e) => e.checked);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Workout Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Goal', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              initialValue: selectedGoal,
              items: goals
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => selectedGoal = v!),
            ),
            const SizedBox(height: 12),
            const Text('Equipment', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              initialValue: selectedEquipment,
              items: equipment
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => selectedEquipment = v!),
            ),
            const SizedBox(height: 12),
            const Text('Focus Area', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              initialValue: selectedFocus,
              items: focusAreas
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => selectedFocus = v!),
            ),
            const SizedBox(height: 12),
            const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<int>(
              initialValue: selectedDuration,
              items: durations
                  .map((d) =>
                      DropdownMenuItem(value: d, child: Text('$d minutes')))
                  .toList(),
              onChanged: (v) => setState(() => selectedDuration = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : generateWorkout,
                child: Text(isLoading ? 'Generating...' : 'Generate Workout'),
              ),
            ),
            const SizedBox(height: 16),
            if (message.isNotEmpty) Text(message),
            if (workout != null) ...[
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout!['workout_name'] ?? 'Your Workout',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${workout!['duration_minutes']} min • ${workout!['focus']} • ${workout!['goal']}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard('Warmup', workout!['warmup'] as List? ?? []),
              const SizedBox(height: 12),
              _checklistCard(allChecked, anyChecked),
              const SizedBox(height: 12),
              _sectionCard('Cooldown', workout!['cooldown'] as List? ?? []),
              const SizedBox(height: 12),
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tips',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(workout!['tips'] as List? ?? []).map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('• $t'),
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _checklistCard(bool allChecked, bool anyChecked) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Main Workout',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: mainExercises.isEmpty
                    ? null
                    : () => _toggleAll(!allChecked),
                child: Text(allChecked ? 'Uncheck All' : 'Complete All'),
              ),
            ],
          ),
          ...mainExercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Column(
              children: [
                CheckboxListTile(
                  value: e.checked,
                  onChanged: (v) =>
                      setState(() => mainExercises[i].checked = v ?? false),
                  title: Text(e.exercise,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${e.sets} x ${e.repsRaw} • ${e.muscleGroup ?? ''}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  activeColor: AppColors.accent,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (e.weight == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Weight (lbs) — optional',
                        isDense: true,
                      ),
                      onChanged: (v) {
                        e.weight = double.tryParse(v);
                      },
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
          ContinueButton(
            label: isSaving ? 'Saving...' : 'Save Session',
            enabled: anyChecked && !isSaving,
            onPressed: anyChecked && !isSaving ? saveSession : null,
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List exercises) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...exercises.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['exercise'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(e['duration'] ?? '',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    Text(e['instructions'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
