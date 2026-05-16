import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

const String baseUrl = 'https://fitness-app-xayv.onrender.com';

Map<String, String> getHeaders() {
  final session = Supabase.instance.client.auth.currentSession;
  final token = session?.accessToken ?? '';
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

Future<bool> testConnection() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/test-db'),
      headers: getHeaders(),
    );
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

Future<List<dynamic>> getWorkouts(int userId) async {
  final session = Supabase.instance.client.auth.currentSession;
  print('Token: ${session?.accessToken}');
  final response = await http.get(
    Uri.parse('$baseUrl/workouts/user/$userId'),
    headers: getHeaders(),
  );
  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
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

Future<Map<String, dynamic>?> getExerciseStats(int userId, String exercise) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/exercises/$exercise/stats'),
      headers: getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  } catch (e) {
    return null;
  }
}