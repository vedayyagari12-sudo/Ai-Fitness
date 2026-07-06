import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../api_service.dart';
import '../../physique_scan_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../workout_generator_screen.dart';

// Composition accent palette (screenshot-accurate).
const Color _pink = Color(0xFFFF3B79);
const Color _green = Color(0xFFB8F94B);
const Color _yellow = Color(0xFFFFD23F);

/// BODY tab — "Your composition": physique scan results, muscle development,
/// body-fat trend and an AI focus-plan hand-off to the TRAIN tab.
class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _MuscleScore {
  _MuscleScore(this.name, this.score);
  final String name;
  final int score; // 0–100
  bool lag = false;
  Color color = _green;
}

class _BodyScreenState extends State<BodyScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _muscle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([getDashboard(), getMuscleBalance()]);
    if (!mounted) return;
    setState(() {
      _data = results[0];
      _muscle = results[1];
      _loading = false;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _chartById(String id) {
    final charts = _data?['charts'] as List? ?? const [];
    for (final c in charts) {
      final m = c as Map<String, dynamic>;
      if (m['id'] == id) return m;
    }
    return null;
  }

  List<double> _chartValues(String id) {
    final v = _chartById(id)?['values'] as List?;
    return v?.map((e) => (e as num).toDouble()).toList() ?? const [];
  }

  List<_MuscleScore> get _muscleScores {
    final groups = _muscle?['groups'] as Map<String, dynamic>? ?? {};
    if (groups.isEmpty) return const [];
    const order = ['back', 'core', 'chest', 'arms', 'legs', 'shoulders'];
    final vals = {
      for (final k in order) k: (groups[k] as num?)?.toDouble() ?? 0.0,
    };
    final maxV = vals.values.fold(0.0, (a, b) => a > b ? a : b);
    final list = order.map((k) {
      final score = maxV > 0 ? (vals[k]! / maxV * 100).round() : 0;
      return _MuscleScore(_titleCase(k), score);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    // Colour by rank; the two weakest are flagged as lagging.
    const palette = [_green, _green, _green, kBlue, _yellow, _pink];
    for (var i = 0; i < list.length; i++) {
      list[i].color = palette[i.clamp(0, palette.length - 1)];
      list[i].lag = i >= list.length - 2;
    }
    return list;
  }

  List<String> get _laggingNames =>
      _muscleScores.where((m) => m.lag).map((m) => m.name).toList();

  String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: kBlue,
          child: _loading ? _skeleton() : _content(),
        ),
      ),
    );
  }

  Widget _skeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        ShimmerBox(width: 160, height: 14, borderRadius: 6),
        const SizedBox(height: 12),
        ShimmerBox(width: 220, height: 30, borderRadius: 8),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
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
        ShimmerBox(width: double.infinity, height: 240, borderRadius: 18),
      ],
    );
  }

  Widget _content() {
    final ts = _data?['today_stats'] as Map<String, dynamic>?;
    final bfTrend = _chartValues('body_fat_trend');
    final bwTrend = _chartValues('bodyweight_trend');

    final bf = (ts?['body_fat'] as num?)?.toDouble() ??
        (bfTrend.isNotEmpty ? bfTrend.last : 0);
    final bfChange = (ts?['body_fat_change'] as num?)?.toDouble() ??
        (bfTrend.length >= 2 ? bfTrend.last - bfTrend.first : 0);

    final weightKg = bwTrend.isNotEmpty ? bwTrend.last : 0;
    final weightLb = weightKg * 2.20462;
    final weightChgLb = ((ts?['weight_change'] as num?)?.toDouble() ??
            (bwTrend.length >= 2 ? bwTrend.last - bwTrend.first : 0)) *
        2.20462;
    final leanLb = weightLb * (1 - bf / 100);
    final leanChgLb = weightChgLb * (1 - bf / 100);

    final scans = (_data?['recent_scans'] as List?) ?? const [];
    final scanNo = scans.isNotEmpty
        ? (scans.first['number']?.toString() ?? '${bfTrend.length}')
        : '${bfTrend.length}';
    final scanCount = bfTrend.isNotEmpty ? bfTrend.length : 0;
    final bfAllTime = bfTrend.length >= 2 ? bfTrend.last - bfTrend.first : 0.0;

    final sections = <Widget>[
      _header(scanNo),
      const SizedBox(height: 18),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 5, child: _BodyRenderCard()),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _statCard(
                    'BODY FAT',
                    '${bf.toStringAsFixed(1)}%',
                    bfChange,
                    'pct',
                    favorableWhenDown: true,
                    valueColor: _pink,
                  ),
                  const SizedBox(height: 12),
                  _statCard(
                    'LEAN MASS',
                    '${leanLb.toStringAsFixed(0)}lb',
                    leanChgLb,
                    'lb',
                    favorableWhenDown: false,
                    valueColor: kBlue,
                  ),
                  const SizedBox(height: 12),
                  _statCard(
                    'WEIGHT',
                    '${weightLb.toStringAsFixed(0)}lb',
                    weightChgLb,
                    'lb',
                    neutral: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _muscleCard(),
      const SizedBox(height: 16),
      _bfTrendCard(bfTrend, scanCount, bfAllTime),
      if (_laggingNames.isNotEmpty) ...[
        const SizedBox(height: 16),
        _focusCta(),
      ],
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
        for (var i = 0; i < sections.length; i++)
          sections[i]
              .animate()
              .fadeIn(duration: 320.ms, delay: (i * 35).ms)
              .slideY(begin: 0.05, end: 0, duration: 320.ms, delay: (i * 35).ms),
      ],
    );
  }

  Widget _header(String scanNo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHYSIQUE SCAN · #$scanNo',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your composition',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PhysiqueScanScreen()),
          ).then((_) {
            if (mounted) _load();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBlue.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_rounded, size: 13, color: kBlue),
                const SizedBox(width: 5),
                Text(
                  'New scan',
                  style: TextStyle(
                    color: kBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    double change,
    String unit, {
    bool favorableWhenDown = false,
    bool neutral = false,
    Color? valueColor,
  }) {
    final down = change < 0;
    final favorable = neutral ? false : (favorableWhenDown ? down : !down);
    final deltaColor =
        neutral ? AppColors.textMuted : (favorable ? _green : _pink);
    final arrow = neutral
        ? ''
        : (down ? '▼ ' : '▲ ');
    final mag = change.abs();
    final deltaStr = unit == 'pct'
        ? '${mag.toStringAsFixed(1)}%'
        : '${change >= 0 ? '+' : '-'}${mag.toStringAsFixed(1)} lb';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                '$arrow$deltaStr',
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'vs last',
              style: TextStyle(color: AppColors.textMuted, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _muscleCard() {
    final scores = _muscleScores;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MUSCLE DEVELOPMENT',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (scores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Log a few workouts to map your muscle development.',
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
            width: 74,
            child: Row(
              children: [
                Text(
                  m.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (m.lag) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: m.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LAG',
                      style: TextStyle(
                        color: m.color,
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
          const SizedBox(width: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: m.score / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(m.color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 24,
            child: Text(
              '${m.score}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bfTrendCard(List<double> trend, int scanCount, double allTime) {
    final hasData = trend.length >= 2;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BODY FAT · $scanCount SCANS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (hasData)
                Text(
                  '${allTime <= 0 ? '' : '+'}${allTime.toStringAsFixed(1)}% all-time',
                  style: TextStyle(
                    color: allTime <= 0 ? _green : _pink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: hasData
                ? _sparkline(trend)
                : Center(
                    child: Text(
                      'Scan again to start your trend.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sparkline(List<double> values) {
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: minY - 0.6,
        maxY: maxY + 0.6,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _pink,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [_pink.withValues(alpha: 0.28), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WorkoutGeneratorScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _pink.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_laggingNames.length} FOCUS AREAS FOUND',
                    style: TextStyle(
                      color: _pink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your $names are lagging — we built a plan.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
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
                color: _pink,
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
}

/// Stylised body-render placeholder card (left column of the composition row).
class _BodyRenderCard extends StatelessWidget {
  const _BodyRenderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            kBlue.withValues(alpha: 0.10),
            AppColors.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'BODY RENDER',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.accessibility_new_rounded,
              size: 96,
              color: kBlue.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
