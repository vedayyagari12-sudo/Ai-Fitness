import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../api_service.dart';
import '../../services/nav_service.dart';
import '../../utils/units.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../utils/snackbar.dart';
import '../workouts/segmented_bar.dart';

/// BODY tab — "Your composition": physique scan results, muscle development,
/// body-fat trend, metric history and the full scan list.
class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _MuscleScore {
  _MuscleScore(this.name, this.score, {required this.fromScan});
  final String name;
  final double score; // 0–10 (scan scale)
  final bool fromScan; // false = derived from training volume, no scan
  bool lag = false; // genuinely weak (<7) — plans add volume here
  bool maintain = false; // lowest of a strong set — keep doing what works
  Color color = kGreen;
}

class _BodyScreenState extends State<BodyScreen> {
  List<Map<String, dynamic>> _scans = [];
  List<Map<String, dynamic>> _bodyweight = [];
  Map<String, dynamic>? _muscle;
  String _goal = 'maintain';
  bool _loading = true;
  int _metricTab = 0; // 0 BODY FAT, 1 WEIGHT, 2 SCORE
  int? _expandedScan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      getPhysiqueScans(),
      getBodyweightHistory(),
      getMuscleBalance(),
      getUserProfile(),
    ]);
    if (!mounted) return;
    setState(() {
      _scans = results[0] as List<Map<String, dynamic>>;
      _bodyweight = results[1] as List<Map<String, dynamic>>;
      _muscle = results[2] as Map<String, dynamic>?;
      _goal =
          ((results[3] as Map<String, dynamic>?)?['goal'] as String?) ??
          'maintain';
      _loading = false;
    });
  }

  // ── Derived data ────────────────────────────────────────────────────────────

  Map<String, dynamic>? get _latest => _scans.isEmpty ? null : _scans.last;
  Map<String, dynamic>? get _previous =>
      _scans.length < 2 ? null : _scans[_scans.length - 2];

  double? _bf(Map<String, dynamic>? scan) {
    final raw = scan?['body_fat_estimate'];
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw.toString());
    return match != null ? double.parse(match.group(1)!) : null;
  }

  int? _score(Map<String, dynamic>? scan) =>
      (scan?['overall_score'] as num?)?.toInt();

  static const _muscleKeys = [
    ('Chest', 'chest_score'),
    ('Back', 'back_score'),
    ('Shoulders', 'shoulders_score'),
    ('Arms', 'arms_score'),
    ('Legs', 'legs_score'),
    ('Core', 'core_score'),
  ];

  bool get _hasScanScores =>
      _latest != null && _muscleKeys.any((k) => _latest![k.$2] != null);

  /// Muscle development from the latest scan, scored 0-10 per muscle.
  /// Colors are ABSOLUTE (same scale as the color key and muscle map):
  /// green 7+, gold 5-6.9, pink below 5 — so a "best" muscle that is still
  /// objectively weak reads as weak. Falls back to 30-day training-volume
  /// balance (relative, neutral color) when there's no scan.
  List<_MuscleScore> get _muscleScores {
    final scan = _latest;
    List<_MuscleScore> list;
    if (_hasScanScores) {
      list = [
        for (final (name, key) in _muscleKeys)
          if (scan![key] != null)
            _MuscleScore(name, (scan[key] as num).toDouble(), fromScan: true),
      ];
      for (final m in list) {
        m.color = m.score >= 7
            ? kGreen
            : m.score >= 5
            ? kGold
            : kPink;
      }
    } else {
      final groups = _muscle?['groups'] as Map<String, dynamic>? ?? {};
      if (groups.isEmpty) return const [];
      final maxV = groups.values
          .map((v) => (v as num).toDouble())
          .fold(0.0, (a, b) => a > b ? a : b);
      list = [
        for (final e in groups.entries)
          _MuscleScore(
            _titleCase(e.key),
            maxV > 0 ? (e.value as num) / maxV * 10 : 0,
            fromScan: false,
          )..color = kCyan,
      ];
    }
    if (list.isEmpty) return list;
    list.sort((a, b) => b.score.compareTo(a.score));
    // A muscle is only a FOCUS area when it's genuinely weak (score < 7).
    // Being someone's relatively-lowest muscle at 8/10 is a strength to
    // maintain, not a lag — cap at the two weakest so plans stay focused.
    var flagged = 0;
    for (var i = list.length - 1; i >= 0 && flagged < 2; i--) {
      if (list[i].score < 7) {
        list[i].lag = true;
        flagged++;
      } else if (i >= list.length - 2 && list.length > 2) {
        // Relatively-lowest but objectively strong — maintain, don't "fix".
        list[i].maintain = true;
      }
    }
    return list;
  }

  List<String> get _laggingNames =>
      _muscleScores.where((m) => m.lag).map((m) => m.name).toList();

  String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _dateLabel(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
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
    return '${months[d.month - 1]} ${d.day}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        accent: kPink,
        accent2: kGold,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            color: kPink,
            backgroundColor: kBgCard,
            child: _loading ? _skeleton() : _content(),
          ),
        ),
      ),
    );
  }

  Widget _skeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + navBarClearance(context)),
      children: [
        const ShimmerBox(width: 160, height: 14, borderRadius: 6),
        const SizedBox(height: 12),
        const ShimmerBox(width: 220, height: 30, borderRadius: 8),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: ShimmerBox(
                width: double.infinity,
                height: 200,
                borderRadius: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ShimmerBox(
                      width: double.infinity,
                      height: 58,
                      borderRadius: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const ShimmerBox(width: double.infinity, height: 240, borderRadius: 18),
      ],
    );
  }

  Widget _content() {
    final bf = _bf(_latest);
    final prevBf = _bf(_previous);
    final bfChange = (bf != null && prevBf != null) ? bf - prevBf : 0.0;

    final weightKg = _bodyweight.isNotEmpty
        ? ((_bodyweight.last['weight_kg'] as num?)?.toDouble() ?? 0)
        : 0.0;
    final prevWeightKg = _bodyweight.length >= 2
        ? ((_bodyweight[_bodyweight.length - 2]['weight_kg'] as num?)
                  ?.toDouble() ??
              weightKg)
        : weightKg;
    final weightLb = weightKg * 2.20462;
    final weightChgLb = (weightKg - prevWeightKg) * 2.20462;
    final leanLb = bf != null ? weightLb * (1 - bf / 100) : 0.0;
    final leanChgLb = bf != null ? weightChgLb * (1 - bf / 100) : 0.0;

    final sections = <Widget>[
      _header(),
      const SizedBox(height: 18),
      if (_scans.isEmpty && _bodyweight.isEmpty)
        _emptyState()
      else ...[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _MuscleMapCard(
                  scores: {
                    for (final (name, key) in _muscleKeys)
                      name.toLowerCase(): (_latest?[key] as num?)?.toDouble(),
                  },
                  scanDate: _latest != null
                      ? _dateLabel(_latest!['created_at'] as String?)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _statCard(
                      'BODY FAT',
                      bf != null ? '${bf.toStringAsFixed(1)}%' : '—',
                      bfChange,
                      'pct',
                      favorableWhenDown: true,
                      valueColor: kPink,
                    ),
                    const SizedBox(height: 12),
                    _statCard(
                      'LEAN MASS',
                      leanLb > 0 ? '${leanLb.toStringAsFixed(0)}lb' : '—',
                      leanChgLb,
                      'lb',
                      valueColor: kBlue,
                    ),
                    const SizedBox(height: 12),
                    _statCard(
                      'WEIGHT · TAP TO LOG',
                      weightLb > 0 ? '${weightLb.toStringAsFixed(0)}lb' : '—',
                      weightChgLb,
                      'lb',
                      neutral: true,
                      onTap: _logWeightSheet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _scoreKey(),
        const SizedBox(height: 12),
        _muscleCard(),
        const SizedBox(height: 16),
        _muscleChangeCard(),
        if (_laggingNames.isNotEmpty) ...[
          const SizedBox(height: 16),
          _focusCta(),
        ],
        const SizedBox(height: 16),
        _metricsCard(),
        if (_scans.isNotEmpty) ...[const SizedBox(height: 16), _historyCard()],
      ],
      const SizedBox(height: 28),
      Center(
        child: Text(
          'For fitness purposes only. Not medical advice.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + navBarClearance(context)),
      children: [
        for (var i = 0; i < sections.length; i++)
          sections[i]
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

  Widget _header() {
    final scanNo = _scans.length;
    final latestDate = _latest != null
        ? _dateLabel(_latest!['created_at'] as String?)
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scanNo > 0 ? 'PHYSIQUE SCAN · #$scanNo' : 'YOUR BODY',
                style: kLabelSmall.copyWith(color: kPink, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                'Your composition',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        if (latestDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              latestDate,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.accessibility_new_rounded,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No physique scans yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Take your first scan in the SCAN tab to see your composition, '
            'muscle balance and trends here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => mainTabIndex.value = 1,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPink,
              foregroundColor: Colors.black,
            ),
            child: const Text('Scan now'),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet to log today's bodyweight in lbs — the database keeps kg,
  /// so we convert on save. Feeds the WEIGHT trend charts.
  Future<void> _logWeightSheet() async {
    final lastKg = _bodyweight.isNotEmpty
        ? (_bodyweight.last['weight_kg'] as num?)?.toDouble()
        : null;
    final ctrl = TextEditingController(
      text: lastKg != null ? lbsLabel(kgToLbs(lastKg)) : '',
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("TODAY'S BODYWEIGHT", style: kLabelSmall),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(suffixText: 'lbs'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save weight'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final lbs = double.tryParse(ctrl.text);
    if (lbs == null || lbs <= 0) {
      AppSnackbar.error(context, 'Enter a valid weight');
      return;
    }
    final kg = lbsToKg(lbs);
    final resp = await logBodyweight(kg);
    if (!mounted) return;
    if (resp != null && resp['error'] == null) {
      AppSnackbar.success(context, 'Weight logged');
      // Keep the profile's weight (used for TDEE / calorie & protein
      // targets) in sync with the latest logged bodyweight — otherwise it
      // silently goes stale the moment someone stops hand-editing Profile.
      unawaited(upsertUserProfile({'weight_kg': kg}));
      triggerTodayRefresh();
      _load();
    } else {
      AppSnackbar.error(context, 'Could not save weight — try again');
    }
  }

  Widget _statCard(
    String label,
    String value,
    double change,
    String unit, {
    bool favorableWhenDown = false,
    bool neutral = false,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final down = change < 0;
    final favorable = neutral ? false : (favorableWhenDown ? down : !down);
    final deltaColor = neutral
        ? AppColors.textMuted
        : (favorable ? kGreen : kPink);
    final arrow = neutral || change == 0 ? '' : (down ? '▼ ' : '▲ ');
    final mag = change.abs();
    final deltaStr = change == 0
        ? '—'
        : unit == 'pct'
        ? '${mag.toStringAsFixed(1)}%'
        : '${change >= 0 ? '+' : '-'}${mag.toStringAsFixed(1)} lb';

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kLabelSmall.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Flexible + scale-down keeps the delta from overflowing
              // the narrow card on small phone widths.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$arrow$deltaStr',
                    style: TextStyle(
                      color: deltaColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'vs last',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }

  /// Color key for the muscle map and development bars.
  Widget _scoreKey() {
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          children: [
            item(kGreen, 'Strong (7+)'),
            const SizedBox(width: 14),
            item(kGold, 'Medium (5–6.9)'),
            const SizedBox(width: 14),
            item(kPink, 'Lagging (<5)'),
            const SizedBox(width: 14),
            item(kFillMuted, 'Not scanned'),
          ],
        ),
      ),
    );
  }

  Widget _muscleCard() {
    final scores = _muscleScores;
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
          Text('MUSCLE DEVELOPMENT', style: kLabelSmall),
          const SizedBox(height: 4),
          Text(
            _hasScanScores
                ? 'Each muscle is scored 0–10 by your latest physique scan. '
                      'Your overall score (/100) is roughly their average ×10.'
                : 'No scan yet — this shows how your last 30 days of '
                      'training volume is balanced across muscle groups.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (scores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Scan your physique or log a few workouts to map your '
                'muscle development.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            ...scores.map(_muscleRow),
        ],
      ),
    );
  }

  Widget _muscleRow(_MuscleScore m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            // Wide enough for the longest name plus a MAINTAIN chip at the
            // larger type sizes.
            width: 132,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (m.lag || m.maintain) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: (m.lag ? kPink : kGreen).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      m.lag ? 'FOCUS' : 'MAINTAIN',
                      style: TextStyle(
                        color: m.lag ? kPink : kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (m.score / 10).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: kFillSubtle,
                  valueColor: AlwaysStoppedAnimation<Color>(m.color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(
              m.fromScan
                  ? '${m.score.round()}/10'
                  : '${(m.score * 10).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Per-muscle score change between the two most recent scans. Higher
  /// training value than a second body-fat chart (body fat already has its
  /// own tab in the metrics card below) — this shows exactly which muscle
  /// groups are actually improving vs stalling, so training focus can
  /// follow the data instead of a hunch.
  Widget _muscleChangeCard() {
    final prev = _previous;
    final latest = _latest;
    final deltas = <(String, double)>[
      if (prev != null && latest != null)
        for (final (name, key) in _muscleKeys)
          if (latest[key] != null && prev[key] != null)
            (
              name,
              (latest[key] as num).toDouble() - (prev[key] as num).toDouble(),
            ),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

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
          Text('MUSCLE CHANGE · LAST TWO SCANS', style: kLabelSmall),
          const SizedBox(height: 14),
          if (deltas.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  _scans.length < 2
                      ? 'Scan again to see which muscles are improving'
                      : "Your last two scans don't share scored muscle "
                            'groups to compare',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            for (final (name, delta) in deltas) _muscleChangeRow(name, delta),
        ],
      ),
    );
  }

  Widget _muscleChangeRow(String name, double delta) {
    final flat = delta == 0;
    final improved = delta > 0;
    final color = flat ? AppColors.textMuted : (improved ? kGreen : kPink);
    // A ±3-point swing between two scans is a big move — normalize against
    // that so the bar has visible range without needing a fixed axis.
    final magnitude = (delta.abs() / 3.0).clamp(0.04, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: kBgHighlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: magnitude,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(
              flat ? '—' : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _focusCta() {
    final names = _laggingNames.map((n) => n.toLowerCase()).join(' & ');
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
                    '${_laggingNames.length} FOCUS AREAS FOUND',
                    style: kLabelSmall.copyWith(color: kPink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your $names are lagging — we built a plan.',
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
              decoration: const BoxDecoration(
                color: kPink,
                shape: BoxShape.circle,
              ),
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

  // ── Metrics over time ──────────────────────────────────────────────────────

  Widget _metricsCard() {
    final bfSeries = <(String, double)>[
      for (final s in _scans)
        if (_bf(s) != null) (_dateLabel(s['created_at'] as String?), _bf(s)!),
    ];
    final weightSeries = <(String, double)>[
      for (final w in _bodyweight)
        (
          _dateLabel(w['created_at'] as String?),
          kgToLbs((w['weight_kg'] as num?) ?? 0),
        ),
    ];
    final scoreSeries = <(String, double)>[
      for (final s in _scans)
        if (_score(s) != null)
          (_dateLabel(s['created_at'] as String?), _score(s)!.toDouble()),
    ];

    final emptyHint = switch (_metricTab) {
      1 =>
        'Tap the WEIGHT card above to log your bodyweight — '
            'two entries start the trend',
      2 => 'Scan again to track your score over time',
      _ => 'Scan again to track body fat over time',
    };

    final series = switch (_metricTab) {
      1 => weightSeries,
      2 => scoreSeries,
      _ => bfSeries,
    };

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('BODY METRICS OVER TIME', style: kLabelSmall),
          ),
          SegmentedBar(
            labels: const ['BODY FAT', 'WEIGHT', 'SCORE'],
            index: _metricTab,
            onChanged: (i) => setState(() => _metricTab = i),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: series.length < 2
                ? SizedBox(
                    height: 140,
                    child: Center(
                      child: Text(
                        emptyHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                : switch (_metricTab) {
                    1 => _weightMetric(weightSeries),
                    2 => _scoreMetric(scoreSeries),
                    _ => _bfMetric(bfSeries),
                  },
          ),
        ],
      ),
    );
  }

  /// Headline + takeaway + chart, shared frame for the three metric tabs.
  Widget _metricBody({
    required String headline,
    required String takeaway,
    required Color takeawayColor,
    required Widget chart,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            headline,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          takeaway,
          style: TextStyle(
            color: takeawayColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // Matches the dashboard trend charts — these carry always-on value
        // labels, which at 130 left the plot itself looking squeezed.
        SizedBox(height: 165, child: chart),
      ],
    );
  }

  Widget _bfMetric(List<(String, double)> series) {
    final change = series.last.$2 - series.first.$2;
    return _metricBody(
      headline: 'Now ${series.last.$2.toStringAsFixed(1)}% body fat',
      takeaway:
          '${change <= 0 ? '' : '+'}${change.toStringAsFixed(1)}% since your '
          'first scan${change <= 0 ? ' — moving the right way' : ''}',
      takeawayColor: change <= 0 ? kGreen : kPink,
      chart: _metricLine(series, kPink, '%'),
    );
  }

  Widget _weightMetric(List<(String, double)> series) {
    final change = series.last.$2 - series.first.$2;
    final g = _goal.toLowerCase();
    final gaining = change > 0;
    final matchesGoal = g.contains('bulk') || g.contains('muscle')
        ? gaining
        : g.contains('cut') || g.contains('lose')
        ? !gaining
        : true;
    return _metricBody(
      headline:
          'Started ${series.first.$2.toStringAsFixed(1)} · '
          'Now ${series.last.$2.toStringAsFixed(1)} lbs',
      takeaway:
          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} lbs '
          '(last 30 days)'
          '${change.abs() < 0.05
              ? ''
              : matchesGoal
              ? ' — on track for your goal'
              : ' — opposite of your goal'}',
      takeawayColor: change.abs() < 0.05
          ? kCyan
          : (matchesGoal ? kGreen : kPink),
      chart: _metricLine(
        series,
        change.abs() < 0.05 ? kCyan : (matchesGoal ? kGreen : kPink),
        ' lbs',
      ),
    );
  }

  Widget _scoreMetric(List<(String, double)> series) {
    final change = (series.last.$2 - series.first.$2).round();
    return _metricBody(
      headline: 'Latest score ${series.last.$2.round()}/100',
      takeaway:
          '${change >= 0 ? '+' : ''}$change vs your first scan across '
          '${series.length} scans',
      takeawayColor: change >= 0 ? kGreen : kPink,
      chart: _scoreBars(series),
    );
  }

  Widget _metricLine(List<(String, double)> series, Color color, String unit) {
    final values = series.map((e) => e.$2).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.25 + 0.3;

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 3 + 0.001),
          getDrawingHorizontalLine: (v) =>
              FlLine(color: kGridline, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        // Values stay on the chart — no tap-and-hold needed.
        lineTouchData: LineTouchData(
          enabled: false,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 4,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${s.y.toStringAsFixed(1)}$unit',
                  TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        showingTooltipIndicators: [
          for (final i in _labelIndices(values.length))
            ShowingTooltipIndicators([
              LineBarSpot(
                _metricBar(values, color),
                0,
                FlSpot(i.toDouble(), values[i]),
              ),
            ]),
        ],
        lineBarsData: [_metricBar(values, color)],
      ),
    );
  }

  LineChartBarData _metricBar(List<double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.20), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  /// Which points get a permanent value label — all of them when the series
  /// is short, otherwise a readable subset that always includes the latest.
  List<int> _labelIndices(int count) {
    if (count <= 0) return const [];
    if (count <= 6) return [for (var i = 0; i < count; i++) i];
    const wanted = 5;
    final step = (count - 1) / (wanted - 1);
    final set = <int>{};
    for (var k = 0; k < wanted; k++) {
      set.add((k * step).round().clamp(0, count - 1));
    }
    set.add(count - 1);
    final list = set.toList()..sort();
    return list;
  }

  /// Physique score as bars — one per scan, latest highlighted.
  Widget _scoreBars(List<(String, double)> series) {
    final maxVal = series.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        // Headroom for the always-on value labels.
        maxY: (maxVal * 1.35).clamp(10, 130).toDouble(),
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 2,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${rod.toY.round()}',
              TextStyle(
                color: group.x == series.length - 1
                    ? kLime
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: const [0],
              barRods: [
                BarChartRodData(
                  toY: series[i].$2,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  color: i == series.length - 1
                      ? kLime
                      : kLime.withValues(alpha: 0.4),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Scan history ───────────────────────────────────────────────────────────

  Widget _historyCard() {
    final newestFirst = _scans.reversed.toList();
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
          Text('SCAN HISTORY', style: kLabelSmall),
          const SizedBox(height: 6),
          for (var i = 0; i < newestFirst.length; i++) ...[
            _historyRow(newestFirst[i], _scans.length - i, i),
            if (i != newestFirst.length - 1)
              Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> scan, int number, int index) {
    final expanded = _expandedScan == index;
    final bf = _bf(scan);
    final score = _score(scan);

    return Dismissible(
      key: ValueKey('scan_${scan['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.danger.withValues(alpha: 0.85),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDeleteScan(scan, number),
      onDismissed: (_) {
        setState(() {
          _scans.removeWhere((s) => s['id'] == scan['id']);
          _expandedScan = null;
        });
      },
      child: InkWell(
        onTap: () => setState(() => _expandedScan = expanded ? null : index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Scan #$number',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _dateLabel(scan['created_at'] as String?),
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  if (score != null)
                    Text(
                      '$score/100',
                      style: const TextStyle(
                        color: kLime,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (bf != null)
                    Text(
                      '${bf.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: kPink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: expanded ? _scanDetails(scan) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scanDetails(Map<String, dynamic> scan) {
    final scores = [
      for (final (name, key) in _muscleKeys)
        if (scan[key] != null) (name, (scan[key] as num).toDouble()),
    ];
    final strengths = ((scan['strengths'] as List?) ?? []).cast<String>();
    final weaknesses = ((scan['weaknesses'] as List?) ?? []).cast<String>();

    Color barColor(double v) => v >= 7
        ? kGreen
        : v >= 5
        ? kGold
        : kPink;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, v) in scores)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      name,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v / 10,
                        minHeight: 4,
                        backgroundColor: kFillSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor(v)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    v.toStringAsFixed(0),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (strengths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '+ ${strengths.join(' · ')}',
              style: const TextStyle(color: kGreen, fontSize: 11),
            ),
          ],
          if (weaknesses.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '– ${weaknesses.join(' · ')}',
              style: const TextStyle(color: kPink, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteScan(Map<String, dynamic> scan, int number) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delete Scan #$number?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This scan and its scores will be removed permanently.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return false;

    final ok = await deletePhysiqueScan('${scan['id']}');
    if (!mounted) return false;
    if (ok) {
      AppSnackbar.success(context, 'Scan deleted');
      return true;
    }
    AppSnackbar.error(context, 'Could not delete — try again');
    return false;
  }
}

/// Muscle map — a simple front-body silhouette with each region tinted by
/// its latest scan score (green = strong, gold = medium, red = lagging,
/// grey = not assessed). Replaces the old empty "body render" placeholder.
class _MuscleMapCard extends StatelessWidget {
  const _MuscleMapCard({required this.scores, this.scanDate});

  /// Scores 0-10 keyed by: chest, back, shoulders, arms, legs, core.
  final Map<String, double?> scores;
  final String? scanDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scanDate != null ? 'MUSCLE MAP · $scanDate' : 'MUSCLE MAP',
            style: kLabelSmall.copyWith(fontSize: 8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.55,
                child: CustomPaint(painter: _MuscleMapPainter(scores: scores)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter({required this.scores})
    : _brightness = AppColors.brightness;

  final Map<String, double?> scores;

  /// Captured so a light/dark flip repaints — every color below is
  /// theme-derived, but `scores` alone wouldn't signal the change.
  final Brightness _brightness;

  Color _tint(String region, [double alpha = 0.8]) {
    final v = scores[region];
    if (v == null) return kBodyUnscored;
    final hue = v >= 7
        ? kGreen
        : v >= 5
        ? kGold
        : kPink;
    // Blend onto the card instead of leaving the fill translucent — over a
    // white surface a 0.8-alpha tint (kGold especially) washes out badly.
    return Color.alphaBlend(hue.withValues(alpha: alpha), kBgCard);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Paint fill(String region, [double alpha = 0.8]) =>
        Paint()..color = _tint(region, alpha);
    final neutral = Paint()..color = kBodyNeutral;
    // Contour on every shape — this is what keeps the silhouette readable
    // when a region is unscored or its fill is low-contrast in light mode.
    final contour = Paint()
      ..color = kBodyContour
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final divider = Paint()
      ..color = kBodyContour
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    RRect rr(double l, double t, double r, double b, [double rad = 8]) =>
        RRect.fromLTRBR(l * w, t * h, r * w, b * h, Radius.circular(rad));
    Offset o(double x, double y) => Offset(x * w, y * h);

    // ── Head & neck (neutral) ─────────────────────────────────────────
    final head = Rect.fromCenter(
      center: o(0.5, 0.055),
      width: 0.13 * w,
      height: 0.09 * h,
    );
    canvas.drawOval(head, neutral);
    canvas.drawOval(head, contour);
    final neck = rr(0.455, 0.09, 0.545, 0.125, 3);
    canvas.drawRRect(neck, neutral);
    canvas.drawRRect(neck, contour);

    // ── Traps (back score) — sloping band from neck to shoulders ─────
    final traps = Path()
      ..moveTo(0.36 * w, 0.165 * h)
      ..lineTo(0.455 * w, 0.125 * h)
      ..lineTo(0.545 * w, 0.125 * h)
      ..lineTo(0.64 * w, 0.165 * h)
      ..close();
    canvas.drawPath(traps, fill('back'));
    canvas.drawPath(traps, contour);

    // ── Delts (shoulders) — rounded caps ──────────────────────────────
    for (final dx in [0.265, 0.735]) {
      final delt = Rect.fromCenter(
        center: o(dx, 0.185),
        width: 0.15 * w,
        height: 0.07 * h,
      );
      canvas.drawOval(delt, fill('shoulders'));
      canvas.drawOval(delt, contour);
    }

    // ── Chest — two pecs with a sternum line ─────────────────────────
    for (final pec in [
      rr(0.335, 0.165, 0.495, 0.30, 10),
      rr(0.505, 0.165, 0.665, 0.30, 10),
    ]) {
      canvas.drawRRect(pec, fill('chest'));
      canvas.drawRRect(pec, contour);
    }

    // ── Core — abs block with segment lines ──────────────────────────
    final core = rr(0.36, 0.315, 0.64, 0.50, 9);
    canvas.drawRRect(core, fill('core'));
    canvas.drawRRect(core, contour);
    canvas.drawLine(o(0.5, 0.325), o(0.5, 0.49), divider);
    canvas.drawLine(o(0.375, 0.375), o(0.625, 0.375), divider);
    canvas.drawLine(o(0.375, 0.435), o(0.625, 0.435), divider);

    // ── Arms — upper arm + forearm with an elbow break, angled out ───
    void arm(bool left) {
      final sign = left ? -1.0 : 1.0;
      final sx = 0.5 + sign * 0.235;
      // Upper arm (biceps)
      final upper = Path()
        ..moveTo((sx - 0.045) * w, 0.215 * h)
        ..lineTo((sx + 0.045) * w, 0.215 * h)
        ..lineTo((sx + sign * 0.03 + 0.04) * w, 0.36 * h)
        ..lineTo((sx + sign * 0.03 - 0.04) * w, 0.36 * h)
        ..close();
      canvas.drawPath(upper, fill('arms'));
      canvas.drawPath(upper, contour);
      // Forearm — slightly narrower, lighter tint for depth
      final fx = sx + sign * 0.035;
      final fore = Path()
        ..moveTo((fx - 0.033) * w, 0.375 * h)
        ..lineTo((fx + 0.033) * w, 0.375 * h)
        ..lineTo((fx + sign * 0.02 + 0.025) * w, 0.52 * h)
        ..lineTo((fx + sign * 0.02 - 0.025) * w, 0.52 * h)
        ..close();
      canvas.drawPath(fore, fill('arms', 0.55));
      canvas.drawPath(fore, contour);
    }

    arm(true);
    arm(false);

    // ── Legs — quads + calves with a knee break ──────────────────────
    void leg(bool left) {
      final sign = left ? -1.0 : 1.0;
      final cx = 0.5 + sign * 0.075;
      // Quad — tapers toward the knee
      final quad = Path()
        ..moveTo((cx - 0.07) * w, 0.515 * h)
        ..lineTo((cx + 0.07) * w, 0.515 * h)
        ..lineTo((cx + 0.05) * w, 0.735 * h)
        ..lineTo((cx - 0.05) * w, 0.735 * h)
        ..close();
      canvas.drawPath(quad, fill('legs'));
      canvas.drawPath(quad, contour);
      // Calf — smaller, lighter for depth
      final calf = Path()
        ..moveTo((cx - 0.045) * w, 0.755 * h)
        ..lineTo((cx + 0.045) * w, 0.755 * h)
        ..lineTo((cx + 0.03) * w, 0.955 * h)
        ..lineTo((cx - 0.03) * w, 0.955 * h)
        ..close();
      canvas.drawPath(calf, fill('legs', 0.55));
      canvas.drawPath(calf, contour);
    }

    leg(true);
    leg(false);
  }

  @override
  bool shouldRepaint(_MuscleMapPainter old) =>
      old.scores != scores || old._brightness != _brightness;
}
