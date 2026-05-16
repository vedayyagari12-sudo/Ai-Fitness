import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  List<dynamic> workouts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadWorkouts();
  }

  void loadWorkouts() async {
    if (!mounted) return;
  final data = await getWorkouts(1);
  if (!mounted) return;
  setState(() {
    workouts = data;
    isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : workouts.isEmpty
              ? const Center(child: Text('No workouts yet!'))
              : ListView.builder(
                  itemCount: workouts.length,
                  itemBuilder: (context, index) {
                    final w = workouts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(w['exercise'] ?? ''),
                        subtitle: Text(
                            'Sets: ${w['sets']} | Reps: ${w['reps']} | Weight: ${w['weight']}lbs'),
                        trailing: Text(
                          'Vol: ${w['volume']?.toStringAsFixed(1) ?? 'N/A'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}