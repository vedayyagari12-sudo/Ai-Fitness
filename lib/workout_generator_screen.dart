import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String generatorBaseUrl = 'https://fitness-app-xayv.onrender.com';

class WorkoutGeneratorScreen extends StatefulWidget {
  const WorkoutGeneratorScreen({super.key});

  @override
  State<WorkoutGeneratorScreen> createState() => _WorkoutGeneratorScreenState();
}

class _WorkoutGeneratorScreenState extends State<WorkoutGeneratorScreen> {
  Map<String, dynamic>? workout;
  bool isLoading = false;
  String message = '';

  String selectedGoal = 'Build Muscle';
  String selectedEquipment = 'Full Gym';
  String selectedFocus = 'Full Body';
  int selectedDuration = 60;

  final goals = ['Build Muscle', 'Lose Weight', 'Improve Endurance', 'General Fitness', 'Athletic Performance'];
  final equipment = ['Full Gym', 'Home No Equipment', 'Dumbbells Only', 'Resistance Bands', 'Barbell Only'];
  final focusAreas = ['Full Body', 'Upper Body', 'Lower Body', 'Push', 'Pull', 'Legs', 'Core', 'Chest', 'Back', 'Shoulders', 'Arms'];
  final durations = [30, 45, 60, 75, 90];

  Future<void> generateWorkout() async {
    setState(() {
      isLoading = true;
      message = 'Generating your workout...';
      workout = null;
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
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          workout = jsonDecode(response.body);
          message = '';
        });
      } else {
        setState(() {
          message = '❌ Could not generate workout. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        message = '❌ Error: ${e.toString()}';
      });
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Workout Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Goal', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedGoal,
              items: goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => selectedGoal = v!),
            ),
            const SizedBox(height: 12),
            const Text('Equipment', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedEquipment,
              items: equipment.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => selectedEquipment = v!),
            ),
            const SizedBox(height: 12),
            const Text('Focus Area', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedFocus,
              items: focusAreas.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() => selectedFocus = v!),
            ),
            const SizedBox(height: 12),
            const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<int>(
              value: selectedDuration,
              items: durations.map((d) => DropdownMenuItem(value: d, child: Text('$d minutes'))).toList(),
              onChanged: (v) => setState(() => selectedDuration = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : generateWorkout,
                child: Text(isLoading ? 'Generating...' : '⚡ Generate Workout'),
              ),
            ),
            const SizedBox(height: 16),
            if (message.isNotEmpty) Text(message),
            if (workout != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout!['workout_name'] ?? 'Your Workout',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text('${workout!['duration_minutes']} min • ${workout!['focus']} • ${workout!['goal']}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Warmup
              _sectionCard('🔥 Warmup', workout!['warmup'] as List? ?? [], isWarmupCooldown: true),
              const SizedBox(height: 12),

              // Main Workout
              _mainWorkoutCard(workout!['main_workout'] as List? ?? []),
              const SizedBox(height: 12),

              // Cooldown
              _sectionCard('🧊 Cooldown', workout!['cooldown'] as List? ?? [], isWarmupCooldown: true),
              const SizedBox(height: 12),

              // Tips
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(workout!['tips'] as List? ?? []).map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('• $t'),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List exercises, {bool isWarmupCooldown = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...exercises.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['exercise'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(e['duration'] ?? '', style: const TextStyle(color: Colors.grey)),
                  Text(e['instructions'] ?? '', style: const TextStyle(fontSize: 12)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _mainWorkoutCard(List exercises) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💪 Main Workout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...exercises.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e['exercise'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${e['sets']} x ${e['reps']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('Rest: ${e['rest_seconds']}s • ${e['muscle_group']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(e['instructions'] ?? '', style: const TextStyle(fontSize: 12)),
                  const Divider(),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}