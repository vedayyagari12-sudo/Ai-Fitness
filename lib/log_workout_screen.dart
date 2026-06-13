import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme/app_widgets.dart';

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final exerciseController = TextEditingController();
  final setsController = TextEditingController();
  final repsController = TextEditingController();
  final weightController = TextEditingController();
  bool isSaving = false;
  String message = '';

  void saveWorkout() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    final workout = {
      "exercise": exerciseController.text,
      "sets": int.tryParse(setsController.text),
      "reps": int.tryParse(repsController.text),
      "weight": double.tryParse(weightController.text),
    };

    final success = await createWorkout(workout);

    setState(() {
      isSaving = false;
      message = success ? '✅ Workout saved!' : '❌ Failed to save';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Workout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: exerciseController,
                decoration: const InputDecoration(labelText: 'Exercise'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: setsController,
                decoration: const InputDecoration(labelText: 'Sets'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repsController,
                decoration: const InputDecoration(labelText: 'Reps'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Weight (lbs)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSaving ? null : saveWorkout,
                child: Text(isSaving ? 'Saving...' : 'Save Workout'),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}