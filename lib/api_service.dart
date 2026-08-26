import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import 'services/error_reporter.dart';

const String baseUrl = 'https://fitai-api-242478218388.us-east1.run.app';

Map<String, String> getHeaders() {
  final session = Supabase.instance.client.auth.currentSession;
  final token = session?.accessToken ?? '';
  return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
}

String? getCurrentUserId() {
  return Supabase.instance.client.auth.currentUser?.id;
}

/// Fire-and-forget request to wake a sleeping backend.
///
/// The API host spins down when idle, so the first real request after a quiet
/// period pays the full cold start. Calling this at launch moves that wait
/// under the login/onboarding screens, where the user is busy anyway. Failure
/// is not interesting — the real request will report its own.
Future<void> warmUpBackend() async {
  try {
    // Root, not /test-db: waking the host needs no database round trip, and
    // /test-db now returns 503 when Postgres is unreachable — a warm-up has
    // no opinion about that.
    await http.get(Uri.parse('$baseUrl/')).timeout(const Duration(seconds: 60));
  } catch (_) {
    // Deliberately silent: this is opportunistic, not a user-visible action.
  }
}

Future<bool> testConnection() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/test-db'),
      headers: getHeaders(),
    );
    return response.statusCode == 200;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'testConnection');
    return false;
  }
}

Future<List<dynamic>> getWorkouts() async {
  final userId = getCurrentUserId();
  if (userId == null) return [];
  final response = await http.get(
    Uri.parse('$baseUrl/workouts/user/$userId'),
    headers: getHeaders(),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }
  return [];
}

Future<bool> createWorkout(Map<String, dynamic> workout) async {
  final response = await http.post(
    Uri.parse('$baseUrl/workouts'),
    headers: getHeaders(),
    body: jsonEncode(workout),
  );
  return response.statusCode == 200;
}

Future<bool> saveWorkoutBatch(List<Map<String, dynamic>> exercises) async {
  final response = await http.post(
    Uri.parse('$baseUrl/workouts/batch'),
    headers: getHeaders(),
    body: jsonEncode({'exercises': exercises}),
  );
  return response.statusCode == 200;
}

Future<Map<String, dynamic>?> getDashboard() async {
  final userId = getCurrentUserId();
  if (userId == null) return null;
  try {
    // Same UTC offset the streak endpoint already takes, so "today" means
    // the user's day rather than the server's.
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/$userId?tz=$tz'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getDashboard');
    return null;
  }
}

Future<List<String>> getUserExercises() async {
  final userId = getCurrentUserId();
  if (userId == null) return [];
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/exercises'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['exercises'] as List).cast<String>();
    }
    return [];
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getUserExercises');
    return [];
  }
}

Future<Map<String, dynamic>?> getExerciseStats(String exercise) async {
  final userId = getCurrentUserId();
  if (userId == null) return null;
  try {
    final encoded = Uri.encodeComponent(exercise);
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/exercises/$encoded/stats'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getExerciseStats');
    return null;
  }
}

Future<Map<String, dynamic>?> getStreak() async {
  final userId = getCurrentUserId();
  if (userId == null) return null;
  try {
    // Pass the device's UTC offset so "today" means the user's local day.
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    final response = await http.get(
      Uri.parse('$baseUrl/streak/$userId?tz=$tz'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getStreak');
    return null;
  }
}

Future<Map<String, dynamic>?> logBodyweight(double weightKg) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/bodyweight/log'),
      headers: getHeaders(),
      body: jsonEncode({'weight_kg': weightKg}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    // Surface the server's reason — a blocked same-day update reports a
    // specific, fixable cause that "Server error (500)" would hide.
    try {
      final detail =
          (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
      if (detail is String && detail.isNotEmpty) return {'error': detail};
    } catch (_) {}
    return {'error': 'Server error (${response.statusCode})'};
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'logBodyweight');
    return {'error': 'Network error'};
  }
}

Future<Map<String, dynamic>?> getTodayBodyweight() async {
  final userId = getCurrentUserId();
  if (userId == null) return null;
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/bodyweight/today/$userId'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getTodayBodyweight');
    return null;
  }
}

/// Weekly training volume/session totals, newest week first
/// (backend GET /users/{id}/summary/weekly).
Future<List<Map<String, dynamic>>> getWeeklySummary({int weeks = 8}) async {
  final userId = getCurrentUserId();
  if (userId == null) return [];
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/summary/weekly?weeks=$weeks'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    return [];
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getWeeklySummary');
    return [];
  }
}

Future<Map<String, dynamic>?> getMuscleBalance() async {
  final userId = getCurrentUserId();
  if (userId == null) return null;
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/muscle-balance/$userId'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getMuscleBalance');
    return null;
  }
}

Future<Map<String, dynamic>?> scanFoodText(String description) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/calories/scan/text'),
      headers: getHeaders(),
      body: jsonEncode({'description': description}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'scanFoodText');
    return null;
  }
}

