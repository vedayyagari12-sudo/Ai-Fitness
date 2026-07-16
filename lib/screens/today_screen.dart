import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api_service.dart';
import '../models/readiness_data.dart';
import '../services/nav_service.dart';
import '../services/split_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../utils/units.dart';
import '../widgets/physique_mini_card.dart';
import '../widgets/readiness_card.dart';
import '../widgets/recent_scan_thumb.dart';
import '../widgets/section_label.dart';
import '../widgets/streak_chip.dart';
import '../widgets/today_session_card.dart';
import '../widgets/trend_card.dart';
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
  TrainingSplit _split = TrainingSplit.auto;

  @override
  void initState() {
    super.initState();
    todayTick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    todayTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      getDashboard(),
      getStreak(),
      getWeeklySummary(),
    ]);
    final split = await SplitService.getSplit();
    if (!mounted) return;
    setState(() {
      _dash = results[0] as Map<String, dynamic>?;
      _streak = results[1] as Map<String, dynamic>?;
      _weeklySummary = (results[2] as List).cast<Map<String, dynamic>>();
      _split = split;
      _loading = false;
    });
  }

  // ── Derived data ────────────────────────────────────────────────────────────

  Map<String, dynamic> get _stats =>
      (_dash?['today_stats'] as Map<String, dynamic>?) ?? {};

  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  String get _goal => (_dash?['goal'] as String?) ?? 'maintain';

  ReadinessData get _readiness {
    final weeklyGoal = ((_dash?['weekly_goal'] as num?)?.toInt() ?? 4).clamp(1, 7);
    final sessions = (_dash?['sessions_this_week'] as num?)?.toInt() ?? 0;
    final weekProgress = (sessions / weeklyGoal).clamp(0.0, 1.0);

    final kcal = _num(_stats['calories']);
    final kcalTarget = _num(_stats['calorie_target']);
    final fueled = kcalTarget > 0 ? (kcal / kcalTarget).clamp(0.0, 1.0) : 0.0;

    final protein = _num(_stats['protein']);
    final proteinTarget = _num(_stats['protein_target']);
    final proteinP =
        proteinTarget > 0 ? (protein / proteinTarget).clamp(0.0, 1.0) : 0.0;

    final bf = _num(_stats['body_fat']);
    final bfChange = _num(_stats['body_fat_change']);
    final volume = _num(_stats['volume']).round();

    // Readiness = blend of weekly training progress and today's fueling.
    final score = ((weekProgress * 0.6 + fueled * 0.25 + proteinP * 0.15) * 100)
        .round()
        .clamp(0, 100);

    return ReadinessData(
      score: score,
      caloriesProgress: fueled,
      proteinProgress: proteinP,
      sessionsProgress: weekProgress,
      fueledValue: '${(fueled * 100).round()}%',
      caloriesLabel: '${_formatThousands(kcal.round())} kcal',
      loadValue: '$volume',
      loadLabel: '${_sessionFocus().toLowerCase()} day',
      proteinValue: '${protein.round()}g',
      proteinTarget:
          proteinTarget > 0 ? 'of ${proteinTarget.round()}g' : 'set a goal',
      bodyFatValue: bf > 0 ? '${bf.toStringAsFixed(1)}%' : '—',
      bodyFatDelta: bfChange != 0
          ? '${bfChange > 0 ? '+' : ''}${bfChange.toStringAsFixed(1)}%'
          : '',
      trainingDetail: '$sessions of $weeklyGoal sessions this week',
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

  String _sessionName() {
    final focus = _sessionFocus();
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

  /// Daily calorie target: goal-based estimate from bodyweight
  /// (bulk ×16, cut ×12, maintain ×14 kcal per lb), falling back to the
  /// backend's TDEE when no weight is known.
  double get _calorieTarget {
    final weights = _trendValues('weight');
    final weightKg =
        weights.isNotEmpty ? weights.last : _num(_stats['weight']);
    if (weightKg > 0) {
      final lbs = kgToLbs(weightKg);
      final g = _goal.toLowerCase();
      final mult = g.contains('bulk') || g.contains('muscle')
          ? 16
          : g.contains('cut') || g.contains('lose')
              ? 12
              : 14;
      return (lbs * mult).roundToDouble();
    }
    final backend = _num(_stats['calorie_target']);
    return backend > 0 ? backend : 2200;
  }

  /// Weekly training volume in lbs lifted, oldest → newest (up to 8 weeks).
  /// Backend returns newest-first.
  List<double> get _weeklyVolume => [
        for (final w in _weeklySummary.reversed)
          (w['total_volume'] as num?)?.toDouble() ?? 0.0,
      ];

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
      body: SafeArea(
        child: _loading ? _skeleton() : _content(),
      ),
    );
  }

  Widget _content() {
    final bf = _num(_stats['body_fat']);
    final bfChange = _num(_stats['body_fat_change']);
    final hasScan = ((_dash?['recent_scans'] as List?) ?? []).isNotEmpty;

    final sections = <Widget>[
      _header(),
      const SizedBox(height: 16),
      ReadinessCard(data: _readiness),
      const SizedBox(height: 12),
      TrendCard(
        goal: _goal,
        weightLbs: [for (final kg in _trendValues('weight')) kgToLbs(kg)],
        dailyCalories: _rawTrendValues('calories'),
        dayLabels: _dayLabels,
        calorieTarget: _calorieTarget,
        weeklyVolume: _weeklyVolume,
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TodaySessionCard(
              title: _sessionName(),
              meta: '~45 min · AI generated',
              note: hasScan ? 'Tuned to your physique scan' : '',
              onStart: () => mainTabIndex.value = 3,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SectionLabel(
        'RECENT SCANS',
        trailing: 'See all',
        onTrailingTap: () => mainTabIndex.value = 2,
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
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final dateLabel =
        '${days[now.weekday - 1]} · ${months[now.month - 1]} ${now.day}';

    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final rawName = email.split('@').first;
    final name = rawName.isEmpty
        ? 'there'
        : rawName[0].toUpperCase() + rawName.substring(1);
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

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
                '$greeting, $name',
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
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
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
          child: const Text(
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
          onTap: () => mainTabIndex.value = 1,
        ),
      for (final s in scans)
        RecentScanThumb(
          title: 'Scan #${(s['number'] as num?)?.toInt() ?? 1}',
          subtitle: '${_num(s['body_fat']).toStringAsFixed(1)}% BF',
          tag: 'body',
          onTap: () => mainTabIndex.value = 2,
        ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: thumbs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => thumbs[i],
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
          children: [
            line(140, 84),
            const SizedBox(width: 12),
            line(140, 84),
          ],
        ),
      ],
    );
  }
}
