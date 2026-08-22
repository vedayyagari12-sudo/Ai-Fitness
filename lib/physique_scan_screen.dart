import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_service.dart';
import 'services/nav_service.dart' show mainTabIndex, triggerTodayRefresh;
import 'services/permission_service.dart';
import 'services/today_cache.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'utils/snackbar.dart';

class PhysiqueScanScreen extends StatefulWidget {
  const PhysiqueScanScreen({
    super.key,
    this.initialImagePath,
    this.embedded = false,
  });

  final String? initialImagePath;
  final bool embedded;

  @override
  State<PhysiqueScanScreen> createState() => _PhysiqueScanScreenState();
}

class _PhotoSlot {
  _PhotoSlot(this.label);
  final String label; // Front / Back / Side
  XFile? file;
  Uint8List? bytes;
}

class _PhysiqueScanScreenState extends State<PhysiqueScanScreen> {
  final ImagePicker picker = ImagePicker();
  final List<_PhotoSlot> _slots = [
    _PhotoSlot('Front'),
    _PhotoSlot('Back'),
    _PhotoSlot('Side'),
  ];
  Map<String, dynamic>? result;
  bool isLoading = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      final f = XFile(widget.initialImagePath!);
      _slots[0].file = f;
      f.readAsBytes().then((b) {
        if (mounted) setState(() => _slots[0].bytes = b);
      });
    }
  }

  List<_PhotoSlot> get _filled => _slots.where((s) => s.file != null).toList();

  Future<void> _pickFor(_PhotoSlot slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final granted = await (source == ImageSource.camera
        ? PermissionService.requestCamera(context)
        : PermissionService.requestGallery(context));
    if (!granted) return;

    XFile? image;
    try {
      image = await picker.pickImage(
        source: source,
        imageQuality: 80,
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
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      slot.file = image;
      slot.bytes = bytes;
      message = '';
    });
  }

  Future<void> scanPhysique() async {
    if (_filled.isEmpty) {
      setState(() => message = 'Add at least one photo first.');
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
        Uri.parse('$baseUrl/physique/scan'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      for (final slot in _filled) {
        final imageBytes = slot.bytes ?? await slot.file!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            imageBytes,
            filename: 'physique_${slot.label.toLowerCase()}.jpg',
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        setState(() {
          result = data;
          message = '';
        });
        // The AI analysis succeeded but the row failed to persist (e.g. a
        // transient DB error). Retry the save alone — never re-run the paid
        // analysis for a persistence failure.
        if (data['saved'] == false) {
          final retried = await savePhysiqueScan(data);
          if (!mounted) return;
          if (retried) {
            data['saved'] = true;
          } else {
            AppSnackbar.error(
              context,
              "Analysis complete, but we couldn't save this scan — "
              'it won\'t appear in BODY',
            );
          }
        }
        if (data['saved'] == true) {
          TodayCache.invalidateActivity();
          triggerTodayRefresh();
        }
      } else {
        setState(() => message = 'Could not analyze photos — try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = 'Connection lost — check your internet.');
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ── Derived ────────────────────────────────────────────────────────────────

  static const _muscleOrder = [
    'chest',
    'back',
    'shoulders',
    'arms',
    'legs',
    'core',
  ];

  List<(String, int, String)> get _muscles {
    final groups = result?['muscle_groups'] as Map<String, dynamic>? ?? {};
    return [
      for (final m in _muscleOrder)
        if (groups[m] != null)
          (
            m,
            ((groups[m] as Map)['score'] as num?)?.toInt() ?? 0,
            ((groups[m] as Map)['feedback'] as String?) ?? '',
          ),
    ];
  }

  List<String> get _weakMuscles {
    final scored = _muscles.toList()..sort((a, b) => a.$2.compareTo(b.$2));
    return [
      for (final (name, score, _) in scored)
        if (score < 7) name,
    ].take(2).toList();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Physique Scanner')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + navBarClearance(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result == null) ...[
              Text(
                'Add 1-3 photos for best results',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < _slots.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _slotTile(_slots[i])),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (_filled.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : scanPhysique,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(
                      isLoading ? 'Analyzing...' : 'Analyze Physique',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: kBlue),
                      SizedBox(height: 12),
                      Text('Analyzing your physique...'),
                    ],
                  ),
                ),
              ),
            if (message.isNotEmpty && !isLoading)
              Text(
                message,
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            if (result != null && !isLoading) ..._resultSections(),
          ],
        ),
      ),
    );
  }

  Widget _slotTile(_PhotoSlot slot) {
    final hasPhoto = slot.bytes != null;
    return GestureDetector(
      onTap: isLoading ? null : () => _pickFor(slot),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasPhoto ? kBlue.withValues(alpha: 0.6) : AppColors.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(slot.bytes!, fit: BoxFit.cover),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          slot.file = null;
                          slot.bytes = null;
                        }),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          slot.label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 26,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slot.label,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _resultSections() {
    final sections = <Widget>[
      _scoreHero(),
      const SizedBox(height: 12),
      if (_muscles.isNotEmpty) _muscleCard(),
      const SizedBox(height: 12),
      if (result!['posture'] != null) _postureCard(),
      const SizedBox(height: 12),
      _listCard('STRENGTHS', result!['strengths'], kGreen),
      const SizedBox(height: 12),
      _listCard('NEEDS WORK', result!['weaknesses'], kGold),
      const SizedBox(height: 12),
      _listCard('RECOMMENDATIONS', result!['recommendations'], kCyan),
      if (_weakMuscles.isNotEmpty) ...[
        const SizedBox(height: 16),
        _focusBanner(),
      ],
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () => setState(() {
              result = null;
              for (final s in _slots) {
                s.file = null;
                s.bytes = null;
              }
            }),
            child: Text(
              'New scan',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      Center(
        child: Text(
          'For fitness purposes only. Not medical advice.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ),
      const SizedBox(height: 8),
    ];

    return [
      for (var i = 0; i < sections.length; i++)
        sections[i]
            .animate()
            .fadeIn(duration: 280.ms, delay: (i * 60).ms)
            .slideY(begin: 0.04, end: 0, duration: 280.ms, delay: (i * 60).ms),
    ];
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _scoreHero() {
    final score = (result!['overall_score'] as num?)?.toInt() ?? 0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PHYSIQUE SCAN RESULT', style: kLabelSmall),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score.toDouble()),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  '${v.round()}',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: kLime,
                    height: 1.0,
                    letterSpacing: -3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 6),
                child: Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Overall Physique Score',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 6),
          if (result!['body_fat_estimate'] != null)
            _infoRow('Body Fat', '${result!['body_fat_estimate']}', kPink),
          if (result!['body_type'] != null)
            _infoRow('Body Type', '${result!['body_type']}', null),
          if (result!['symmetry_score'] != null)
            _infoRow('Symmetry', '${result!['symmetry_score']}/10', null),
          if (result!['visible_angles'] != null)
            _infoRow(
              'Angles Analyzed',
              (result!['visible_angles'] as List).join(', '),
              null,
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _muscleCard() {
    final weak = _weakMuscles.toSet();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MUSCLE DEVELOPMENT', style: kLabelSmall),
          const SizedBox(height: 12),
          for (final (name, score, feedback) in _muscles) ...[
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Row(
                    children: [
                      Text(
                        name[0].toUpperCase() + name.substring(1),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (weak.contains(name)) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LAG',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score / 10),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 4,
                        backgroundColor: kFillSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          score >= 7
                              ? AppColors.success
                              : score >= 5
                              ? kGold
                              : AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$score',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (feedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 10),
                child: Text(
                  feedback,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              )
            else
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _postureCard() {
    final posture = result!['posture'] as Map<String, dynamic>;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POSTURE', style: kLabelSmall),
          const SizedBox(height: 8),
          if (posture['overall'] != null)
            _infoRow('Overall', '${posture['overall']}', null),
          if (posture['head_position'] != null)
            _infoRow('Head', '${posture['head_position']}', null),
          if (posture['shoulder_alignment'] != null)
            _infoRow('Shoulders', '${posture['shoulder_alignment']}', null),
          if (posture['hip_alignment'] != null)
            _infoRow('Hips', '${posture['hip_alignment']}', null),
          if (posture['feedback'] != null) ...[
            const SizedBox(height: 6),
            Text(
              '${posture['feedback']}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _listCard(String title, dynamic items, Color accent) {
    final list = ((items as List?) ?? []).cast<String>();
    if (list.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kLabelSmall.copyWith(color: accent)),
          const SizedBox(height: 8),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _focusBanner() {
    final names = _weakMuscles.join(' & ');
    return GestureDetector(
      onTap: () => mainTabIndex.value = 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kPink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPink.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_weakMuscles.length} FOCUS AREAS FOUND',
                    style: kLabelSmall.copyWith(color: kPink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${names[0].toUpperCase()}${names.substring(1)} '
                    'lagging — we built a plan.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: kPink, shape: BoxShape.circle),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
