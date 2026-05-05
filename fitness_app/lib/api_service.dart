import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'https://fitness-app-xayv.onrender.com';

Future<bool> testConnection() async {
  try {
    final response = await http.get(Uri.parse('$baseUrl/test-db'));
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

Future<List<dynamic>> getWorkouts(int userId) async {
  final response = await http.get(
    Uri.parse('$baseUrl/workouts/user/$userId'),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }
  return [];
}

Future<bool> createWorkout(Map<String, dynamic> workout) async {
  final response = await http.post(
    Uri.parse('$baseUrl/workouts'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(workout),
  );
  return response.statusCode == 200;
}

Future<Map<String, dynamic>?> getExerciseStats(int userId, String exercise) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/exercises/$exercise/stats'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  } catch (e) {
    return null;
  }
}