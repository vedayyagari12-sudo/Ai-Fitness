import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../api_service.dart';
import '../../screens/today_screen.dart' show triggerTodayRefresh;
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../utils/snackbar.dart';

/// AI-generated training session — the TODAY sub-tab of TRAIN.
/// The plan is built automatically from the user's profile and physique scan.
class AiSessionView extends StatefulWidget {
  const AiSessionView({super.key});

  @override
  State<AiSessionView> createState() => _AiSessionViewState();
}

class _GeneratedExercise {
  _GeneratedExercise({
    required this.exercise,
    required this.sets,
    required this.repsRaw,
    required this.reps,
    this.weight,
    this.muscleGroup,
  });

  final String exercise;
  final int sets;
  final dynamic repsRaw;
  final int reps;
  double? weight;
  final String? muscleGroup;
  bool checked = false;
}

class _AiSessionViewState extends State<AiSessionView>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? workout;
  List<_GeneratedExercise> mainExercises = [];
  Set<String> _lagging = {}; // canonical lagging muscle groups
  bool isLoading = false;
  bool isSaving = false;
  bool _started = false; // true once the user has begun ticking off exercises
  String error = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  // ── Data ────────────────────────────────────────────────────────────────
  /// Focus split derived from the day so consecutive sessions rotate.
  String get _autoFocus {
    const rotation = [
      'Push', // Mon
      'Pull', // Tue
      'Legs', // Wed
      'Upper Body', // Thu
      'Push', // Fri
      'Full Body', // Sat
      'Pull', // Sun
    ];
    return rotation[(DateTime.now().weekday - 1) % rotation.length];
  }

  Future<void> _loadLagging() async {
    final muscle = await getMuscleBalance();
    final groups = muscle?['groups'] as Map<String, dynamic>? ?? {};
    if (groups.isEmpty) return;
    final entries =
        groups.entries
            .map((e) => MapEntry(e.key, (e.value as num).toDouble()))
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    // The two least-trained groups are "lagging".
    _lagging = entries.take(2).map((e) => e.key.toLowerCase()).toSet();
  }

  Future<void> _generate() async {
    setState(() {
      isLoading = true;
      error = '';
      workout = null;
      mainExercises = [];
      _started = false;
    });

    await _loadLagging();

    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final response = await http.post(
        Uri.parse('$baseUrl/workouts/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'goal': 'Build Muscle',
          'equipment': 'Full Gym',
          'focus': _autoFocus,
          'duration': 60,
          'intensity': 'Medium',
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          workout = data;
          _parseMainExercises(data);
        });
      } else {
        setState(() => error = 'Could not build your session. Pull to retry.');
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Network error. Pull to retry.');
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _parseMainExercises(Map<String, dynamic> data) {
    final list = data['main_workout'] as List? ?? [];
    mainExercises = list.map((e) {
      final weight = e['weight'];
      return _GeneratedExercise(
        exercise: e['exercise'] ?? '',
        sets: (e['sets'] as num?)?.toInt() ?? 0,
        repsRaw: e['reps'],
        reps: parseReps(e['reps']),
        weight: weight is num ? weight.toDouble() : null,
        muscleGroup: e['muscle_group'] as String?,
      );
    }).toList();
  }

  int get _completedCount => mainExercises.where((e) => e.checked).length;

  /// Step 1 — enter "in session" mode where the user ticks off each lift.
  void _beginSession() {
    if (mainExercises.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _started = true;
      for (final e in mainExercises) {
        e.checked = false;
      }
    });
  }

  void _toggleExercise(int i) {
    HapticFeedback.selectionClick();
    setState(() => mainExercises[i].checked = !mainExercises[i].checked);
  }

  /// Step 2 — log only the exercises the user actually completed.
  Future<void> _finishSession() async {
    final done = mainExercises.where((e) => e.checked).toList();
    if (done.isEmpty) return;
    setState(() => isSaving = true);
    final payload = done
        .map(
          (e) => {
            'exercise': e.exercise,
            'sets': e.sets,
            'reps': e.reps,
            if (e.weight != null) 'weight': e.weight,
          },
        )
        .toList();
    final ok = await saveWorkoutBatch(payload);
    if (!mounted) return;
    setState(() => isSaving = false);
    if (ok) {
      HapticFeedback.heavyImpact();
      final n = done.length;
      setState(() => _started = false);
      triggerTodayRefresh();
      AppSnackbar.success(
        context,
        '$n exercise${n == 1 ? '' : 's'} logged — nice work 💪',
      );
    } else {
      AppSnackbar.error(context, 'Could not log session');
    }
  }

  // ── Derived metrics ──────────────────────────────────────────────────────
  int get _estLoad =>
      mainExercises.fold(0, (sum, e) => sum + e.sets * e.reps);

  String _canon(String? raw) {
    final g = (raw ?? '').toLowerCase();
    if (g.contains('delt') || g.contains('shoulder')) return 'shoulders';
    if (g.contains('chest') || g.contains('pec')) return 'chest';
    if (g.contains('back') ||
        g.contains('lat') ||
        g.contains('trap') ||
        g.contains('row')) {
      return 'back';
    }
    if (g.contains('quad') ||
        g.contains('ham') ||
        g.contains('glute') ||
        g.contains('calf') ||
        g.contains('leg')) {
      return 'legs';
    }
    if (g.contains('bicep') ||
        g.contains('tricep') ||
        g.contains('arm') ||
        g.contains('curl')) {
      return 'arms';
    }
    if (g.contains('core') || g.contains('ab')) return 'core';
    return g;
  }

  bool _isFocus(_GeneratedExercise e) =>
      _lagging.contains(_canon(e.muscleGroup));

  /// % of total work-sets in strength / hypertrophy / pump rep ranges.
  (int, int, int) get _intensityMix {
    var strength = 0, hyper = 0, pump = 0;
    for (final e in mainExercises) {
      final s = e.sets <= 0 ? 1 : e.sets;
      if (e.reps <= 6) {
        strength += s;
      } else if (e.reps <= 12) {
        hyper += s;
      } else {
        pump += s;
      }
    }
    final total = strength + hyper + pump;
    if (total == 0) return (0, 0, 0);
    final a = (strength / total * 100).round();
    final b = (hyper / total * 100).round();
    return (a, b, 100 - a - b);
  }

  String get _whyText {
    final fromBackend = (workout?['why_this_session'] as String?)?.trim();
    if (fromBackend != null && fromBackend.isNotEmpty) return fromBackend;
    if (_lagging.isEmpty) {
      return 'Built from your goals and recent training so every muscle '
          'gets balanced volume across the week.';
    }
    final names = _lagging.map(_titleCase).join(' & ');
    return 'Your latest scan flagged $names as lagging. This session adds '
        'focused volume there while keeping your strong areas in maintenance.';
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _generate,
      color: kCyan,
      backgroundColor: kBgCard,
      child: isLoading
          ? _loadingState()
          : (workout == null ? _errorState() : _sessionView()),
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      children: [
        Icon(Icons.bolt_rounded, size: 44, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(
          error.isEmpty ? 'No session yet' : error,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _loadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        const SizedBox(height: 8),
        ShimmerBox(width: 180, height: 14, borderRadius: 6),
        const SizedBox(height: 14),
        ShimmerBox(width: 240, height: 34, borderRadius: 8),
        const SizedBox(height: 20),
        Row(
          children: List.generate(
            3,
            (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 10),
                child: ShimmerBox(
                  width: double.infinity,
                  height: 70,
                  borderRadius: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShimmerBox(width: double.infinity, height: 92, borderRadius: 18),
        const SizedBox(height: 20),
        ...List.generate(
          5,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerBox(
              width: double.infinity,
              height: 56,
              borderRadius: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sessionView() {
    final name = (workout!['workout_name'] as String?)?.trim();
    final focus = (workout!['focus'] as String?) ?? _autoFocus;
    final duration = (workout!['duration_minutes'] as num?)?.toInt() ?? 60;
    final mix = _intensityMix;

    final children = <Widget>[
      _header(focus, name),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(child: _statBox('DURATION', '$duration', 'min', null)),
          const SizedBox(width: 10),
          Expanded(
            child: _statBox('EXERCISES', '${mainExercises.length}', '', null),
          ),
          const SizedBox(width: 10),
          Expanded(child: _statBox('EST. LOAD', '$_estLoad', '', kGold)),
        ],
      ),
      const SizedBox(height: 16),
      _whyCard(),
      const SizedBox(height: 22),
      _planHeader(),
      const SizedBox(height: 6),
      ..._planRows(),
      const SizedBox(height: 18),
      _intensityCard(mix),
      const SizedBox(height: 20),
      _sessionButton(),
      const SizedBox(height: 28),
      Center(
        child: Text(
          'For fitness purposes only. Not medical advice.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (var i = 0; i < children.length; i++)
          children[i]
              .animate()
              .fadeIn(duration: 320.ms, delay: (i * 35).ms)
              .slideY(begin: 0.05, end: 0, duration: 320.ms, delay: (i * 35).ms),
      ],
    );
  }

  Widget _header(String focus, String? name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S SESSION · ${focus.toUpperCase()}",
          style: kLabelSmall,
        ),
        const SizedBox(height: 8),
        Text(
          name?.isNotEmpty == true ? name! : '$focus Session',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.05,
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, String unit, Color? valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
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
                value,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCyan.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: kCyan, width: 3),
          top: BorderSide(color: kCyan.withValues(alpha: 0.2)),
          right: BorderSide(color: kCyan.withValues(alpha: 0.2)),
          bottom: BorderSide(color: kCyan.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: kCyan),
              const SizedBox(width: 6),
              Text(
                'WHY THIS SESSION',
                style: kLabelSmall.copyWith(color: kCyan),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _whyText,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.9),
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t, style: kLabelSmall);

  List<Widget> _planRows() {
    return List.generate(mainExercises.length, (i) {
      final e = mainExercises[i];
      final focus = _isFocus(e);
      final done = _started && e.checked;

      final Color borderColor;
      if (done) {
        borderColor = kCyan.withValues(alpha: 0.6);
      } else if (focus) {
        borderColor = kPink.withValues(alpha: 0.45);
      } else {
        borderColor = AppColors.border;
      }

      return GestureDetector(
        onTap: _started ? () => _toggleExercise(i) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: done ? kCyan.withValues(alpha: 0.07) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Leading: number normally, tappable checkbox once started.
              SizedBox(
                width: 24,
                child: _started
                    ? _checkDot(done)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.exercise,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (focus) ...[
                          const SizedBox(width: 8),
                          _focusTag(),
                        ],
                      ],
                    ),
                    if ((e.muscleGroup ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        e.muscleGroup!.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${e.sets} × ${e.repsRaw}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _checkDot(bool done) {
    return AnimatedScale(
      scale: done ? 1.0 : 0.92,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: done ? kCyan : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: done ? kCyan : AppColors.textMuted,
            width: 2,
          ),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
            : null,
      ),
    );
  }

  Widget _focusTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: kPink.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'FOCUS',
        style: TextStyle(
          color: kPink,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _intensityCard((int, int, int) mix) {
    final (s, h, p) = mix;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('INTENSITY MIX'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                if (s > 0)
                  Expanded(
                    flex: s,
                    child: Container(height: 10, color: kBlue),
                  ),
                if (h > 0)
                  Expanded(
                    flex: h,
                    child: Container(height: 10, color: kGold),
                  ),
                if (p > 0)
                  Expanded(
                    flex: p,
                    child: Container(height: 10, color: kPink),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _mixLegend(kBlue, 'Strength', s),
              const Spacer(),
              _mixLegend(kGold, 'Hypertrophy', h),
              const Spacer(),
              _mixLegend(kPink, 'Pump', p),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mixLegend(Color c, String label, int pct) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: 5),
        Text(
          '$pct%',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _planHeader() {
    return Row(
      children: [
        _label(_started ? 'TICK WHAT YOU COMPLETED' : 'THE PLAN'),
        const Spacer(),
        if (_started)
          GestureDetector(
            onTap: () {
              final all = _completedCount == mainExercises.length;
              HapticFeedback.selectionClick();
              setState(() {
                for (final e in mainExercises) {
                  e.checked = !all;
                }
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Text(
              _completedCount == mainExercises.length
                  ? 'Clear all'
                  : 'Select all',
              style: const TextStyle(
                color: kCyan,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sessionButton() {
    final disabled = mainExercises.isEmpty || isSaving;
    final finishReady = _started && _completedCount > 0;

    final label = !_started
        ? 'Start session'
        : (_completedCount == 0
              ? 'Tick the exercises you did'
              : 'Finish · $_completedCount done');

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: disabled
                ? null
                : (!_started
                      ? _beginSession
                      : (finishReady ? _finishSession : null)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCyan,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppColors.surfaceElevated,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        !_started
                            ? Icons.play_arrow_rounded
                            : Icons.check_circle_rounded,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_started && !isSaving) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _started = false),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (!_started && !isLoading) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _generate,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Generate different session →',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
