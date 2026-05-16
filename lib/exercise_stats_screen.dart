import 'package:flutter/material.dart';
import 'api_service.dart';

class ExerciseStatsScreen extends StatefulWidget {
  const ExerciseStatsScreen({super.key});

  @override
  State<ExerciseStatsScreen> createState() => _ExerciseStatsScreenState();
}

class _ExerciseStatsScreenState extends State<ExerciseStatsScreen> {
  final exerciseController = TextEditingController();
  Map<String, dynamic>? stats;
  bool isLoading = false;
  String message = '';

  void loadStats() async {
    setState(() {
      isLoading = true;
      message = '';
      stats = null;
    });
    final data = await getExerciseStats(1, exerciseController.text);
    setState(() {
      isLoading = false;
      if (data != null) {
        stats = data;
      } else {
        message = 'No stats found for that exercise';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Stats')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: exerciseController,
              decoration: const InputDecoration(
                labelText: 'Exercise name',
                hintText: 'e.g. dumbell curls',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : loadStats,
              child: Text(isLoading ? 'Loading...' : 'Get Stats'),
            ),
            const SizedBox(height: 24),
            if (message.isNotEmpty) Text(message),
            if (stats != null) ...[
              statRow('Exercise', stats!['exercise']),
              statRow('Last Weight', '${stats!['last_weight']} lbs'),
              statRow('Last Reps', '${stats!['last_reps']}'),
              statRow('Last Sets', '${stats!['last_sets']}'),
              statRow('Max Weight Ever', '${stats!['max_weight']} lbs'),
              statRow('Max Volume Ever', '${stats!['max_volume']}'),
              statRow('Total Sessions', '${stats!['total_sessions']}'),
            ]
          ],
        ),
      ),
    );
  }

  Widget statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}