Future<bool> deleteWorkout(int workoutId) async {
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl/workouts/$workoutId'),
      headers: getHeaders(),
    );
    return response.statusCode == 200;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'deleteWorkout');
    return false;
  }
}

Future<bool> updateWorkout(int workoutId, Map<String, dynamic> fields) async {
  try {
    final response = await http.put(
      Uri.parse('$baseUrl/workouts/$workoutId'),
      headers: getHeaders(),
      body: jsonEncode(fields),
    );
    return response.statusCode == 200;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'updateWorkout');
    return false;
  }
}

/// Persist an already-analyzed physique scan (retry path when the insert
/// during /physique/scan failed) — no AI call involved.
Future<bool> savePhysiqueScan(Map<String, dynamic> scanData) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/physique/scans'),
      headers: getHeaders(),
      body: jsonEncode(scanData),
    );
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['saved'] == true;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'savePhysiqueScan');
    return false;
  }
}

Future<bool> deletePhysiqueScan(String scanId) async {
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl/physique/scans/$scanId'),
      headers: getHeaders(),
    );
    return response.statusCode == 200;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'deletePhysiqueScan');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getBodyweightHistory() async {
  final userId = getCurrentUserId();
  if (userId == null) return [];
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/bodyweight/history/$userId'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['entries'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getBodyweightHistory');
    return [];
  }
}

/// Returns null on failure; otherwise the backend's result including
/// `auth_user_deleted` (false when the server lacks the service-role key,
/// meaning the login credential still exists).
Future<Map<String, dynamic>?> deleteAccount() async {
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl/account'),
      headers: getHeaders(),
    );
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'deleteAccount');
    return null;
  }
}

/// All physique scans for the signed-in user, oldest first.
/// Reads Supabase directly (RLS scopes rows to the user's JWT).
Future<List<Map<String, dynamic>>> getPhysiqueScans() async {
  final userId = getCurrentUserId();
  if (userId == null) return [];
  try {
    final rows = await Supabase.instance.client
        .from('physique_scans')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getPhysiqueScans');
    return [];
  }
}

/// All calorie/meal logs for the signed-in user, newest first.
/// Reads Supabase directly (RLS scopes rows to the user's JWT) — used by the
/// TODAY "See all" sheet, which needs more history than the dashboard's
/// 3-item preview.
Future<List<Map<String, dynamic>>> getCalorieLogs() async {
  final userId = getCurrentUserId();
  if (userId == null) return [];
  try {
    final rows = await Supabase.instance.client
        .from('calorie_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getCalorieLogs');
    return [];
  }
}

Future<Map<String, dynamic>?> getUserProfile() async {
  final userId = getCurrentUserId();
  if (userId == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row;
  } catch (e, s) {
    ErrorReporter.report(e, stack: s, context: 'getUserProfile');
    return null;
  }
}

int parseReps(dynamic reps) {
  if (reps == null) return 0;
  if (reps is int) return reps;
  if (reps is double) return reps.round();
  final text = reps.toString();
  final range = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(text);
  if (range != null) {
    final low = int.parse(range.group(1)!);
    final high = int.parse(range.group(2)!);
    return ((low + high) / 2).round();
  }
  final single = RegExp(r'\d+').firstMatch(text);
  return single != null ? int.parse(single.group(0)!) : 0;
}

String mapOnboardingGoalToProfile(String? goal) {
  switch (goal) {
    case 'Build Muscle':
      return 'bulk';
    case 'Lose Weight':
      return 'cut';
    case 'General Fitness':
      return 'maintain';
    case 'Athletic Performance':
    case 'Improve Endurance':
      return 'athletic';
    default:
      return 'maintain';
  }
}

Future<void> upsertUserProfile(Map<String, dynamic> profile) async {
  final userId = getCurrentUserId();
  if (userId == null) return;
  await Supabase.instance.client.from('user_profiles').upsert({
    'id': userId,
    ...profile,
    'updated_at': DateTime.now().toIso8601String(),
  });
}

Future<void> syncOnboardingToProfile(dynamic data) async {
  final userId = getCurrentUserId();
  if (userId == null) return;
  await Supabase.instance.client.from('user_profiles').upsert({
    'id': userId,
    'goal': mapOnboardingGoalToProfile(data.goal as String?),
    'gender': data.gender,
    'age': data.age,
    'height_cm': data.heightCm,
    'weight_kg': data.weightKg,
    'workout_frequency': data.workoutFrequency,
    'equipment': data.equipment,
    'fitness_level': data.fitnessLevel,
    'updated_at': DateTime.now().toIso8601String(),
  });

  // The weight given during onboarding is a real weigh-in, so record it as
  // one. Without this the profile knows your weight but bodyweight_logs is
  // empty, so the weight trend has a single point at best and never draws —
  // it just keeps asking for "two entries".
  final weightKg = data.weightKg as double?;
  if (weightKg != null && weightKg > 0) {
    await logBodyweight(weightKg);
  }
}
