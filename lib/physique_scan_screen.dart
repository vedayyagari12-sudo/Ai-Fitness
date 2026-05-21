import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String physiqueBaseUrl = 'https://fitness-app-xayv.onrender.com';

class PhysiqueScanScreen extends StatefulWidget {
  const PhysiqueScanScreen({super.key});

  @override
  State<PhysiqueScanScreen> createState() => _PhysiqueScanScreenState();
}

class _PhysiqueScanScreenState extends State<PhysiqueScanScreen> {
  final ImagePicker picker = ImagePicker();
  Map<String, dynamic>? result;
  bool isLoading = false;
  String message = '';

  Future<void> scanPhysique(ImageSource source) async {
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (image == null) return;

    setState(() {
      isLoading = true;
      message = 'Analyzing your physique...';
      result = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken ?? '';
      final imageBytes = await image.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$physiqueBaseUrl/physique/scan'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'physique.jpg',
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

  Widget scoreBar(String label, int score, int maxScore) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text('$score/$maxScore',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: score / maxScore,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Physique Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => scanPhysique(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => scanPhysique(ImageSource.gallery),
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
                  Text('Analyzing your physique...'),
                ],
              ),
            if (message.isNotEmpty) Text(message),
            if (result != null) ...[
              // Overall Score
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${result!['overall_score']}/100',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Overall Physique Score'),
                      const SizedBox(height: 12),
                      infoRow('Body Fat', result!['body_fat_estimate'] ?? 'N/A'),
                      infoRow('Body Type', result!['body_type'] ?? 'N/A'),
                      infoRow('Symmetry', '${result!['symmetry_score']}/10'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Muscle Groups
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Muscle Groups',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...['chest', 'back', 'shoulders', 'arms', 'legs', 'core']
                          .map((muscle) {
                        final data = result!['muscle_groups']?[muscle];
                        if (data == null) return const SizedBox();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            scoreBar(muscle.toUpperCase(),
                                data['score'] ?? 0, 10),
                            Text(
                              data['feedback'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Posture
              if (result!['posture'] != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Posture Analysis',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        infoRow('Overall',
                            result!['posture']['overall'] ?? 'N/A'),
                        infoRow('Head Position',
                            result!['posture']['head_position'] ?? 'N/A'),
                        infoRow('Shoulders',
                            result!['posture']['shoulder_alignment'] ?? 'N/A'),
                        infoRow('Hips',
                            result!['posture']['hip_alignment'] ?? 'N/A'),
                        const SizedBox(height: 8),
                        Text(result!['posture']['feedback'] ?? ''),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Strengths
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Strengths ✅',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(result!['strengths'] as List? ?? [])
                          .map((s) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text('• $s'),
                              )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Weaknesses
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Needs Work ⚠️',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(result!['weaknesses'] as List? ?? [])
                          .map((s) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text('• $s'),
                              )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Recommendations
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommendations 💪',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(result!['recommendations'] as List? ?? [])
                          .map((s) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text('• $s'),
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
}