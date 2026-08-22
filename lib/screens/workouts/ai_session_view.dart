import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../api_service.dart';
import '../../services/nav_service.dart'
    show triggerTodayRefresh, triggerHistoryRefresh;
import '../../services/split_service.dart';
import '../../services/today_cache.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../utils/snackbar.dart';

/// AI-generated training session — the TODAY sub-tab of TRAIN.
/// The plan is built automatically from the user's profile and physique scan.
class AiSessionView extends StatefulWidget {
  const AiSessionView({super.key, this.onViewHistory});

  /// Jumps to the HISTORY segment (provided by WorkoutsTabScreen).
  final VoidCallback? onViewHistory;

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

/// Today's session state, kept outside the widget so leaving and re-entering
/// the TRAIN tab (MainScreen disposes tab subtrees) doesn't wipe a finished
/// workout or burn another AI generation. Cleared automatically on a new day.
class _SessionCache {
  static String? _dayKey;
  static String? _userKey;
  static Map<String, dynamic>? workout;
  static List<_GeneratedExercise> exercises = [];
  static Set<String> lagging = {};
  static bool started = false;
  static bool completed = false;
  static int completedCount = 0;
  static bool restOverride = false; // user asked to train on a rest day
  static String focus = '';

  static String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static String get _uid {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    } catch (_) {
      return 'anon';
    }
  }

  /// Drop yesterday's session so each day starts fresh, and drop it on an
  /// account change too — this state is process-wide, so otherwise a brand
  /// new account opens TRAIN to the previous user's finished session
  /// ("workout logged, 3 exercises").
  static void ensureToday() {
    if (_userKey != _uid) {
      _userKey = _uid;
      _dayKey = _today;
      reset();
      return;
    }
    if (_dayKey != _today) {
      _dayKey = _today;
      reset();
    }
  }

  static void reset() {
    workout = null;
    exercises = [];
    lagging = {};
    started = false;
    completed = false;
    completedCount = 0;
    restOverride = false;
    focus = '';
  }

  /// True when there's something worth restoring instead of regenerating.
  static bool get hasSession => workout != null || completed;
}

class _AiSessionViewState extends State<AiSessionView> {
  Map<String, dynamic>? workout;
  List<_GeneratedExercise> mainExercises = [];
  Set<String> _lagging = {}; // canonical lagging muscle groups
  bool isLoading = false;
  bool isSaving = false;
  bool _started = false; // true once the user has begun ticking off exercises
  int _completedCountLogged = 0; // exercises logged in the finished session
  bool _completed = false; // show the "workout logged" confirmation view
  bool _isRestDay = false;
  bool _restOverride = false; // user chose to train anyway on a rest day
  String error = '';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Rehydrate today's session from the cache; only generate when there
  /// genuinely isn't one yet.
  Future<void> _restore() async {
    _SessionCache.ensureToday();
    final split = await SplitService.getSplit();
    if (!mounted) return;

    _isRestDay = SplitService.isRestDay(split);
    _restOverride = _SessionCache.restOverride;

    if (_SessionCache.hasSession) {
      setState(() {
        workout = _SessionCache.workout;
        mainExercises = _SessionCache.exercises;
        _lagging = _SessionCache.lagging;
        _started = _SessionCache.started;
        _completed = _SessionCache.completed;
        _completedCountLogged = _SessionCache.completedCount;
        _focus = _SessionCache.focus.isNotEmpty
            ? _SessionCache.focus
            : SplitService.focusForToday(split);
      });
      return;
    }

    // Rest day: show the recovery view rather than auto-generating.
    if (_isRestDay && !_restOverride) {
      setState(() => _focus = SplitService.rest);
      return;
    }
    await _generate();
  }

  void _cache() {
    _SessionCache.workout = workout;
    _SessionCache.exercises = mainExercises;
    _SessionCache.lagging = _lagging;
    _SessionCache.started = _started;
    _SessionCache.completed = _completed;
    _SessionCache.completedCount = _completedCountLogged;
    _SessionCache.restOverride = _restOverride;
    _SessionCache.focus = _focus;
  }

  // ── Data ────────────────────────────────────────────────────────────────
  /// Today's focus — follows the user's chosen training split
  /// (Profile → Training Split); refreshed at the start of each generation.
  String _focus = 'Full Body';

