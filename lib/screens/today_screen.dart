import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api_service.dart';
import '../models/readiness_data.dart';
import '../services/nav_service.dart';
import '../services/split_service.dart';
import '../services/today_cache.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/theme_controller.dart';
import '../utils/strength_trend.dart';
import '../utils/units.dart';
import '../widgets/physique_mini_card.dart';
import '../widgets/readiness_card.dart';
import '../widgets/recent_scan_thumb.dart';
import '../widgets/section_label.dart';
import '../widgets/streak_chip.dart';
import '../widgets/today_session_card.dart';
import '../widgets/trend_card.dart';
import '../widgets/week_strip.dart';
import 'profile/profile_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _loading = true;
  Map<String, dynamic>? _dash;
  Map<String, dynamic>? _streak;
  List<Map<String, dynamic>> _weeklySummary = [];
  List<dynamic> _workouts = [];
  TrainingSplit _split = TrainingSplit.auto;

  @override
  void initState() {
    super.initState();
    todayTick.addListener(_load);
    // Repaint immediately on a theme flip — the profile screen (where the
    // toggle lives) sits on top of this one, so a stale frame shows through.
    ThemeController.mode.addListener(_onThemeChange);
    _load();
  }

  @override
  void dispose() {
    todayTick.removeListener(_load);
    ThemeController.mode.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    TodayCache.ensureToday();
    final results = await Future.wait([
      getDashboard(),
      getStreak(),
      getWeeklySummary(),
      getWorkouts(),
    ]);
    final split = await SplitService.getSplit();
    if (!mounted) return;
    setState(() {
      _dash = results[0] as Map<String, dynamic>?;
      _streak = results[1] as Map<String, dynamic>?;
      _weeklySummary = (results[2] as List).cast<Map<String, dynamic>>();
      _workouts = results[3] as List;
      _split = split;
      _loading = false;
    });
  }

  // ── Derived data ────────────────────────────────────────────────────────────

  Map<String, dynamic> get _stats =>
      (_dash?['today_stats'] as Map<String, dynamic>?) ?? {};

  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  String get _goal => (_dash?['goal'] as String?) ?? 'maintain';

  int get _sessionsToday => _num(_stats['sessions']).toInt();

  /// True once today's workout is logged — trusts the real dashboard count,
  /// but ORs in the optimistic cache flag so the card flips the instant a
  /// session is saved instead of waiting on a dashboard refetch to catch up.
  bool get _trainedToday => _sessionsToday > 0 || TodayCache.trainedToday;

  ReadinessData get _readiness {
    // DAILY score — everything below is about TODAY only, so it naturally
    // resets to 0 each morning and 100 is achievable every single day:
    // train once (40%) + hit your calories (35%) + hit your protein (25%).
    final trained = _trainedToday ? 1.0 : 0.0;

    final kcal = _num(_stats['calories']);
    final kcalTarget = _num(_stats['calorie_target']);
    final fueled = kcalTarget > 0 ? (kcal / kcalTarget).clamp(0.0, 1.0) : 0.0;

    final protein = _num(_stats['protein']);
    final proteinTarget = _num(_stats['protein_target']);
    final proteinP = proteinTarget > 0
        ? (protein / proteinTarget).clamp(0.0, 1.0)
        : 0.0;

    final bf = _num(_stats['body_fat']);
    final bfChange = _num(_stats['body_fat_change']);
    final volume = _num(_stats['volume']).round();

    final score = ((trained * 0.40 + fueled * 0.35 + proteinP * 0.25) * 100)
        .round()
        .clamp(0, 100);

    return ReadinessData(
      score: score,
      caloriesProgress: fueled,
      proteinProgress: proteinP,
      sessionsProgress: trained,
      fueledValue: '${(fueled * 100).round()}%',
      caloriesLabel: '${_formatThousands(kcal.round())} kcal',
      loadValue: '$volume',
      loadLabel: '${_sessionFocus().toLowerCase()} day',
      proteinValue: '${protein.round()}g',
      proteinTarget: proteinTarget > 0
          ? 'of ${proteinTarget.round()}g'
          : 'set a goal',
      bodyFatValue: bf > 0 ? '${bf.toStringAsFixed(1)}%' : '—',
      bodyFatDelta: bfChange != 0
          ? '${bfChange > 0 ? '+' : ''}${bfChange.toStringAsFixed(1)}%'
          : '',
      trainingDetail: _trainedToday
          ? 'Trained today ✓'
          : 'No workout yet today',
      fuelDetail: kcalTarget > 0
          ? '${_formatThousands(kcal.round())} of '
                '${_formatThousands(kcalTarget.round())} kcal today'
          : '${_formatThousands(kcal.round())} kcal today',
      proteinDetail: proteinTarget > 0
          ? '${protein.round()}g of ${proteinTarget.round()}g today'
          : '${protein.round()}g today',
    );
  }

  /// Today's focus — follows the user's chosen training split, matching
  /// what the AI session generator will build.
  String _sessionFocus() => SplitService.focusForToday(_split);

  bool get _isRestDay => SplitService.isRestDay(_split);

  String _sessionName() {
    final focus = _sessionFocus();
    if (focus == SplitService.rest) return 'Rest day';
    final g = _goal.toLowerCase();
    if (g.contains('cut') || g.contains('lose')) return '$focus Conditioning';
    return '$focus Session';
  }

  /// Raw trend series as sent by the backend (zeros preserved — for the
  /// calorie chart a zero day means "nothing logged" and must stay visible).
  List<double> _rawTrendValues(String key) {
    final trends = (_dash?['trends'] as Map<String, dynamic>?) ?? {};
    final entry = (trends[key] as Map<String, dynamic>?) ?? {};
    return ((entry['values'] as List?) ?? [])
        .map((v) => (v as num).toDouble())
        .toList();
  }

  /// Trend series with the backend's all-zero "[0.0]" sentinel treated
  /// as no data at all.
  List<double> _trendValues(String key) {
    final values = _rawTrendValues(key);
    return values.where((v) => v != 0.0).isEmpty ? <double>[] : values;
  }

  List<String> get _dayLabels {
    final trends = (_dash?['trends'] as Map<String, dynamic>?) ?? {};
    final entry = (trends['calories'] as Map<String, dynamic>?) ?? {};
    return ((entry['labels'] as List?) ?? []).cast<String>();
  }

  /// Daily calorie target — computed on the backend from the user's profile
  /// (height, weight, age, gender, activity via Mifflin-St Jeor TDEE) and
  /// adjusted for their goal (surplus to bulk, deficit to cut). Using the
  /// backend value keeps the ring and the chart's target line in agreement.
  double get _calorieTarget {
    final backend = _num(_stats['calorie_target']);
    return backend > 0 ? backend : 2200;
  }

  /// Weekly training volume in lbs lifted, oldest → newest (up to 8 weeks).
  /// Backend returns newest-first.
  List<double> get _weeklyVolume => [
    for (final w in _weeklySummary.reversed)
      (w['total_volume'] as num?)?.toDouble() ?? 0.0,
  ];

  /// Estimated 1-rep max for a single tracked lift, oldest week first.
  ///
  /// Following one exercise rather than the week's heaviest anything: mixing
  /// lifts meant a squat week beside a curl week read as a collapse in
  /// strength, and the number described a different exercise every bar.
  StrengthTrend get _strengthTrend => strengthTrend(_workouts);

  int? get _latestScanScore {
    final scans = ((_dash?['recent_scans'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    if (scans.isEmpty) return null;
    return (scans.first['score'] as num?)?.toInt();
  }

  /// Total scan count — the newest recent_scans entry carries its ordinal.
  int get _scanCount {
    final scans = ((_dash?['recent_scans'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    if (scans.isEmpty) return 0;
    return (scans.first['number'] as num?)?.toInt() ?? 0;
  }

  /// Muscle groups the latest scan called out, for the TODAY physique card.
  /// [key] is 'focus' (rated weak) or 'strong'.
  List<String> _scanHighlight(String key) {
    final scans = ((_dash?['recent_scans'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    if (scans.isEmpty) return const [];
    return ((scans.first[key] as List?) ?? []).cast<String>();
  }

  /// Per-muscle scores from the latest scan, weakest first.
  List<(String, double)> get _scanMuscles {
    final scans = ((_dash?['recent_scans'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    if (scans.isEmpty) return const [];
    return [
      for (final m in ((scans.first['muscles'] as List?) ?? []))
        if (m is Map<String, dynamic> && m['name'] != null)
          (m['name'] as String, (m['score'] as num?)?.toDouble() ?? 0),
    ];
  }

  List<double> get _bfPoints {
    final charts = (_dash?['charts'] as List?) ?? [];
    final bf = charts.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['id'] == 'body_fat_trend',
      orElse: () => null,
    );
    if (bf == null) return [];
    final values = ((bf['values'] as List?) ?? [])
        .map((v) => (v as num).toDouble())
        .where((v) => v > 0)
        .toList();
    return values;
  }

  String _formatThousands(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      body: AmbientBackground(
        accent: kPink, // top-right glow
        accent2: kLime, // bottom-left glow — two-tone
        child: SafeArea(child: _loading ? _skeleton() : _content()),
      ),
    );
  }

  Widget _content() {
    final bf = _num(_stats['body_fat']);
    final bfChange = _num(_stats['body_fat_change']);
    final hasScan = ((_dash?['recent_scans'] as List?) ?? []).isNotEmpty;

    final weeklyActivity = [
      for (final a in (_streak?['weekly_activity'] as List?) ?? []) a == true,
    ];

    final sections = <Widget>[
      _header(),
      const SizedBox(height: 16),
      if (weeklyActivity.isNotEmpty) ...[
        WeekStrip(
          activity: weeklyActivity,
          streak: (_streak?['current_streak'] as num?)?.toInt() ?? 0,
        ),
        const SizedBox(height: 12),
      ],
      ReadinessCard(data: _readiness),
      const SizedBox(height: 12),
      TrendCard(
        goal: _goal,
        weightLbs: [for (final kg in _trendValues('weight')) kgToLbs(kg)],
        dailyCalories: _rawTrendValues('calories'),
        dayLabels: _dayLabels,
        calorieTarget: _calorieTarget,
        weeklyVolume: _weeklyVolume,
        weeklyStrength: _strengthTrend.weekly,
        strengthExercise: _strengthTrend.exercise,
      ),
      const SizedBox(height: 12),
      // IntrinsicHeight + stretch: the two cards hold different amounts of
      // text, and left ragged they end at different heights.
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PhysiqueMiniCard(
                bodyFat: bf > 0 ? bf : null,
                score: _latestScanScore,
                scanCount: _scanCount,
                delta: bfChange != 0
                    ? '${bfChange > 0 ? '+' : ''}${bfChange.toStringAsFixed(1)}% vs last scan'
                    : null,
                deltaPositive: bfChange <= 0,
                points: _bfPoints,
                focus: _scanHighlight('focus'),
                strong: _scanHighlight('strong'),
                muscles: _scanMuscles,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TodaySessionCard(
                title: _sessionName(),
                meta: _isRestDay
                    ? 'Recovery — nothing scheduled'
                    : '~45 min · AI generated',
                note: _isRestDay
                    ? ''
                    : (hasScan ? 'Tuned to your physique scan' : ''),
                startLabel: _isRestDay ? 'View →' : 'Start →',
                onStart: () => mainTabIndex.value = 3,
                workoutDone: _trainedToday,
                onLogMeal: (_) => mainTabIndex.value = 1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionLabel(
        'RECENT SCANS',
        trailing: 'See all',
        onTrailingTap: _showAllActivity,
      ),
      const SizedBox(height: 8),
      _recentScans(),
      const SizedBox(height: 24),
    ];

    return RefreshIndicator(
      color: kLime,
      backgroundColor: kBgCard,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: sections
            .animate(interval: 60.ms)
            .fadeIn(duration: 200.ms)
            .slideY(begin: 0.05, end: 0, duration: 250.ms),
      ),
    );
  }

  Widget _header() {
    final now = DateTime.now();
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final dateLabel =
        '${days[now.weekday - 1]} · ${months[now.month - 1]} ${now.day}';

    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    // Avatar initial only — the email itself no longer appears in the
    // greeting.
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final avatarInitial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    final streakCount = (_streak?['current_streak'] as num?)?.toInt() ?? 0;
    // activity_today is a list of activity kinds (["workout", "meal"]).
    final keptToday = ((_streak?['activity_today'] as List?) ?? []).isNotEmpty;
    final atRisk = _streak?['streak_at_risk'] == true && streakCount > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel, style: kLabelSmall.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                greeting,
                style: kHeadlineMedium.copyWith(fontSize: 26),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (streakCount > 0) ...[
              StreakChip(
                count: streakCount,
                isKeptToday: keptToday,
                atRisk: atRisk,
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  )
                  // Goal/weight/age edits in Profile change readiness math,
                  // the trend goal badge and calorie/protein targets — reload
                  // on return since TODAY stays mounted under the push.
                  .then((_) => _load()),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kBgCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorder),
                ),
                alignment: Alignment.center,
                child: Text(
                  avatarInitial,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recentScans() {
    final meals = ((_dash?['recent_meals'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final scans = ((_dash?['recent_scans'] as List?) ?? [])
        .cast<Map<String, dynamic>>();

    if (meals.isEmpty && scans.isEmpty) {
      return Container(
        height: 92,
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => mainTabIndex.value = 1,
          child: Text(
            'No scans yet — scan your first meal in the SCAN tab →',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ),
      );
    }

    final thumbs = <Widget>[
      for (final m in meals)
        RecentScanThumb(
          title: (m['food_name'] as String?) ?? 'Meal',
          subtitle: '${_num(m['calories']).round()} kcal',
          tag: 'meal',
          onTap: () => _showMealDetail(m),
        ),
      for (final s in scans)
        RecentScanThumb(
          title: 'Scan #${(s['number'] as num?)?.toInt() ?? 1}',
          subtitle: '${_num(s['body_fat']).toStringAsFixed(1)}% BF',
          tag: 'body',
          onTap: () => mainTabIndex.value = 2,
        ),
    ];

    // A Row inside a horizontal scroller instead of a fixed-height ListView:
    // the strip then measures itself against the tallest card, so it can't
    // clip the subtitle the way a hard-coded 92 did at larger font sizes.
    // IntrinsicHeight keeps the cards a uniform height.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < thumbs.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              thumbs[i],
            ],
          ],
        ),
      ),
    );
  }

  // ── Recent-activity sheets ─────────────────────────────────────────────────

  String _formatTime(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  /// Meal macro stats — no photo (none is stored), just the numbers.
  void _showMealDetail(Map<String, dynamic> meal) {
    final cal = _num(meal['calories']);
    final protein = _num(meal['protein_g']);
    final carbs = _num(meal['carbs_g']);
    final fat = _num(meal['fat_g']);
    final serving = meal['serving_size'] as String?;
    final time = _formatTime(meal['created_at'] as String?);
    final date = _formatDate(meal['created_at'] as String?);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kBgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                (meal['food_name'] as String?) ?? 'Meal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (date.isNotEmpty && time.isNotEmpty) '$date · $time',
                  if (serving != null && serving.isNotEmpty) serving,
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${cal.round()}', style: kStatMedium),
                  const SizedBox(width: 4),
                  Text('kcal', style: kStatCaption),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _macroTile('PROTEIN', protein, kLime),
                  const SizedBox(width: 10),
                  _macroTile('CARBS', carbs, kCyan),
                  const SizedBox(width: 10),
                  _macroTile('FAT', fat, kOrange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroTile(String label, double grams, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: kBgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${grams.round()}g',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: kLabelSmall.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  /// Full recent-activity list (all logged meals + all physique scans) in a
  /// scrollable sheet, instead of only the 3-meal/2-scan dashboard preview.
  void _showAllActivity() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kBgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => FutureBuilder<List<List<Map<String, dynamic>>>>(
          // Cache-first: a reopen of this sheet is instant unless a write
          // has invalidated the cache (new meal/scan logged elsewhere).
          future: (TodayCache.meals != null && TodayCache.scans != null)
              ? Future.value([TodayCache.meals!, TodayCache.scans!])
              : Future.wait([getCalorieLogs(), getPhysiqueScans()]).then((r) {
                  TodayCache.meals = r[0];
                  TodayCache.scans = r[1];
                  return r;
                }),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: kLime),
                ),
              );
            }
            final meals = snap.data![0];
            final scans = snap.data![1].reversed.toList(); // newest first
            final rows =
                <Map<String, dynamic>>[
                  for (final m in meals) {...m, '_kind': 'meal'},
                  for (final s in scans) {...s, '_kind': 'scan'},
                ]..sort(
                  (a, b) => (b['created_at'] as String? ?? '').compareTo(
                    a['created_at'] as String? ?? '',
                  ),
                );

            if (rows.isEmpty) {
              return Center(
                child: Text(
                  'No activity logged yet',
                  style: TextStyle(color: kTextMuted),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: kBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [Text('ALL ACTIVITY', style: kLabelSmall)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: kBorder, height: 1),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final isMeal = r['_kind'] == 'meal';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isMeal
                                ? Icons.restaurant_rounded
                                : Icons.camera_alt_rounded,
                            color: isMeal ? kLime : kPink,
                            size: 20,
                          ),
                          title: Text(
                            isMeal
                                ? ((r['food_name'] as String?) ?? 'Meal')
                                : 'Physique scan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            isMeal
                                ? '${_num(r['calories']).round()} kcal · '
                                      '${_formatDate(r['created_at'] as String?)}'
                                : '${(r['overall_score'] as num?)?.toInt() ?? '—'}/100 · '
                                      '${_formatDate(r['created_at'] as String?)}',
                            style: TextStyle(fontSize: 12, color: kTextMuted),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: kTextMuted,
                          ),
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            if (isMeal) {
                              _showMealDetail(r);
                            } else {
                              mainTabIndex.value = 2;
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _skeleton() {
    Widget line(double w, double h) => ShimmerBox(width: w, height: h);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(90, 12),
                const SizedBox(height: 8),
                line(200, 24),
              ],
            ),
            const ShimmerBox(width: 36, height: 36, borderRadius: 18),
          ],
        ),
        const SizedBox(height: 16),
        line(double.infinity, 210),
        const SizedBox(height: 12),
        line(double.infinity, 260),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: line(double.infinity, 140)),
            const SizedBox(width: 12),
            Expanded(child: line(double.infinity, 140)),
          ],
        ),
        const SizedBox(height: 16),
        line(120, 12),
        const SizedBox(height: 8),
        Row(
          children: [line(140, 84), const SizedBox(width: 12), line(140, 84)],
        ),
      ],
    );
  }
}
