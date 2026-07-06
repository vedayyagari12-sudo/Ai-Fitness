import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'dashboard_screen.dart' show triggerDashboardRefresh;
import 'services/permission_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'utils/snackbar.dart';

const String baseUrl = 'https://fitness-app-xayv.onrender.com';

class CalorieScanScreen extends StatefulWidget {
  const CalorieScanScreen({
    super.key,
    this.initialImagePath,
    this.embedded = false,
  });

  final String? initialImagePath;
  final bool embedded;

  @override
  State<CalorieScanScreen> createState() => _CalorieScanScreenState();
}

class _CalorieScanScreenState extends State<CalorieScanScreen> {
  final ImagePicker picker = ImagePicker();
  final _textCtrl = TextEditingController();
  Map<String, dynamic>? result;
  bool isLoading = false;
  bool _textAnalyzing = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scanFromPath(widget.initialImagePath!);
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanFromPath(String path) async {
    setState(() {
      isLoading = true;
      message = 'Analyzing your food...';
      result = null;
    });
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken ?? '';
      final imageBytes = await XFile(path).readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/calories/scan'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'food.jpg'),
      );
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final scanResult = jsonDecode(responseBody);
        setState(() {
          result = scanResult;
          message = '';
        });
        await _logAndNotify(scanResult, token);
      } else {
        setState(() => message = '❌ Could not analyze image. Try again.');
      }
    } catch (e) {
      setState(() => message = '❌ Error: ${e.toString()}');
    }
    setState(() => isLoading = false);
  }

  Future<void> scanFood(ImageSource source) async {
    if (!mounted) return;
    final ctx = context;
    final granted = source == ImageSource.camera
        ? await PermissionService.requestCamera(ctx)
        : await PermissionService.requestGallery(ctx);
    if (!granted) return;

    XFile? image;
    try {
      image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          source == ImageSource.camera
              ? 'Camera unavailable here — try Gallery.'
              : 'Could not open the picker.',
        );
      }
      return;
    }
    if (image == null) return;

    setState(() {
      isLoading = true;
      message = 'Analyzing your food...';
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
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'food.jpg'),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final scanResult = jsonDecode(responseBody);
        setState(() {
          result = scanResult;
          message = '';
        });
        await _logAndNotify(scanResult, token);
      } else {
        setState(() => message = '❌ Could not analyze image. Try again.');
      }
    } catch (e) {
      setState(() => message = '❌ Error: ${e.toString()}');
    }

    setState(() => isLoading = false);
  }

  Future<void> _scanFromText() async {
    final desc = _textCtrl.text.trim();
    if (desc.isEmpty) return;
    setState(() {
      _textAnalyzing = true;
      message = 'Analyzing your meal...';
      result = null;
    });
    try {
      final scanResult = await scanFoodText(desc);
      if (scanResult != null) {
        setState(() {
          result = scanResult;
          message = '';
        });
        final session = Supabase.instance.client.auth.currentSession;
        await _logAndNotify(scanResult, session?.accessToken ?? '');
      } else {
        setState(() => message = '❌ Could not analyze meal. Try again.');
      }
    } catch (e) {
      setState(() => message = '❌ Error: ${e.toString()}');
    }
    setState(() => _textAnalyzing = false);
  }

  Future<void> _logAndNotify(
    Map<String, dynamic> scanResult,
    String token,
  ) async {
    final logResp = await http.post(
      Uri.parse('$baseUrl/calories/log'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(scanResult),
    );
    if (!mounted) return;
    bool saved = false;
    String? err;
    if (logResp.statusCode == 200) {
      try {
        final body = jsonDecode(logResp.body) as Map<String, dynamic>;
        saved = body['saved'] == true;
        err = body['error'] as String?;
      } catch (_) {}
    } else {
      err = 'Server error (${logResp.statusCode})';
    }
    if (saved) {
      triggerDashboardRefresh();
      AppSnackbar.success(context, 'Saved to food log');
    } else {
      AppSnackbar.error(
        context,
        err != null ? 'Could not save — $err' : 'Could not save to food log',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Calorie Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera / Gallery buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => scanFood(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('CAMERA'),
                    style: _scanBtnStyle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => scanFood(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('GALLERY'),
                    style: _scanBtnStyle,
                  ),
                ),
              ],
            ),

            // ── OR divider ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
            ),

            // Text description input
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Describe your meal',
                hintText:
                    'e.g. "chicken sandwich and fries" or "oatmeal with banana"',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_textAnalyzing || isLoading) ? null : _scanFromText,
              icon: _textAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_textAnalyzing ? 'Analyzing...' : 'Analyze with AI'),
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
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  message,
                  style: TextStyle(
                    color: message.startsWith('❌')
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            if (result != null)
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result!['food_name'] ?? 'Unknown food',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Serving: ${result!['serving_size'] ?? 'N/A'}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Hero calories
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${result!['calories']}',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                            height: 1.0,
                            letterSpacing: -2,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 8),
                          child: Text(
                            'KCAL',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),
                    // Protein / Carbs / Fat
                    Row(
                      children: [
                        _macroStat('PROTEIN', '${result!['protein_g']}g'),
                        _macroStat('CARBS', '${result!['carbs_g']}g'),
                        _macroStat('FAT', '${result!['fat_g']}g'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Powered by AI',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static final ButtonStyle _scanBtnStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.accent,
    side: const BorderSide(color: AppColors.accent),
    padding: const EdgeInsets.symmetric(vertical: 14),
    textStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  Widget _macroStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