  Future<void> _loadLagging() async {
    // Scan-first: FOCUS means "your scan scored this muscle weak" (< 7/10).
    // A strong muscle that merely ranks lowest is maintenance, not a lag.
    final scans = await getPhysiqueScans();
    if (scans.isNotEmpty) {
      final latest = scans.last;
      const keys = {
        'chest': 'chest_score',
        'back': 'back_score',
        'shoulders': 'shoulders_score',
        'arms': 'arms_score',
        'legs': 'legs_score',
        'core': 'core_score',
      };
      final weak =
          keys.entries
              .map(
                (e) => MapEntry(e.key, (latest[e.value] as num?)?.toDouble()),
              )
              .where((e) => e.value != null && e.value! < 7)
              .toList()
            ..sort((a, b) => a.value!.compareTo(b.value!));
      _lagging = weak.take(2).map((e) => e.key).toSet();
      return;
    }
    // No scan: nothing is marked FOCUS. This used to fall back to the two
    // least-trained muscle groups by volume, which tagged exercises FOCUS for
    // people who had never scanned — and "least trained in the last 30 days"
    // is not evidence a muscle is underdeveloped. With no logged workouts it
    // picked two groups at random. The session is still generated; it just
    // doesn't claim to know what's weak until a scan says so.
    _lagging = {};
  }

