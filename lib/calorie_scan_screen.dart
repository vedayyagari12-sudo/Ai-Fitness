import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_service.dart';
import 'services/nav_service.dart' show triggerTodayRefresh;
import 'services/permission_service.dart';
import 'services/today_cache.dart';
import 'theme/app_theme.dart';
import 'widgets/deco.dart';
import 'utils/snackbar.dart';

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
  Uint8List? _photoBytes;
  bool isLoading = false;
  bool _textAnalyzing = false;
  bool _saving = false;
  bool _savedToLog = false;
  String message = '';
  double _calorieTarget = 2200;

  @override
  void initState() {
    super.initState();
    _loadCalorieTarget();
    if (widget.initialImagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scanFromXFile(XFile(widget.initialImagePath!));
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  /// Use the same calorie target the TODAY dashboard shows — one source of
  /// truth (the backend's TDEE) so the "% of daily goal" numbers agree.
  Future<void> _loadCalorieTarget() async {
    final dash = await getDashboard();
    final target =
        ((dash?['today_stats'] as Map<String, dynamic>?)?['calorie_target']
                as num?)
            ?.toDouble();
    if (target != null && target > 0 && mounted) {
      setState(() => _calorieTarget = target);
    }
  }

  Future<void> _scanFromXFile(XFile image) async {
    setState(() {
      isLoading = true;
      message = 'Analyzing your food...';
      result = null;
      _savedToLog = false;
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
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          result = jsonDecode(responseBody);
          _photoBytes = imageBytes;
          message = '';
        });
      } else {
        setState(() => message = 'Could not analyze image — try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Connection lost — check your internet.');
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> scanFood(ImageSource source) async {
    if (!mounted) return;
    final granted = await (source == ImageSource.camera
        ? PermissionService.requestCamera(context)
        : PermissionService.requestGallery(context));
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
    await _scanFromXFile(image);
  }

  Future<void> _scanFromText() async {
    final desc = _textCtrl.text.trim();
    if (desc.isEmpty) return;
    setState(() {
      _textAnalyzing = true;
      message = 'Analyzing your meal...';
      result = null;
      _photoBytes = null;
      _savedToLog = false;
    });
    try {
      final scanResult = await scanFoodText(desc);
      if (!mounted) return;
      if (scanResult != null) {
        setState(() {
          result = scanResult;
          message = '';
        });
      } else {
        setState(() => message = 'Could not analyze meal — try rephrasing.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Connection lost — check your internet.');
      }
    }
    if (mounted) setState(() => _textAnalyzing = false);
  }

  Future<void> _addToLog() async {
    if (result == null || _saving || _savedToLog) return;
    setState(() => _saving = true);
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';
    bool saved = false;
    String? err;
    try {
      final logResp = await http.post(
        Uri.parse('$baseUrl/calories/log'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(result),
      );
      if (logResp.statusCode == 200) {
        final body = jsonDecode(logResp.body) as Map<String, dynamic>;
        saved = body['saved'] == true;
        err = body['error'] as String?;
      } else {
        err = 'Server error (${logResp.statusCode})';
      }
    } catch (_) {
      err = 'Connection lost';
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedToLog = saved;
    });
    if (saved) {
      TodayCache.invalidateActivity();
      triggerTodayRefresh();
      AppSnackbar.success(context, "Added to today's log");
    } else {
      AppSnackbar.error(
        context,
        err != null ? 'Could not save — $err' : 'Could not save to food log',
      );
    }
  }

  // ── Derived ────────────────────────────────────────────────────────────────

  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  List<Map<String, dynamic>> get _items =>
      ((result?['items'] as List?) ?? []).cast<Map<String, dynamic>>();

  /// AI tags derived from the macro breakdown.
  List<(String, Color)> get _tags {
    if (result == null) return [];
    final cal = _num(result!['calories']);
    if (cal <= 0) return [];
    final proteinPct = _num(result!['protein_g']) * 4 / cal;
    final fatPct = _num(result!['fat_g']) * 9 / cal;
    final carbsPct = _num(result!['carbs_g']) * 4 / cal;

    final tags = <(String, Color)>[];
    if (proteinPct >= 0.28) tags.add(('HIGH PROTEIN', kGreen));
    if (fatPct >= 0.18 && fatPct <= 0.40) tags.add(('GOOD FATS', kCyan));
    if (carbsPct >= 0.55) tags.add(('CARB HEAVY', kOrange));
    if (cal <= 450) tags.add(('LIGHT MEAL', kBlue));

    // Rough nutri-score: protein-dense and moderate calories score best.
    final grade = proteinPct >= 0.28 && cal <= 700
        ? 'A'
        : proteinPct >= 0.20
        ? 'B'
        : carbsPct >= 0.6 || cal > 900
        ? 'D'
        : 'C';
    tags.add(('NUTRI-SCORE $grade', kGold));
    return tags;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Calorie Scanner')),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result != null && _photoBytes != null) _photoHeader(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result == null) ...[
                    _capturePrompt(),
                    const SizedBox(height: 24),
                  ],
                  if (isLoading) _analyzing(),
                  if (message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: message.startsWith('Analyzing')
                              ? AppColors.textSecondary
                              : AppColors.error,
                        ),
                      ),
                    ),
                  if (result != null && !isLoading) ..._resultSections(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoHeader() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          child: Image.memory(
            _photoBytes!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              gradient: LinearGradient(
                colors: [Colors.transparent, kBgDeep.withValues(alpha: 0.55)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        if (_items.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kLime.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_avgConfidence()}% MATCH',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _avgConfidence() {
    if (_items.isEmpty) return 0;
    final sum = _items.fold<double>(0, (a, i) => a + _num(i['confidence']));
    return (sum / _items.length).round();
  }

  /// Big tappable camera target with a soft glow and floating food emojis —
  /// gives the empty scan state some life before the AI has anything to show.
  Widget _captureHero() {
    return GestureDetector(
      onTap: isLoading ? null : () => scanFood(ImageSource.camera),
      // Opaque so the whole block, padding included, is a tap target.
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          // Not const — a const instance would keep its old-theme colors when
          // the light/dark toggle flips (the framework skips identical widgets).
          ScanMotif(
            icon: Icons.photo_camera_rounded,
            accent: kBlue,
            size: 200,
            showDots: false,
          ),
          const SizedBox(height: 14),
          Text(
            'SNAP YOUR MEAL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _capturePrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _captureHero(),
        const SizedBox(height: 18),
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: kLabelSmall),
              ),
              Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
        ),
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
          style: FilledButton.styleFrom(
            backgroundColor: kBlue,
            foregroundColor: Colors.black,
          ),
          icon: _textAnalyzing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.auto_awesome, size: 18),
          label: Text(_textAnalyzing ? 'Analyzing...' : 'Analyze with AI'),
        ),
      ],
    );
  }

  Widget _analyzing() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(color: kBlue),
          SizedBox(height: 12),
          Text('Analyzing your food...'),
        ],
      ),
    );
  }

  List<Widget> _resultSections() {
    final cal = _num(result!['calories']);
    final pct = _calorieTarget > 0
        ? (cal / _calorieTarget * 100).round().clamp(0, 999)
        : 0;

    final sections = <Widget>[
      Text(
        _items.isNotEmpty
            ? 'SCAN RESULT · ${_items.length} ITEMS DETECTED'
            : 'SCAN RESULT',
        style: kLabelSmall.copyWith(color: kBlue, fontSize: 11),
      ),
      const SizedBox(height: 8),
      Text(
        (result!['food_name'] as String?) ?? 'Unknown food',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: kTextPrimary,
          letterSpacing: -0.6,
          height: 1.1,
        ),
      ),
      const SizedBox(height: 14),
      _heroCalories(cal, pct),
      const SizedBox(height: 20),
      _macroRow(),
      if (_items.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text('DETECTED ITEMS', style: kLabelSmall),
        const SizedBox(height: 6),
        ..._itemRows(),
      ],
      if (_tags.isNotEmpty) ...[const SizedBox(height: 16), _tagsRow()],
      const SizedBox(height: 20),
      _actionRow(),
      const SizedBox(height: 8),
      Center(
        child: Text(
          'Powered by AI — nutritional values are estimates.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ),
    ];

    return [
      for (var i = 0; i < sections.length; i++)
        sections[i]
            .animate()
            .fadeIn(duration: 280.ms, delay: (i * 60).ms)
            .slideY(begin: 0.04, end: 0, duration: 280.ms, delay: (i * 60).ms),
    ];
  }

  Widget _heroCalories(double cal, int pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: cal),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text(
                '${v.round()}',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: kLime,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 8, top: 18),
              child: Text(
                'kcal',
                style: TextStyle(
                  color: kTextSecondary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 44,
              height: 44,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, t, _) => CustomPaint(
                  painter: _GoalRingPainter(progress: t),
                  child: Center(
                    child: Text(
                      '$pct%',
                      style: const TextStyle(
                        color: kGold,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$pct% of your ${_calorieTarget.round()} daily goal',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _macroRow() {
    Widget tile(String label, double grams, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${grams.round()}',
                    style: TextStyle(
                      color: color,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'g',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: kLabelSmall.copyWith(fontSize: 9)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(height: 3, color: color),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('PROTEIN', _num(result!['protein_g']), kLime),
        const SizedBox(width: 10),
        tile('CARBS', _num(result!['carbs_g']), kCyan),
        const SizedBox(width: 10),
        tile('FAT', _num(result!['fat_g']), kGold),
      ],
    );
  }

  List<Widget> _itemRows() {
    const dotPalette = [kLime, kCyan, kGold, kPink, kGreen, kBlue];
    return [
      for (var i = 0; i < _items.length; i++)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotPalette[i % dotPalette.length],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_items[i]['name'] as String?) ?? '',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_num(_items[i]['grams']).round()} g · '
                      '${_num(_items[i]['confidence']).round()}% conf',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_num(_items[i]['calories']).round()} kcal',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _tagsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, color) in _tags)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionRow() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _savedToLog ? null : _addToLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.surfaceElevated,
                disabledForegroundColor: kGreen,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      _savedToLog ? '✓ Added to log' : "Add to today's log",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: OutlinedButton(
            onPressed: () => setState(() {
              result = null;
              _photoBytes = null;
              _savedToLog = false;
              message = '';
            }),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  static final ButtonStyle _scanBtnStyle = OutlinedButton.styleFrom(
    foregroundColor: kBlue,
    side: const BorderSide(color: kBlue),
    padding: const EdgeInsets.symmetric(vertical: 14),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

class _GoalRingPainter extends CustomPainter {
  _GoalRingPainter({required this.progress});

  final double progress;
  static const _stroke = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = kBgHighlight;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = kGold;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress.clamp(0.0, 1.0) * 2 * math.pi,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) => old.progress != progress;
}
