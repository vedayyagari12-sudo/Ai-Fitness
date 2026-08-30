import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../api_service.dart';
import '../../services/nav_service.dart';
import '../../utils/chart_labels.dart';
import '../../utils/chart_range.dart';
import '../../utils/muscle_focus.dart';
import '../../utils/units.dart';
import '../../utils/weight_validation.dart';
import '../../theme/app_theme.dart';
import '../../widgets/muscle_radar.dart';
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
    // Back detail — only scored when the scan had a back photo, and rows with
    // no score are skipped, so front-only scans are unaffected.
    ('Lats', 'lats_score'),
    ('Mid Back', 'mid_back_score'),
    ('Traps', 'traps_score'),
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
      // Nothing trained yet: every share would be 0, which says nothing about
      // any muscle. Show the empty state rather than a row of zeroed bars.
      if (maxV <= 0) return const [];
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

    // Scan-only by design — see focusFlags for why the volume fallback must
    // not feed this.
    final flags = focusFlags(
      scoresHighToLow: [for (final m in list) m.score],
      fromScan: _hasScanScores,
    );
    for (final i in flags.lagging) {
      list[i].lag = true;
    }
    for (final i in flags.maintain) {
      list[i].maintain = true;
    }
    return list;
  }

  List<String> get _laggingNames =>
      _muscleScores.where((m) => m.lag).map((m) => m.name).toList();

  String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Full date for the expanded scan detail — "26 August 2026".
  ///
  /// Spelled out rather than the row's abbreviated form: this has a line to
  /// itself, so there is no reason to compress it, and a scan history is
  /// read to answer "when was this" precisely.
  String _fullDateLabel(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = d.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

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
        // StatefulBuilder so the error text and the button's enabled state
        // track what is being typed; the sheet has no state of its own.
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final error = weightInputError(ctrl.text);
            final canSave = isValidWeightInput(ctrl.text);
            return Column(
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
                  // The numeric keyboard is a hint, not a restriction — a
                  // physical or third-party keyboard can still send letters.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    suffixText: 'lbs',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  // Null disables it: an out-of-range value cannot be saved
                  // rather than being rejected after the round trip.
                  onPressed: canSave ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Save weight'),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (saved != true || !mounted) return;
    // The button is gated on the same check, so this only catches a value
    // that changed after the sheet closed.
    if (!isValidWeightInput(ctrl.text)) {
      AppSnackbar.error(context, kWeightRangeMessage);
      return;
    }
    final lbs = double.parse(ctrl.text.trim());
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
      final reason = resp?['error'];
      AppSnackbar.error(
        context,
        reason is String && reason.isNotEmpty
            ? 'Could not save weight — $reason'
            : 'Could not save weight — try again',
      );
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
          else ...[
            // The web shows the shape of the imbalance; the rows below are its
            // table view, carrying the exact numbers and the focus flags a
            // shape cannot. Below three muscles there is no shape to draw and
            // the radar renders nothing, leaving the rows on their own.
            if (scores.length >= MuscleRadar.minAxes) ...[
              SizedBox(
                height: 236,
                child: MuscleRadar(
                  readings: [
                    for (final m in scores)
                      (label: _radarLabel(m.name), score: m.score),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            ...scores.map(_muscleRow),
          ],
        ],
      ),
    );
  }

  /// Axis labels have far less room than the rows below them, so the longest
  /// names get a short form rather than being ellipsised into nothing.
  static String _radarLabel(String name) {
    const short = {
      'shoulders': 'Delts',
      'hamstrings': 'Hams',
      'quadriceps': 'Quads',
      'mid back': 'Mid back',
      'lower back': 'Low back',
      'glutes': 'Glutes',
    };
    return short[name.toLowerCase()] ?? name;
  }

  Widget _muscleRow(_MuscleScore m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Proportional so every row still lines up, but a share of the
          // width rather than a fixed 132px — at larger type that clipped
          // "Shoulders" to "Sho…".
          Expanded(
            flex: 7,
            child: Row(
              children: [
                // Scaled, not ellipsised: "Shoulders" is the label's whole
                // meaning, and "Should…" tells the user nothing.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      m.name,
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
                      m.lag ? 'FOCUS' : 'OK',
                      // Chrome, not content — kept at a fixed size so it
                      // can't crowd out the muscle name it sits beside.
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: m.lag ? kPink : kGreen,
                        fontSize: 9.5,
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
            flex: 3,
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
          // Proportional rather than a fixed 74px, for the same reason as the
          // scan-detail rows: long names wrapped mid-word.
          Expanded(
            flex: 4,
            child: Text(
              name,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 6,
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

  // ── Metrics over time ──────────────────────────────────────────────────────

  Widget _metricsCard() {
    final bfSeries = <(String, double)>[
      for (final s in _scans)
        if (_bf(s) != null) (_dateLabel(s['created_at'] as String?), _bf(s)!),
    ];
    final weightSeries = <(String, double)>[
      // Skip rows with no weight rather than plotting them as 0 lbs. A null
      // became a real point that dragged the line to zero, read as a huge
      // loss in the takeaway, and counted toward the length check that
      // decides whether this is still a first weigh-in.
      for (final w in _bodyweight)
        if (w['weight_kg'] != null)
          (
            _dateLabel(w['created_at'] as String?),
            kgToLbs((w['weight_kg'] as num).toDouble()),
          ),
    ];
    final scoreSeries = <(String, double)>[
      for (final s in _scans)
        if (_score(s) != null)
          (_dateLabel(s['created_at'] as String?), _score(s)!.toDouble()),
    ];

    // Shown under a chart holding exactly one point.
    final singlePointHint = switch (_metricTab) {
      1 => kFirstWeighInHint,
      2 =>
        'That is your first score. Scan again to see how it moves over time.',
      _ =>
        'That is your first reading. Scan again to see how it moves over '
            'time.',
    };

    final emptyHint = switch (_metricTab) {
      1 => 'Tap the WEIGHT card above to log your bodyweight',
      2 => 'Scan again to track your score over time',
      _ => 'Scan again to track body fat over time',
    };

    // Charts show a recent window, not the whole history. These series grow
    // without bound (one entry per scan / per day logged), and past a few
    // dozen points the bars are thinner than their own value labels. Lines
    // hold more than bars because their labels are already thinned out.
    List<(String, double)> tail(List<(String, double)> s, int max) =>
        s.length <= max ? s : s.sublist(s.length - max);

    final series = switch (_metricTab) {
      1 => tail(weightSeries, 30),
      2 => tail(scoreSeries, 10),
      _ => tail(bfSeries, 30),
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
            // Only a genuinely empty series hides the chart. One entry still
            // draws, so its dot confirms the log or scan saved — hiding it
            // made a successful log look like nothing had happened.
            child: series.isEmpty
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
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // `series` is the windowed list. Passing the raw
                      // weightSeries/scoreSeries/bfSeries here meant the
                      // window never applied and the charts still drew the
                      // whole history.
                      switch (_metricTab) {
                        1 => _weightMetric(series),
                        2 => _scoreMetric(series),
                        _ => _bfMetric(series),
                      },
                      // Drops away at two points, where the line itself
                      // explains the chart.
                      if (series.length < 2) ChartHint(singlePointHint),
                    ],
                  ),
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
    if (series.length < 2) {
      // One reading compared against itself is 0.0%, which the general path
      // renders as "moving the right way" — progress nothing has measured.
      return _metricBody(
        headline: 'Now ${series.last.$2.toStringAsFixed(1)}% body fat',
        takeaway: 'Your first reading',
        takeawayColor: kCyan,
        chart: _metricLine(series, kPink),
      );
    }
    final change = series.last.$2 - series.first.$2;
    return _metricBody(
      headline: 'Now ${series.last.$2.toStringAsFixed(1)}% body fat',
      // "since your first scan" was wrong once the chart started showing a
      // window: series.first is the oldest scan *in view*, not the oldest
      // ever, for anyone past the window size.
      takeaway:
          '${change <= 0 ? '' : '+'}${change.toStringAsFixed(1)}% across your '
          'last ${series.length} scans'
          '${change <= 0 ? ' — moving the right way' : ''}',
      takeawayColor: change <= 0 ? kGreen : kPink,
      chart: _metricLine(series, kPink),
    );
  }

  Widget _weightMetric(List<(String, double)> series) {
    if (series.length < 2) {
      // The general path would read "Started 162.0 · Now 162.0 lbs" and
      // "+0.0 lbs (last 30 days)" — a start and a 30-day history invented
      // from a single entry.
      return _metricBody(
        headline: '${series.last.$2.toStringAsFixed(1)} lbs',
        takeaway: 'First weigh-in recorded',
        takeawayColor: kCyan,
        chart: _metricLine(series, kCyan),
      );
    }
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
      ),
    );
  }

  Widget _scoreMetric(List<(String, double)> series) {
    if (series.length < 2) {
      // Otherwise: "+0 vs your first scan across 1 scans".
      return _metricBody(
        headline: 'Latest score ${series.last.$2.round()}/100',
        takeaway: 'Your first scan',
        takeawayColor: kCyan,
        chart: _scoreBars(series),
      );
    }
    final change = (series.last.$2 - series.first.$2).round();
    return _metricBody(
      headline: 'Latest score ${series.last.$2.round()}/100',
      // Same correction: with a window, series.first is not the first scan,
      // and series.length is the window size rather than the scan count.
      takeaway:
          '${change >= 0 ? '+' : ''}$change across your last '
          '${series.length} scans',
      takeawayColor: change >= 0 ? kGreen : kPink,
      chart: _scoreBars(series),
    );
  }

  Widget _metricLine(List<(String, double)> series, Color color) {
    final values = series.map((e) => e.$2).toList();
    final yr = paddedYRange(values, basePad: 0.3);
    final xr = xRangeFor(values.length);
    // No unit on the point labels — the headline above the chart already
    // says what the number is, and "162.0lbs" is wide enough that the suffix
    // alone forces labels to be dropped.
    final labelStyle = TextStyle(
      color: color,
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );
    final labels = [for (final v in values) v.toStringAsFixed(1)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelled = fittingLabelIndices(
          labels: labels,
          style: labelStyle,
          pointSpacing: linePointSpacing(constraints.maxWidth, values.length),
        );
        return LineChart(
          LineChartData(
            minY: yr.min,
            maxY: yr.max,
            // A lone point would otherwise be pinned to the left border.
            minX: xr.min,
            maxX: xr.max,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yr.interval(),
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: kChartGrid, strokeWidth: 1),
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
                    LineTooltipItem(s.y.toStringAsFixed(1), labelStyle),
                ],
              ),
            ),
            showingTooltipIndicators: [
              for (final i in labelled)
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
      },
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
      dotData: FlDotData(
        show: true,
        // Only the newest reading. Thirty weigh-ins with a dot each read as
        // a dotted band rather than a trend.
        checkToShowDot: (spot, bar) =>
            bar.spots.isNotEmpty && spot.x == bar.spots.last.x,
        getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: kBgCard,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          // A 20% wash was almost nothing against the card.
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  /// Physique score as bars — one per scan, latest highlighted.
  Widget _scoreBars(List<(String, double)> series) {
    final maxVal = series.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    // Bars thin out as the series grows so they always sit inside their own
    // slot with a gap, instead of merging into a solid block.
    final barWidth = (240 / series.length * 0.55).clamp(4.0, 14.0);
    final labelStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );
    final labels = [for (final e in series) '${e.$2.round()}'];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Bars carry a label each; past a certain density they cannot all
        // fit, so only the ones that clear their neighbours are shown.
        final labelled = fittingLabelIndices(
          labels: labels,
          style: labelStyle,
          pointSpacing: barPointSpacing(constraints.maxWidth, series.length),
        ).toSet();
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
                  labelStyle.copyWith(
                    color: group.x == series.length - 1
                        ? kLime
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            titlesData: const FlTitlesData(show: false),
            barGroups: [
              for (var i = 0; i < series.length; i++)
                BarChartGroupData(
                  x: i,
                  showingTooltipIndicators: labelled.contains(i)
                      ? const [0]
                      : const [],
                  barRods: [
                    BarChartRodData(
                      toY: series[i].$2,
                      width: barWidth,
                      borderRadius: BorderRadius.circular(barWidth * 0.34),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          (i == series.length - 1
                                  ? ChartFill.lime
                                  : chartMuted(ChartFill.lime))
                              .withValues(alpha: 0.62),
                          i == series.length - 1
                              ? ChartFill.lime
                              : chartMuted(ChartFill.lime),
                        ],
                      ),
                      // Earlier scans were drawn at alpha 0.4, which sinks
                      // into the card; the grey de-emphasis recedes without
                      // disappearing. The track gives each scan a slot so a
                      // low score reads as low rather than as missing.
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxVal,
                        color: kChartTrack,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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
                  // Just the label here. The date used to share this row
                  // with two 18px stat numbers and lost every time both were
                  // present — "AUG 26" was rendered as "A…", which tells the
                  // reader nothing at all. It moved into the expanded detail
                  // below, where it has a line to itself.
                  Flexible(
                    child: Text(
                      'Scan #$number',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (score != null)
                    Text(
                      '$score/100',
                      style: TextStyle(
                        color: kLime,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (bf != null)
                    Text(
                      '${bf.toStringAsFixed(1)}%',
                      style: TextStyle(
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

    final date = _fullDateLabel(scan['created_at'] as String?);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (date.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          for (final (name, v) in scores)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // Proportional, not a fixed 78px: "Shoulders" outgrew that
                  // at the larger font sizes phones ship with and wrapped to
                  // "Shoulder / s".
                  Expanded(
                    flex: 4,
                    child: Text(
                      name,
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
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
              style: TextStyle(color: kGreen, fontSize: 11),
            ),
          ],
          if (weaknesses.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '– ${weaknesses.join(' · ')}',
              style: TextStyle(color: kPink, fontSize: 11),
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
class _MuscleMapCard extends StatefulWidget {
  const _MuscleMapCard({required this.scores, this.scanDate});

  /// Scores 0-10 keyed by: chest, back, lats, mid back, traps, shoulders,
  /// arms, legs, core.
  final Map<String, double?> scores;
  final String? scanDate;

  @override
  State<_MuscleMapCard> createState() => _MuscleMapCardState();
}

class _MuscleMapCardState extends State<_MuscleMapCard> {
  bool _back = false;

  /// Back regions only carry a score when the scan had a back photo. With
  /// none of them scored there is nothing to show back-side, so the toggle
  /// stays hidden rather than offering an entirely grey figure.
  bool get _hasBackDetail => const [
    'lats',
    'mid back',
    'traps',
    'back',
  ].any((k) => widget.scores[k] != null);

  @override
  Widget build(BuildContext context) {
    final showToggle = _hasBackDetail;
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
            widget.scanDate != null
                ? 'MUSCLE MAP · ${widget.scanDate}'
                : 'MUSCLE MAP',
            style: kLabelSmall.copyWith(fontSize: 8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (showToggle) ...[_frontBackToggle(), const SizedBox(height: 6)],
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.55,
                child: CustomPaint(
                  painter: _back && showToggle
                      ? _BackMuscleMapPainter(scores: widget.scores)
                      : _MuscleMapPainter(scores: widget.scores),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _frontBackToggle() {
    return Container(
      decoration: BoxDecoration(
        color: kBgElevated,
        borderRadius: BorderRadius.circular(7),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (final (label, isBack) in [('FRONT', false), ('BACK', true)])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _back = isBack),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: _back == isBack ? kPink : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    label,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: _back == isBack ? Colors.black : kTextMuted,
                    ),
                  ),
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

    // ── Traps — the slope from neck to shoulders, visible from the front
    //    too. Falls back to the overall back score on older scans, which
    //    have no traps score stored. ────────────────────────────────────
    final traps = Path()
      ..moveTo(0.36 * w, 0.165 * h)
      ..lineTo(0.455 * w, 0.125 * h)
      ..lineTo(0.545 * w, 0.125 * h)
      ..lineTo(0.64 * w, 0.165 * h)
      ..close();
    canvas.drawPath(traps, fill(scores['traps'] != null ? 'traps' : 'back'));
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

/// Back view of the muscle map. Deliberately shares the front view's
/// proportions — same head, neck, delt and leg geometry — so flipping
/// between the two reads as turning one figure around rather than swapping
/// to a different drawing.
class _BackMuscleMapPainter extends CustomPainter {
  _BackMuscleMapPainter({required this.scores})
    : _brightness = AppColors.brightness;

  final Map<String, double?> scores;
  final Brightness _brightness;

  Color _tint(String region, [double alpha = 0.8]) {
    final v = scores[region];
    if (v == null) return kBodyUnscored;
    final hue = v >= 7
        ? kGreen
        : v >= 5
        ? kGold
        : kPink;
    return Color.alphaBlend(hue.withValues(alpha: alpha), kBgCard);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Paint fill(String region, [double alpha = 0.8]) =>
        Paint()..color = _tint(region, alpha);
    final neutral = Paint()..color = kBodyNeutral;
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
    Path poly(List<(double, double)> pts) {
      final p = Path()..moveTo(pts.first.$1 * w, pts.first.$2 * h);
      for (final pt in pts.skip(1)) {
        p.lineTo(pt.$1 * w, pt.$2 * h);
      }
      return p..close();
    }

    // ── Head & neck (neutral) — identical to the front ────────────────
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

    // ── Traps — the slope from neck out to each shoulder ──────────────
    final traps = poly([
      (0.355, 0.19),
      (0.455, 0.125),
      (0.545, 0.125),
      (0.645, 0.19),
      (0.575, 0.255),
      (0.425, 0.255),
    ]);
    canvas.drawPath(traps, fill('traps'));
    canvas.drawPath(traps, contour);
    canvas.drawLine(o(0.5, 0.135), o(0.5, 0.25), divider);

    // ── Rear delts — same caps as the front view ──────────────────────
    for (final dx in [0.265, 0.735]) {
      final delt = Rect.fromCenter(
        center: o(dx, 0.185),
        width: 0.15 * w,
        height: 0.07 * h,
      );
      canvas.drawOval(delt, fill('shoulders'));
      canvas.drawOval(delt, contour);
    }

    // ── Lats — wings flaring from the armpit and tapering to the waist,
    //    which is what gives the V-taper its shape ─────────────────────
    for (final left in [true, false]) {
      double x(double v) => left ? v : 1 - v;
      final lat = poly([
        (x(0.305), 0.25),
        (x(0.435), 0.26),
        (x(0.445), 0.465),
        (x(0.365), 0.45),
      ]);
      canvas.drawPath(lat, fill('lats'));
      canvas.drawPath(lat, contour);
      // Two sweep lines hint at the fanning fibres.
      for (final t in [0.32, 0.39]) {
        canvas.drawLine(o(x(0.34), t), o(x(0.43), t + 0.015), divider);
      }
    }

    // ── Mid back — the rhomboid block between the shoulder blades ─────
    final mid = rr(0.44, 0.265, 0.56, 0.365, 6);
    canvas.drawRRect(mid, fill('mid back'));
    canvas.drawRRect(mid, contour);
    canvas.drawLine(o(0.5, 0.275), o(0.5, 0.355), divider);

    // ── Lower back — erectors either side of the spine ────────────────
    final lower = rr(0.45, 0.375, 0.55, 0.47, 6);
    canvas.drawRRect(lower, fill('back'));
    canvas.drawRRect(lower, contour);
    canvas.drawLine(o(0.5, 0.385), o(0.5, 0.46), divider);

    // ── Arms — triceps + forearm, mirroring the front geometry ────────
    void arm(bool left) {
      final sign = left ? -1.0 : 1.0;
      final sx = 0.5 + sign * 0.235;
      final upper = poly([
        (sx - 0.045, 0.215),
        (sx + 0.045, 0.215),
        (sx + sign * 0.03 + 0.04, 0.36),
        (sx + sign * 0.03 - 0.04, 0.36),
      ]);
      canvas.drawPath(upper, fill('arms'));
      canvas.drawPath(upper, contour);
      final fx = sx + sign * 0.035;
      final fore = poly([
        (fx - 0.033, 0.375),
        (fx + 0.033, 0.375),
        (fx + sign * 0.02 + 0.025, 0.52),
        (fx + sign * 0.02 - 0.025, 0.52),
      ]);
      canvas.drawPath(fore, fill('arms', 0.55));
      canvas.drawPath(fore, contour);
    }

    arm(true);
    arm(false);

    // ── Glutes — the one region the front view has no equivalent for ──
    for (final left in [true, false]) {
      final cx = 0.5 + (left ? -0.075 : 0.075);
      final glute = rr(cx - 0.062, 0.48, cx + 0.062, 0.565, 12);
      canvas.drawRRect(glute, fill('legs'));
      canvas.drawRRect(glute, contour);
    }

    // ── Hamstrings + calves — same taper as the front's quads ─────────
    void leg(bool left) {
      final cx = 0.5 + (left ? -0.075 : 0.075);
      final ham = poly([
        (cx - 0.07, 0.575),
        (cx + 0.07, 0.575),
        (cx + 0.05, 0.735),
        (cx - 0.05, 0.735),
      ]);
      canvas.drawPath(ham, fill('legs'));
      canvas.drawPath(ham, contour);
      final calf = poly([
        (cx - 0.045, 0.755),
        (cx + 0.045, 0.755),
        (cx + 0.03, 0.955),
        (cx - 0.03, 0.955),
      ]);
      canvas.drawPath(calf, fill('legs', 0.55));
      canvas.drawPath(calf, contour);
    }

    leg(true);
    leg(false);
  }

  @override
  bool shouldRepaint(_BackMuscleMapPainter old) =>
      old.scores != scores || old._brightness != _brightness;
}

// The muscle map is drawn on a raw canvas, so the widget tree says nothing
// about whether a region landed in the right place. These aliases let the
// painters be rendered and sampled directly from tests without making them
// part of the screen's public surface.
@visibleForTesting
typedef MuscleMapPainterForTest = _MuscleMapPainter;

@visibleForTesting
typedef BackMuscleMapPainterForTest = _BackMuscleMapPainter;