  Future<void> _generate() async {
    setState(() {
      isLoading = true;
      error = '';
      workout = null;
      mainExercises = [];
      _started = false;
      _completed = false;
    });

    final split = await SplitService.getSplit();
    _isRestDay = SplitService.isRestDay(split);
    // On a rest day the user explicitly asked for a session — pick a
    // sensible focus instead of asking the AI to program "Rest".
    _focus = _isRestDay
        ? _focusForRestOverride(split)
        : SplitService.focusForToday(split);
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
          'focus': _focus,
          'duration': 60,
          'intensity': 'Medium',
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _parseMainExercises(data);
          if (mainExercises.isEmpty) {
            // A session with no parseable exercises would render as an
            // empty shell — treat it as a failed generation instead.
            workout = null;
            error = 'Could not build your session. Pull to retry.';
          } else {
            workout = data;
          }
        });
      } else {
        setState(() => error = 'Could not build your session. Pull to retry.');
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Network error. Pull to retry.');
    }
    if (mounted) {
      setState(() => isLoading = false);
      _cache();
    }
  }

  /// The next training focus in the rotation — used when someone chooses to
  /// train on a scheduled rest day.
  String _focusForRestOverride(TrainingSplit split) {
    final r = SplitService.rotation(split);
    final today = (DateTime.now().weekday - 1) % r.length;
    for (var step = 1; step <= r.length; step++) {
      final f = r[(today + step) % r.length];
      if (f != SplitService.rest) return f;
    }
    return 'Full Body';
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
    _cache();
  }

  void _toggleExercise(int i) {
    HapticFeedback.selectionClick();
    setState(() => mainExercises[i].checked = !mainExercises[i].checked);
    _cache();
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
      TodayCache.markTrainedToday();
      triggerTodayRefresh();
      triggerHistoryRefresh();
      // Show an explicit confirmation view — the user should never wonder
      // whether the workout actually saved.
      setState(() {
        _started = false;
        _completedCountLogged = done.length;
        _completed = true;
      });
      _cache();
    } else {
      AppSnackbar.error(context, 'Could not log session');
    }
  }

  // ── Derived metrics ──────────────────────────────────────────────────────
  int get _estLoad => mainExercises.fold(0, (sum, e) => sum + e.sets * e.reps);

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

  /// Unique canonical muscle groups this session hits, in plan order.
  List<String> get _targetedGroups {
    final seen = <String>{};
    final groups = <String>[];
    for (final e in mainExercises) {
      final g = _canon(e.muscleGroup);
      if (g.isNotEmpty && seen.add(g)) groups.add(g);
    }
    return groups;
  }

  int get _totalSets =>
      mainExercises.fold(0, (sum, e) => sum + (e.sets <= 0 ? 1 : e.sets));

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
    final showRest = _isRestDay && !_restOverride && !_completed;
    return RefreshIndicator(
      onRefresh: () async {
        // Don't silently burn a generation on a rest day.
        if (_isRestDay && !_restOverride) return;
        await _generate();
      },
      color: kCyan,
      backgroundColor: kBgCard,
      child: isLoading
          ? _loadingState()
          : showRest
          ? _restDayView()
          : _completed
          ? _completedView()
          : (workout == null ? _errorState() : _sessionView()),
    );
  }

  /// Scheduled recovery day — the split has today off. Treated as a completed
  /// state (nothing to do), with an escape hatch to train anyway.
  Widget _restDayView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 60, 20, 32 + navBarClearance(context)),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kCyan.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kCyan.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bedtime_rounded, size: 38, color: kCyan),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'SCHEDULED RECOVERY',
                  style: TextStyle(
                    color: kCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Rest Day',
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your training split plans today as a recovery day, so there '
                "isn't a workout to do. Take the day off — or tap Train "
                'anyway below to add an extra session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _restOverride = true);
              _cache();
              _generate();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: kCyan,
              side: BorderSide(color: kCyan),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 20),
            label: const Text(
              'Train anyway',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Generates the next session in your split',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  /// Post-workout confirmation — unmistakable "it saved" feedback with a
  /// summary and clear next steps.
  Widget _completedView() {
    final n = _completedCountLogged;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 60, 20, 32 + navBarClearance(context)),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kLime.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kLime.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: kLime.withValues(alpha: 0.12),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      // Tinted green disc with a solid green check — reads in
                      // both themes and stays on-brand (never white/black).
                      color: kLime.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: kLime.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(Icons.check_rounded, size: 44, color: kLime),
                  )
                  .animate()
                  .scale(
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                    duration: 450.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 150.ms),
              const SizedBox(height: 18),
              Text(
                'Workout logged!',
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$n exercise${n == 1 ? '' : 's'} saved to your history — '
                'your dashboard and streak are updated.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: kLime,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.bolt_rounded, size: 20),
            label: const Text(
              'Generate another session',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (widget.onViewHistory != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onViewHistory,
            child: Text(
              'View it in your history →',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 80, 20, 20 + navBarClearance(context)),
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + navBarClearance(context)),
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
    final focus = (workout!['focus'] as String?) ?? _focus;
    final duration = (workout!['duration_minutes'] as num?)?.toInt() ?? 60;

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
      _targetsCard(),
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
      padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + navBarClearance(context)),
      children: [
        for (var i = 0; i < children.length; i++)
          children[i]
              .animate()
              .fadeIn(duration: 320.ms, delay: (i * 35).ms)
              .slideY(
                begin: 0.05,
                end: 0,
                duration: 320.ms,
                delay: (i * 35).ms,
              ),
      ],
    );
  }

  Widget _header(String focus, String? name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TODAY'S SESSION · ${focus.toUpperCase()}", style: kLabelSmall),
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
          // FittedBox keeps large values from overflowing the narrow
          // pill on small phone widths (~360px).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 30,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whyCard() {
    // NOTE: a non-uniform Border (thick left accent + faint other sides)
    // combined with borderRadius makes Flutter throw during paint(), which
    // silently blanks the card's content. Round the corners with a ClipRRect
    // instead and draw the accent stripe as its own element.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: kCyan.withValues(alpha: 0.06),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: kCyan),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: kCyan,
                          ),
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
                        // Capped so a long AI explanation can't balloon the card.
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              // The name takes whatever the reps column does not need. A
              // fixed flex reserved ~40% of the row for reps even when they
              // read "4 x 12", and that unused width was what truncated the
              // names.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.exercise,
                            // Two lines, not one-plus-ellipsis: names like
                            // "Single-Arm Dumbbell Row" don't fit a half-row
                            // and truncating them hides which lift it is.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (focus) ...[const SizedBox(width: 8), _focusTag()],
                      ],
                    ),
                    if ((e.muscleGroup ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        e.muscleGroup!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              // Capped rather than flexed: short reps take only the width
              // they need, while prose ones ("30-45 sec hold per arm") still
              // cannot grow far enough to crush the name.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: Text(
                  '${e.sets} × ${e.repsRaw}',
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
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
      child: Text(
        'FOCUS',
        style: TextStyle(
          color: kPink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// What this session actually hits: muscle-group pills (focus areas in
  /// pink) plus a plain-English set count. Always accurate — derived from
  /// the plan itself, unlike the old rep-range intensity guess.
  Widget _targetsCard() {
    final groups = _targetedGroups;
    if (groups.isEmpty) return const SizedBox.shrink();
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
          _label('THIS SESSION TARGETS'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in groups)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _lagging.contains(g)
                        ? kPink.withValues(alpha: 0.15)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _lagging.contains(g)
                          ? kPink.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    _titleCase(g),
                    style: TextStyle(
                      color: _lagging.contains(g)
                          ? kPink
                          : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_totalSets working sets across ${groups.length} '
            'muscle group${groups.length == 1 ? '' : 's'}'
            '${_lagging.isNotEmpty ? ' — extra volume on your focus areas' : ''}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
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
              style: TextStyle(
                color: kCyan,
                fontSize: 14,
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
