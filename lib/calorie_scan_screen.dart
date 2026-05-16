import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'https://fitness-app-xayv.onrender.com';

class CalorieScanScreen extends StatefulWidget {
  const CalorieScanScreen({super.key});

  @override
  State<CalorieScanScreen> createState() => _CalorieScanScreenState();
}

class _CalorieScanScreenState extends State<CalorieScanScreen> {
  final ImagePicker picker = ImagePicker();
  Map<String, dynamic>? result;
  bool isLoading = false;
  String message = '';

  Future<void> scanFood(ImageSource source) async {
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (image == null) return;

    setState(() {
      isLoading = true;
      result = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken ?? '';
      final imageBytes = await image.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/calories/scan'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'food.jpg',
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        setState(() {
          result = jsonDecode(responseBody);
          message = '';
        });
      } else {
        setState(() {
          message = '❌ Could not analyze image. Try again.';
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
      appBar: AppBar(title: const Text('Calorie Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : () => scanFood(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : () => scanFood(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Analyzing your food...'),
                ],
              ),
            if (message.isNotEmpty) Text(message),
            if (result != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result!['food_name'] ?? 'Unknown food',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Serving: ${result!['serving_size'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.grey)),
                      const Divider(height: 24),
                      nutritionRow('Calories', '${result!['calories']} kcal'),
                      nutritionRow('Protein', '${result!['protein_g']}g'),
                      nutritionRow('Carbs', '${result!['carbs_g']}g'),
                      nutritionRow('Fat', '${result!['fat_g']}g'),
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

  Widget nutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
