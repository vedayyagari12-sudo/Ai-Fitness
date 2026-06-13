import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';

const String physiqueBaseUrl = 'https://fitness-app-xayv.onrender.com';

class PhysiqueScanScreen extends StatefulWidget {
  const PhysiqueScanScreen({super.key, this.initialImagePath});

  final String? initialImagePath;

  @override
  State<PhysiqueScanScreen> createState() => _PhysiqueScanScreenState();
}

class _PhysiqueScanScreenState extends State<PhysiqueScanScreen> {
  final ImagePicker picker = ImagePicker();
  Map<String, dynamic>? result;
  bool isLoading = false;
  String message = '';
  List<XFile> selectedImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      selectedImages = [XFile(widget.initialImagePath!)];
    }
  }

  Future<void> addPhoto(ImageSource source) async {
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (image == null) return;
    setState(() {
      selectedImages.add(image);
    });
  }

  void removePhoto(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  Future<void> scanPhysique() async {
    if (selectedImages.isEmpty) {
      setState(() => message = '❌ Please add at least one photo');
      return;
    }

    setState(() {
      isLoading = true;
      message = 'Analyzing your physique...';
      result = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken ?? '';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$physiqueBaseUrl/physique/scan'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      for (final image in selectedImages) {
        final imageBytes = await image.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          imageBytes,
          filename: 'physique.jpg',
        ));
      }

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add photos from different angles for the most accurate analysis',
              style: secondaryTextStyle(context),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : () => addPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : () => addPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Show selected photos
            if (selectedImages.isNotEmpty) ...[
              Text('${selectedImages.length} photo(s) selected',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: selectedImages.asMap().entries.map((entry) {
                  return Chip(
                    label: Text('Photo ${entry.key + 1}'),
                    onDeleted: () => removePhoto(entry.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : scanPhysique,
                  child: Text(isLoading ? 'Analyzing...' : '🔍 Analyze Physique'),
                ),
              ),
            ],

            const SizedBox(height: 16),
            if (message.isNotEmpty) Text(message),
            if (result != null) ...[
              // Overall Score
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                    children: [
                      Text(
                        '${result!['overall_score']}/100',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      const Text('Overall Physique Score'),
                      const SizedBox(height: 12),
                      if (result!['body_fat_estimate'] != null)
                        infoRow('Body Fat', result!['body_fat_estimate']),
                      if (result!['body_type'] != null)
                        infoRow('Body Type', result!['body_type']),
                      if (result!['symmetry_score'] != null)
                        infoRow('Symmetry', '${result!['symmetry_score']}/10'),
                      if (result!['visible_angles'] != null)
                        infoRow('Angles Analyzed',
                            (result!['visible_angles'] as List).join(', ')),
                    ],
                  ),
              ),
              const SizedBox(height: 12),

              // Muscle Groups - only show visible ones
              if (result!['muscle_groups'] != null)
                AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Muscle Groups',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Powered by AI',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 12),
                        ...['chest', 'back', 'shoulders', 'arms', 'legs', 'core']
                            .where((muscle) =>
                                result!['muscle_groups'][muscle] != null)
                            .map((muscle) {
                          final data = result!['muscle_groups'][muscle];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              scoreBar(muscle.toUpperCase(),
                                  data['score'] ?? 0, 10),
                              Text(
                                data['feedback'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        }),
                      ],
                    ),
                ),
              const SizedBox(height: 12),

              // Posture
              if (result!['posture'] != null)
                AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Posture Analysis',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (result!['posture']['overall'] != null)
                          infoRow('Overall', result!['posture']['overall']),
                        if (result!['posture']['head_position'] != null)
                          infoRow('Head Position',
                              result!['posture']['head_position']),
                        if (result!['posture']['shoulder_alignment'] != null)
                          infoRow('Shoulders',
                              result!['posture']['shoulder_alignment']),
                        if (result!['posture']['hip_alignment'] != null)
                          infoRow('Hips', result!['posture']['hip_alignment']),
                        const SizedBox(height: 8),
                        if (result!['posture']['feedback'] != null)
                          Text(result!['posture']['feedback']),
                      ],
                    ),
                ),
              const SizedBox(height: 12),

              // Strengths
              if ((result!['strengths'] as List? ?? []).isNotEmpty)
                AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Strengths ✅',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...(result!['strengths'] as List).map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('• $s'),
                            )),
                      ],
                    ),
                ),
              const SizedBox(height: 12),

              // Weaknesses
              if ((result!['weaknesses'] as List? ?? []).isNotEmpty)
                AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Needs Work ⚠️',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...(result!['weaknesses'] as List).map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('• $s'),
                            )),
                      ],
                    ),
                ),
              const SizedBox(height: 12),

              // Recommendations
              if ((result!['recommendations'] as List? ?? []).isNotEmpty)
                AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recommendations 💪',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...(result!['recommendations'] as List)
                            .map((s) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('• $s'),
                                )),
                      ],
                    ),
                ),

              // Note about what couldn't be assessed
              if (result!['note'] != null)
                AppWarningCard(
                  title: '📸 Note',
                  body: result!['note'] ?? '',
                ),
            ],
          ],
        ),
      ),
    );
  }
}
// 