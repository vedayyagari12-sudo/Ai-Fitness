import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'calorie_scan_screen.dart';
import 'log_workout_screen.dart';
import 'physique_scan_screen.dart';
import 'workout_generator_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/app_state_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';
import 'utils/snackbar.dart';

// ── Dashboard refresh hook (called from MainScreen on tab switch) ─────────────
VoidCallback? _dashboardRefreshHook;
void triggerDashboardRefresh() => _dashboardRefreshHook?.call();

// ── Constants ─────────────────────────────────────────────────────────────────
const _milestones = [7, 30, 60, 100, 365];
const _muscleOrder = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];

// ── Confetti ──────────────────────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress, this.particles);

  final double progress;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x =
          p.x * size.width +
          math.cos(p.angle) * p.speed * progress * size.width * 0.5;
      final y =
          p.y * size.height +
          progress * size.height * 0.8 +
          math.sin(p.angle) * p.speed * size.height * 0.2;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), p.radius * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  _Particle(math.Random rng)
    : x = rng.nextDouble(),
      y = rng.nextDouble() * 0.3,
      angle = rng.nextDouble() * math.pi * 2,
      speed = 0.3 + rng.nextDouble() * 0.7,
      radius = 3 + rng.nextDouble() * 5,
      color = _confettiColors[rng.nextInt(_confettiColors.length)];

  final double x, y, angle, speed, radius;
  final Color color;
}

const _confettiColors = [
  Colors.orange,
  Colors.amber,
  Colors.green,
  Colors.blue,
  Colors.pink,
  Colors.purple,
  Colors.red,
  Colors.cyan,
];

// ── 270° readiness gauge painter ──────────────────────────────────────────────

// ── Milestone full-screen overlay ─────────────────────────────────────────────
class _MilestoneOverlay extends StatefulWidget {
  const _MilestoneOverlay({required this.days});
  final int days;

  @override
  State<_MilestoneOverlay> createState() => _MilestoneOverlayState();
}

class _MilestoneOverlayState extends State<_MilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A1A2E),
                  Colors.amber.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                Text(
                  '${widget.days} Day Milestone!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You're on fire 🔥\nKeep that streak alive!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                ContinueButton(
                  label: 'Keep it going!',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dashboard screen ──────────────────────────────────────────────────────────
// Screenshot-accurate "The Outsiders" accent palette (lime / cyan / neon).
const Color _cYellow = Color(0xFFFFD23F); // LOAD
const Color _cPink = Color(0xFFFF3B79); // BODY FAT
const Color _cGreen = Color(0xFFB8F94B); // PROTEIN (lime-green)
const Color _cCyan = Color(0xFF00D8E8); // FUELED / trend / session
const Color _cBlue = Color(0xFF1CA7F0); // READY / brand signature (blue)

class _MultiRingPainter extends CustomPainter {
  _MultiRingPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;
  static const double stroke = 9;
  static const double gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    double r = size.shortestSide / 2 - stroke / 2;
    for (var i = 0; i < values.length; i++) {
      // Recessed track groove.
      final track = Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, r, track);

      final p = values[i].clamp(0.0, 1.0);
      if (p > 0) {
        final rect = Rect.fromCircle(center: center, radius: r);
        const start = -math.pi / 2;
        final sweep = 2 * math.pi * p;

        // Outer neon glow.
        final glow = Paint()
          ..color = colors[i].withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        canvas.drawArc(rect, start, sweep, false, glow);

        // Crisp progress arc with a subtle gradient along its length.
        final arc = Paint()
          ..shader = SweepGradient(
            colors: [colors[i].withValues(alpha: 0.65), colors[i]],
            startAngle: start,
            endAngle: start + sweep,
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, start, sweep, false, arc);
      }
      r -= (stroke + gap);
    }
  }

  @override
  bool shouldRepaint(_MultiRingPainter old) => true;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // Data state
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _streak;
  Map<String, dynamic>? _muscleData;
  String? _aiSummary;
  int _weeklyGoal = 4; // workouts/week target, derived from onboarding
  int _trendTab = 0;
  bool _loading = true;
  bool _loadingAiSummary = false;
  String? _error;
  bool _bannerDismissed = false;

  // Weight log state
  final _weightController = TextEditingController();
  bool _savingWeight = false;
  bool _weightSaved = false;
  bool _loggedToday = false;
  double? _todayWeight;

  // Streak increment tracking
  int _prevStreak = 0;

  // Confetti particles
  late List<_Particle> _particles;

  // ── Animation Controllers ─────────────────────────────────────────────────
  late final AnimationController _countCtrl; // streak count-up
  late final AnimationController _pulseCtrl; // today dot pulse
  late final AnimationController _confettiCtrl;
  late final AnimationController _chartCtrl; // chart/ring entrance
  late final AnimationController _dotPulseCtrl; // line chart dot radius
  late final AnimationController _fadeCtrl; // screen fade-in

  late Animation<double> _pulseScale;
  late Animation<double> _dotRadius;
  late Animation<double> _chartAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _particles = List.generate(40, (_) => _Particle(math.Random()));

    _chartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _chartAnim = CurvedAnimation(parent: _chartCtrl, curve: Curves.easeOut);

    _dotPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _dotRadius = Tween<double>(begin: 4.0, end: 6.5).animate(_dotPulseCtrl);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _dashboardRefreshHook = _load;
    _load();
  }

  @override
  void dispose() {
    _dashboardRefreshHook = null;
    _countCtrl.dispose();
    _pulseCtrl.dispose();
    _confettiCtrl.dispose();
    _chartCtrl.dispose();
    _dotPulseCtrl.dispose();
    _fadeCtrl.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final results = await Future.wait([
      getDashboard(),
      getStreak(),
      getTodayBodyweight(),
      getMuscleBalance(),
    ]);

    if (!mounted) return;

    final data = results[0];
    final streak = results[1];
    final todayBw = results[2];
    final muscle = results[3];

    final onboarding = await AppStateService.getOnboardingData();
    if (!mounted) return;

    final newStreak = (streak?['current_streak'] as int?) ?? 0;
    final didIncrement = newStreak > _prevStreak && _prevStreak > 0;

    setState(() {
      _data = data;
      _streak = streak;
      _muscleData = muscle;
      _weeklyGoal = _parseWeeklyGoal(onboarding?.workoutFrequency);
      _loggedToday = (todayBw?['logged_today'] as bool?) ?? false;
      _todayWeight = (todayBw?['weight_kg'] as num?)?.toDouble();
      _loading = false;
      _error = data == null ? 'Could not load dashboard data' : null;
    });

    _countCtrl.forward(from: 0);
    _chartCtrl.forward(from: 0);
    _fadeCtrl.forward(from: 0);

    if (didIncrement) {
      HapticFeedback.heavyImpact();
      _confettiCtrl.forward(from: 0);
      _particles = List.generate(40, (_) => _Particle(math.Random()));
    }

    _prevStreak = newStreak;

    if (newStreak > 0) _checkMilestones(newStreak);

    // Load AI summary separately so it doesn't block the main load
    _loadAiSummaryAsync();
  }

  Future<void> _loadAiSummaryAsync() async {
    if (_loadingAiSummary) return;
    setState(() => _loadingAiSummary = true);
    final summary = await getAiSummary();
    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _loadingAiSummary = false;
      });
    }
  }

  Future<void> _checkMilestones(int streak) async {
    for (final m in _milestones) {
      if (streak == m) {
        final seen = await AppStateService.getSeenMilestones();
        if (!seen.contains(m) && mounted) {
          await AppStateService.markMilestoneSeen(m);
          _showMilestoneOverlay(m);
        }
      }
    }
  }

  void _showMilestoneOverlay(int days) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, anim, _) => FadeTransition(
          opacity: anim,
          child: _MilestoneOverlay(days: days),
        ),
      ),
    );
  }

  Future<void> _logWeight() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) return;
    setState(() => _savingWeight = true);
    final result = await logBodyweight(weight);
    if (!mounted) return;
    if (result != null && result['saved'] == true) {
      HapticFeedback.mediumImpact();
      setState(() {
        _savingWeight = false;
        _weightSaved = true;
        _loggedToday = true;
        _todayWeight = weight;
      });
      _weightController.clear();
      AppSnackbar.success(
        context,
        'Weight logged: ${weight.toStringAsFixed(1)} kg',
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _weightSaved = false);
      });
      // Refresh charts to show updated bodyweight trend
      getDashboard().then((d) {
        if (mounted && d != null) setState(() => _data = d);
      });
    } else {
      setState(() => _savingWeight = false);
      final detail = result?['error'];
      AppSnackbar.error(
        context,
        detail is String
            ? 'Failed to save weight — $detail'
            : 'Failed to save weight',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStreak = (_streak?['current_streak'] as int?) ?? 0;
    final atRisk = (_streak?['streak_at_risk'] as bool?) ?? false;
    final showBanner = atRisk && DateTime.now().hour >= 18 && !_bannerDismissed;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: _loading
                  ? _buildShimmerSkeleton()
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                        children: [..._animatedSections()],
                      ),
                    ),
            ),

            // Confetti overlay
            if (_confettiCtrl.isAnimating || _confettiCtrl.value > 0)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiCtrl,
                  builder: (_, _) => CustomPaint(
                    painter: _ConfettiPainter(_confettiCtrl.value, _particles),
                    size: MediaQuery.of(context).size,
                  ),
                ),
              ),

            // After-6pm streak-at-risk banner
            if (showBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildAtRiskBanner(currentStreak),
              ),
          ],
        ),
      ),
    );
  }

  // ── New: animated sections, colorful charts, big stats, banner ──────────────

  Map<String, dynamic>? _chartById(String id) {
    final charts = _data?['charts'] as List? ?? const [];
    for (final c in charts) {
      final m = c as Map<String, dynamic>;
      if (m['id'] == id) return m;
    }
    return null;
  }

  List<double>? _chartValues(String id) {
    final v = _chartById(id)?['values'] as List?;
    return v?.map((e) => (e as num).toDouble()).toList();
  }

  Widget _entrance(Widget child, int i) => child
      .animate()
      .fadeIn(duration: 360.ms, delay: (i * 50).ms)
      .slideY(
        begin: 0.06,
        end: 0,
        duration: 360.ms,
        delay: (i * 50).ms,
        curve: Curves.easeOutCubic,
      );

  List<Widget> _animatedSections() {
    final muscleTotal = (_muscleData?['total'] as int?) ?? 0;
    const volIds = [
      'weekly_volume',
      'daily_volume',
      'daily_sessions',
      'daily_workouts',
      'weekly_sessions',
    ];
    final volId = volIds.firstWhere(
      (id) => _chartById(id) != null,
      orElse: () => '',
    );

    final sections = <Widget>[
      _mockHeader(),
      if (_data != null) _buildHeroCard(),
      if (_data != null) _trendCard(),
      if (_data != null) _physiqueSessionRow(),
      if (_data != null) _recentScans(),
      if (_data != null) _buildBigStats(),
      if (_data != null) _buildSuggestedActions(),
      if (_data != null) _buildMacrosPieCard(),
      if (_data != null) _buildCalorieBudgetCard(),
      if (_chartById('daily_calories') != null)
        _chartCard(
          'CALORIES',
          'daily_calories',
          AppColors.accent,
          forceType: 'line',
        ),
      if (_chartById('daily_protein') != null)
        _chartCard(
          'PROTEIN',
          'daily_protein',
          _cCyan,
          forceType: 'bar',
        ),
      if (volId.isNotEmpty)
        _chartCard(
          'TRAINING LOAD',
          volId,
          AppColors.accentViolet,
          forceType: 'bar',
        ),
      if (_streak != null) _buildTrainingCalendar(),
      if (muscleTotal > 0) _buildMuscleBalanceCard(),
      _weightLogCard(),
      _buildAiSummaryCard(),
      if (_data != null) _motivationBanner(),
      if (_error != null)
        AppCard(
          margin: EdgeInsets.zero,
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
    ];

    final out = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      out.add(_entrance(sections[i], i));
      if (i != sections.length - 1) out.add(const SizedBox(height: 16));
    }
    return out;
  }

  Widget _mockHeader() {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateLabel(),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _greeting(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceElevated,
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _dateLabel() {
    final dt = DateTime.now();
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
    return '${days[dt.weekday - 1]} · ${months[dt.month - 1]} ${dt.day}';
  }

  Widget _sectionLbl(String t) => Text(
    t,
    style: TextStyle(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );

  Widget _cornerStat(
    String value,
    Color color,
    String label, {
    String? sub,
    Color? subColor,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -0.5,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.30), blurRadius: 14),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              sub,
              style: TextStyle(
                color: subColor ?? AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _goalPill(String goal) {
    final g = goal.toLowerCase();
    final (String label, IconData icon, Color tint) = switch (g) {
      'cut' || 'cutting' || 'lose' || 'lose_weight' => (
        'CUTTING',
        Icons.trending_down_rounded,
        AppColors.success,
      ),
      'bulk' || 'bulking' || 'gain' || 'gain_muscle' => (
        'BULKING',
        Icons.trending_up_rounded,
        _cBlue,
      ),
      _ => ('MAINTAINING', Icons.trending_flat_rounded, _cCyan),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendTabs(List<String> labels, int active) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final sel = i == active;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _trendTab = i;
                _chartCtrl.forward(from: 0);
              }),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? _cCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sel ? Colors.black : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _trendCard() {
    final goal = (_data?['goal'] as String?) ?? 'maintain';
    const tabs = [
      ('WEIGHT', 'bodyweight_trend'),
      ('CALORIES', 'daily_calories'),
      ('VOLUME', 'weekly_volume'),
    ];
    final safe = _trendTab.clamp(0, tabs.length - 1);
    var chartId = tabs[safe].$2;
    if (chartId == 'weekly_volume') {
      chartId =
          const [
            'weekly_volume',
            'daily_volume',
            'daily_sessions',
            'daily_workouts',
            'workout_consistency',
          ].firstWhere(
            (id) => _chartById(id) != null,
            orElse: () => 'weekly_volume',
          );
    }
    final chart = _chartById(chartId);
    final values =
        (chart?['values'] as List?)
            ?.map((v) => (v as num).toDouble())
            .toList() ??
        const [];
    final hasData = values.any((v) => v != 0);

    String bigVal = '';
    String change = '';
    String total = '';
    if (values.isNotEmpty) {
      final latest = values.last;
      final delta = values.last - values.first;
      if (safe == 0) {
        final lb = latest * 2.20462;
        final dLb = delta * 2.20462;
        bigVal = '${lb.toStringAsFixed(1)} lb';
        total = '${dLb >= 0 ? '+' : ''}${dLb.toStringAsFixed(1)} lb total';
        final perWk = dLb / (values.length > 1 ? values.length - 1 : 1);
        change = '${perWk >= 0 ? '+' : ''}${perWk.toStringAsFixed(1)} lb / wk';
      } else {
        bigVal = '${latest.toInt()}';
        change = '${delta >= 0 ? '+' : ''}${delta.toInt()} this period';
      }
    }

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionLbl('8-WEEK TREND'),
              const Spacer(),
              _goalPill(goal),
            ],
          ),
          const SizedBox(height: 14),
          _trendTabs(const ['WEIGHT', 'CALORIES', 'VOLUME'], safe),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bigVal,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              if (change.isNotEmpty)
                Text(
                  change,
                  style: TextStyle(
                    color: _cCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (total.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                total,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: AnimatedBuilder(
              animation: _chartAnim,
              builder: (_, _) => hasData && chart != null
                  ? _lineChart(
                      chart,
                      goal: goal,
                      anim: _chartAnim.value,
                      color: _cCyan,
                    )
                  : _emptyChart(<String, dynamic>{'type': 'line'}),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot(_cCyan, 'Actual'),
              const SizedBox(width: 16),
              _legendDot(AppColors.textMuted, 'Maintain zone'),
              const Spacer(),
              Text(
                'Goal',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _physiqueSessionRow() {
    final ts = _data?['today_stats'] as Map<String, dynamic>?;
    final bodyFat = (ts?['body_fat'] as num?)?.toDouble() ?? 0;
    final bodyFatChange = (ts?['body_fat_change'] as num?)?.toDouble() ?? 0;
    final bfSpark = _chartValues('body_fat_trend');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLbl('PHYSIQUE'),
                  const SizedBox(height: 10),
                  Text(
                    '${bodyFat.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    bodyFatChange == 0
                        ? 'BODY FAT'
                        : '${bodyFatChange > 0 ? '+' : ''}${bodyFatChange.toStringAsFixed(1)}% this week',
                    style: TextStyle(
                      color: _cPink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: (bfSpark != null && bfSpark.isNotEmpty)
                        ? AnimatedBuilder(
                            animation: _chartAnim,
                            builder: (_, _) =>
                                _sparkline(bfSpark, _cPink, _chartAnim.value),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _sessionCard()),
        ],
      ),
    );
  }

  Widget _sessionCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cCyan.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY\'S SESSION',
            style: TextStyle(
              color: _cCyan,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sessionTitle(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '45 min · 7 moves',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Tuned to your physique scan',
            style: TextStyle(
              color: _cCyan,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WorkoutGeneratorScreen(),
                  ),
                ).then((_) {
                  if (mounted) _load();
                }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _cCyan,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Start',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: Colors.black),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _latestChart(String id) {
    final v = _chartValues(id);
    return (v != null && v.isNotEmpty) ? v.last : 0;
  }

  double _chartDelta(String id) {
    final v = _chartValues(id);
    return (v != null && v.length >= 2) ? v.last - v.first : 0;
  }

  String _sessionFocus() {
    const f = [
      'PUSH DAY',
      'PULL DAY',
      'LEG DAY',
      'UPPER DAY',
      'FULL BODY',
      'CONDITIONING',
      'REST DAY',
    ];
    return f[(DateTime.now().weekday - 1) % f.length];
  }

  String _sessionTitle() {
    const splits = [
      'Upper Push',
      'Pull Day',
      'Leg Day',
      'Upper Pull',
      'Full Body',
      'Conditioning',
      'Active Recovery',
    ];
    return splits[(DateTime.now().weekday - 1) % splits.length];
  }

  Widget _recentScans() {
    final meals = (_data?['recent_meals'] as List?) ?? const [];
    final scans = (_data?['recent_scans'] as List?) ?? const [];
    final meal = meals.isNotEmpty ? meals.first as Map<String, dynamic> : null;
    final scan = scans.isNotEmpty ? scans.first as Map<String, dynamic> : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionLbl('RECENT SCANS'),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalorieScanScreen(),
                    ),
                  ).then((_) {
                    if (mounted) _load();
                  }),
              child: Text(
                'See all',
                style: TextStyle(
                  color: _cCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _scanThumb(
                  icon: Icons.restaurant,
                  tint: _cYellow,
                  title: meal != null
                      ? (meal['food_name'] as String? ?? 'Meal')
                      : 'No meals yet',
                  subtitle: meal != null
                      ? '${(meal['calories'] as num?)?.toInt() ?? 0} kcal'
                      : 'Log a meal',
                  onTap: () =>
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CalorieScanScreen(),
                        ),
                      ).then((_) {
                        if (mounted) _load();
                      }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scanThumb(
                  icon: Icons.accessibility_new,
                  tint: _cPink,
                  title: scan != null
                      ? 'Scan #${scan['number'] ?? ''}'
                      : 'No scans yet',
                  subtitle: scan != null
                      ? '${((scan['body_fat'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}% BF'
                      : 'Scan your body',
                  onTap: () =>
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PhysiqueScanScreen(),
                        ),
                      ).then((_) {
                        if (mounted) _load();
                      }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scanThumb({
    required IconData icon,
    required Color tint,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tint.withValues(alpha: 0.25),
                  AppColors.surfaceElevated,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(icon, color: tint.withValues(alpha: 0.85), size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _motivationBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=900&q=60',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accentMuted, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : Container(color: AppColors.surface),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Let's make today count.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  Widget _buildBigStats() {
    final ts = _data?['today_stats'] as Map<String, dynamic>?;
    final calories = (ts?['calories'] as num?)?.toDouble() ?? 0;
    final calTarget = (ts?['calorie_target'] as num?)?.toDouble() ?? 2200;
    final protein = (ts?['protein'] as num?)?.toDouble() ?? 0;
    final proteinTarget = (ts?['protein_target'] as num?)?.toDouble() ?? 150;
    final sessions = (ts?['sessions'] as int?) ?? 0;
    final streak = (_streak?['current_streak'] as int?) ?? 0;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _bigStatCard(
          Icons.local_fire_department_rounded,
          'CALORIES',
          calories,
          'kcal',
          '/ ${calTarget.toInt()}',
          AppColors.accent,
          _chartValues('daily_calories'),
          highlighted: true,
        ),
        _bigStatCard(
          Icons.bolt_rounded,
          'PROTEIN',
          protein,
          'g',
          '/ ${proteinTarget.toInt()}g',
          _cCyan,
          _chartValues('daily_protein'),
        ),
        _bigStatCard(
          Icons.fitness_center_rounded,
          'WORKOUTS',
          sessions.toDouble(),
          'today',
          '',
          AppColors.accentViolet,
          null,
        ),
        _bigStatCard(
          Icons.whatshot_rounded,
          'STREAK',
          streak.toDouble(),
          'days',
          '',
          AppColors.accentTertiary,
          null,
        ),
      ],
    );
  }

  Widget _bigStatCard(
    IconData icon,
    String label,
    double value,
    String unit,
    String sub,
    Color color,
    List<double>? spark, {
    bool highlighted = false,
  }) {
    final bg = highlighted
        ? LinearGradient(
            colors: [color, color.withValues(alpha: 0.72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [color.withValues(alpha: 0.12), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final textColor = highlighted ? Colors.white : AppColors.textPrimary;
    final mutedColor = highlighted
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.textMuted;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      gradient: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: highlighted ? Colors.white : color, size: 18),
              const Spacer(),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _chartAnim,
            builder: (_, _) => Text(
              '${(value * _chartAnim.value).round()}',
              style: TextStyle(
                color: textColor,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -1.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label · $unit',
            style: TextStyle(
              color: mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          if (spark != null && spark.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 26,
              child: AnimatedBuilder(
                animation: _chartAnim,
                builder: (_, _) => _sparkline(
                  spark,
                  highlighted ? Colors.white : color,
                  _chartAnim.value,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sparkline(List<double> values, Color color, double anim) {
    if (values.isEmpty) return const SizedBox.shrink();
    final n = (values.length * anim).ceil().clamp(1, values.length);
    final vis = values.sublist(0, n);
    final spots = [
      for (var i = 0; i < vis.length; i++) FlSpot(i.toDouble(), vis[i]),
    ];
    final maxY = values.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.15,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.35), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(String title, String id, Color color, {String? forceType}) {
    final chart = _chartById(id);
    if (chart == null) return const SizedBox.shrink();
    final goal = (_data?['goal'] as String?) ?? 'maintain';
    final values =
        (chart['values'] as List?)
            ?.map((v) => (v as num).toDouble())
            .toList() ??
        const [];
    final hasData = values.any((v) => v != 0);
    final type = forceType ?? (chart['type'] as String? ?? 'bar');

    String summary = '';
    if (values.isNotEmpty) {
      final latest = values.last;
      final sum = values.fold(0.0, (a, b) => a + b);
      summary = id == 'bodyweight_trend'
          ? '${latest.toStringAsFixed(1)} kg'
          : (type == 'line' ? '${latest.toInt()}' : '${sum.toInt()} total');
    }

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (summary.isNotEmpty)
                Text(
                  summary,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: AnimatedBuilder(
              animation: _chartAnim,
              builder: (_, _) => hasData
                  ? (type == 'line'
                        ? _lineChart(
                            chart,
                            goal: goal,
                            anim: _chartAnim.value,
                            color: color,
                          )
                        : _barChart(
                            chart,
                            anim: _chartAnim.value,
                            color: color,
                          ))
                  : _emptyChart(chart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieBudgetCard() {
    final ts = _data?['today_stats'] as Map<String, dynamic>?;
    final calories = (ts?['calories'] as num?)?.toDouble() ?? 0;
    final target = (ts?['calorie_target'] as num?)?.toDouble() ?? 2200;
    final remaining = target - calories;
    final pct = target > 0 ? (calories / target).clamp(0.0, 1.0) : 0.0;
    final over = calories > target;
    final ringColor = over ? AppColors.accentTertiary : AppColors.accent;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large_rounded, color: ringColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'CALORIE BUDGET',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _chartAnim,
            builder: (_, _) {
              final a = _chartAnim.value;
              return Row(
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            sectionsSpace: 0,
                            centerSpaceRadius: 44,
                            sections: [
                              PieChartSectionData(
                                value: pct * a,
                                color: ringColor,
                                radius: 13,
                                title: '',
                              ),
                              PieChartSectionData(
                                value: (1 - pct * a).clamp(0.0, 1.0),
                                color: ringColor.withValues(alpha: 0.12),
                                radius: 13,
                                title: '',
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(remaining.abs() * a).toInt()}',
                              style: TextStyle(
                                color: over
                                    ? AppColors.accentTertiary
                                    : AppColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              over ? 'OVER' : 'LEFT',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _macroRow(
                          'Consumed',
                          '${calories.toInt()} kcal',
                          ringColor,
                        ),
                        const SizedBox(height: 10),
                        _macroRow(
                          'Target',
                          '${target.toInt()} kcal',
                          AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        _macroRow(
                          over ? 'Over by' : 'Remaining',
                          '${remaining.abs().toInt()} kcal',
                          over ? AppColors.accentTertiary : AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Skeleton loading ──────────────────────────────────────────────────────

  Widget _buildShimmerSkeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        ShimmerBox(width: double.infinity, height: 44, borderRadius: 10),
        const SizedBox(height: 20),
        ShimmerBox(width: double.infinity, height: 230, borderRadius: 20),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ShimmerBox(
                width: double.infinity,
                height: 140,
                borderRadius: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShimmerBox(
                width: double.infinity,
                height: 140,
                borderRadius: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ShimmerBox(
                width: double.infinity,
                height: 140,
                borderRadius: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShimmerBox(
                width: double.infinity,
                height: 140,
                borderRadius: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ShimmerBox(width: double.infinity, height: 200, borderRadius: 16),
      ],
    );
  }

  // ── Hero Section (The Outsiders inspired) ────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    final g = h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final name = email.contains('@') ? email.split('@')[0] : '';
    return name.isNotEmpty ? '$g, $name' : g;
  }

  Widget _buildHeroCard() {
    final ts = _data?['today_stats'] as Map<String, dynamic>?;
    final calories = (ts?['calories'] as num?)?.toDouble() ?? 0;
    final calTarget = (ts?['calorie_target'] as num?)?.toDouble() ?? 2200;
    final protein = (ts?['protein'] as num?)?.toDouble() ?? 0;
    final protTarget = (ts?['protein_target'] as num?)?.toDouble() ?? 150;
    double volume = (ts?['volume'] as num?)?.toDouble() ?? 0;
    if (volume == 0) volume = _latestChart('weekly_volume');
    double bodyFat = (ts?['body_fat'] as num?)?.toDouble() ?? 0;
    if (bodyFat == 0) bodyFat = _latestChart('body_fat_trend');
    double weightChangeKg = (ts?['weight_change'] as num?)?.toDouble() ?? 0;
    if (weightChangeKg == 0) weightChangeKg = _chartDelta('bodyweight_trend');
    final weightChangeLb = weightChangeKg * 2.20462;
    final calPct = (calTarget > 0 ? calories / calTarget : 0.0).clamp(0.0, 1.0);
    final protPct = (protTarget > 0 ? protein / protTarget : 0.0).clamp(
      0.0,
      1.0,
    );
    final wkGoal = _weeklyGoal <= 0 ? 1 : _weeklyGoal;
    final actPct = (_workoutDaysThisWeek() / wkGoal).clamp(0.0, 1.0);
    final readiness = ((calPct * 0.4 + protPct * 0.35 + actPct * 0.25) * 100)
        .round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF18181D), Color(0xFF0D0D10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SizedBox(
        height: 158,
        child: AnimatedBuilder(
          animation: _chartAnim,
          builder: (_, _) {
            final a = _chartAnim.value;
            final calStr = (calories * a).round().toString().replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+$)'),
              (m) => '${m[1]},',
            );
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _cornerStat(
                        '${(calPct * 100 * a).round()}%',
                        _cCyan,
                        'FUELED',
                        sub: '$calStr kcal',
                      ),
                      _cornerStat(
                        '${(protein * a).toInt()}g',
                        _cGreen,
                        'PROTEIN',
                        sub: 'of ${protTarget.toInt()} g',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(150, 150),
                        painter: _MultiRingPainter(
                          // outer → inner : pink, yellow, cyan (screenshot order)
                          values: [protPct * a, actPct * a, calPct * a],
                          colors: const [_cPink, _cYellow, _cCyan],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(readiness * a).round()}',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -2,
                              shadows: [
                                Shadow(
                                  color: _cBlue.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'READY',
                            style: TextStyle(
                              color: _cBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.5,
                              shadows: [
                                Shadow(
                                  color: _cBlue.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _cornerStat(
                        '${(volume * a).toInt()}',
                        _cYellow,
                        'LOAD',
                        alignEnd: true,
                        sub: _sessionFocus().toLowerCase(),
                      ),
                      _cornerStat(
                        '${bodyFat.toStringAsFixed(1)}%',
                        _cPink,
                        'BODY FAT',
                        alignEnd: true,
                        sub: weightChangeKg == 0
                            ? null
                            : '${weightChangeLb >= 0 ? '+' : ''}${weightChangeLb.toStringAsFixed(1)} lb',
                        subColor: weightChangeLb <= 0 ? _cGreen : _cPink,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _parseWeeklyGoal(String? freq) {
    final f = (freq ?? '').toLowerCase();
    if (f.contains('6') ||
        f.contains('7') ||
        f.contains('daily') ||
        f.contains('every')) {
      return 6;
    }
    if (f.contains('3') || f.contains('4') || f.contains('5')) return 4;
    if (f.contains('1') || f.contains('2')) return 2;
    return 4;
  }

  int _workoutDaysThisWeek() {
    final charts = _data?['charts'] as List? ?? [];
    for (final c in charts) {
      final m = c as Map<String, dynamic>;
      if (m['id'] == 'daily_workouts') {
        final vals =
            (m['values'] as List?)
                ?.map((v) => (v as num).toDouble())
                .toList() ??
            const [];
        final week = vals.length > 7 ? vals.sublist(vals.length - 7) : vals;
        return week.where((v) => v > 0).length;
      }
    }
    final s =
        ((_data?['today_stats'] as Map<String, dynamic>?)?['sessions']
            as int?) ??
        0;
    return s > 0 ? 1 : 0;
  }

  Widget _buildAtRiskBanner(int streak) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade800, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Don't break your streak! $streak days strong — log something today",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _bannerDismissed = true),
          ),
        ],
      ),
    );
  }

  // ── Weight Log Card ───────────────────────────────────────────────────────

  Widget _weightLogCard() {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Today's Weight",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_loggedToday)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Logged today: ${_todayWeight?.toStringAsFixed(1) ?? '--'} kg',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _loggedToday = false),
                  child: const Text(
                    'Edit',
                    style: TextStyle(color: AppColors.accent),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: 'e.g. 75.5',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: (_savingWeight || _weightSaved) ? null : _logWeight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 64,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _weightSaved ? Colors.green : AppColors.accent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: _savingWeight
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : _weightSaved
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                          : const Text(
                              'Log',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Muscle Balance Radar ──────────────────────────────────────────────────

  Widget _buildMuscleBalanceCard() {
    final groups = _muscleData?['groups'] as Map<String, dynamic>? ?? {};
    final maxVal = groups.values
        .map((v) => (v as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.radar, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Muscle Balance (30 days)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    dataEntries: _muscleOrder
                        .map(
                          (k) => RadarEntry(
                            value: (groups[k] as num?)?.toDouble() ?? 0,
                          ),
                        )
                        .toList(),
                    fillColor: AppColors.accent.withValues(alpha: 0.15),
                    borderColor: AppColors.accent,
                    borderWidth: 2,
                    entryRadius: 4,
                  ),
                ],
                radarBorderData: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                tickBorderData: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.2),
                ),
                gridBorderData: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.3),
                ),
                ticksTextStyle: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 0,
                ),
                tickCount: 4,
                radarBackgroundColor: Colors.transparent,
                getTitle: (index, _) => RadarChartTitle(
                  text: _muscleOrder[index].toUpperCase(),
                  positionPercentageOffset: 0.12,
                ),
                titleTextStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Summary Card ───────────────────────────────────────────────────────

  Widget _buildAiSummaryCard() {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple.shade300, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Weekly Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingAiSummary)
            Column(
              children: [
                ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
                const SizedBox(height: 6),
                ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
                const SizedBox(height: 6),
                ShimmerBox(width: 200, height: 14, borderRadius: 4),
              ],
            )
          else if (_aiSummary != null)
            Text(
              _aiSummary!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            )
          else
            Text(
              'Log workouts and meals to get your personalised weekly summary.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Powered by Gemini AI',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggested Actions ─────────────────────────────────────────────────────

  Widget _buildSuggestedActions() {
    final todayStats = _data?['today_stats'] as Map<String, dynamic>?;
    final calories = (todayStats?['calories'] as num?)?.toDouble() ?? 0;
    final calorieTarget =
        (todayStats?['calorie_target'] as num?)?.toDouble() ?? 2200;
    final sessions = (todayStats?['sessions'] as int?) ?? 0;
    final h = DateTime.now().hour;

    final actions =
        <
          ({
            IconData icon,
            String label,
            String sub,
            Color color,
            VoidCallback onTap,
          })
        >[];

    void goCalories() =>
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CalorieScanScreen()),
        ).then((_) {
          if (mounted) _load();
        });
    void goWorkout() =>
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogWorkoutScreen()),
        ).then((_) {
          if (mounted) _load();
        });

    if (sessions == 0) {
      actions.add((
        icon: Icons.fitness_center,
        label: 'Log Workout',
        sub: 'No workout yet today',
        color: AppColors.accent,
        onTap: goWorkout,
      ));
    }
    if (calories < 200 && h >= 6 && h < 11) {
      actions.add((
        icon: Icons.wb_sunny_outlined,
        label: 'Log Breakfast',
        sub: 'Start your nutrition',
        color: Colors.amber,
        onTap: goCalories,
      ));
    } else if (calories < 600 && h >= 11 && h < 15) {
      actions.add((
        icon: Icons.restaurant_outlined,
        label: 'Log Lunch',
        sub: 'Keep fuelling up',
        color: Colors.green,
        onTap: goCalories,
      ));
    } else if (calories < calorieTarget * 0.7 && h >= 17) {
      actions.add((
        icon: Icons.dinner_dining,
        label: 'Log Dinner',
        sub: '${(calorieTarget - calories).toInt()} kcal remaining',
        color: Colors.orange,
        onTap: goCalories,
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...actions.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: a.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: a.color,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(a.icon, color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            a.label,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            a.sub,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Macros Pie Chart ──────────────────────────────────────────────────────

  Widget _buildMacrosPieCard() {
    final todayStats = _data?['today_stats'] as Map<String, dynamic>?;
    final protein = (todayStats?['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (todayStats?['carbs'] as num?)?.toDouble() ?? 0;
    final fat = (todayStats?['fat'] as num?)?.toDouble() ?? 0;
    final total = protein + carbs + fat;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart_outline,
                color: AppColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                "Today's Macros",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (total < 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Log your first meal to see macro breakdown',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            AnimatedBuilder(
              animation: _chartAnim,
              builder: (_, _) {
                final anim = _chartAnim.value;
                return Row(
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 3,
                          centerSpaceRadius: 40,
                          sections: [
                            PieChartSectionData(
                              value: protein * 4 * anim,
                              color: AppColors.ringExercise,
                              radius: 32,
                              title: '',
                            ),
                            PieChartSectionData(
                              value: carbs * 4 * anim,
                              color: Colors.amber,
                              radius: 32,
                              title: '',
                            ),
                            PieChartSectionData(
                              value: fat * 9 * anim,
                              color: Colors.orange,
                              radius: 32,
                              title: '',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _macroRow(
                            'Protein',
                            '${protein.toInt()}g',
                            AppColors.ringExercise,
                          ),
                          const SizedBox(height: 10),
                          _macroRow('Carbs', '${carbs.toInt()}g', Colors.amber),
                          const SizedBox(height: 10),
                          _macroRow('Fat', '${fat.toInt()}g', Colors.orange),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _macroRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Training Load Calendar ────────────────────────────────────────────────

  Widget _buildTrainingCalendar() {
    final weekly =
        (_streak?['weekly_activity'] as List?)
            ?.map((e) => e as bool)
            .toList() ??
        List.filled(7, false);
    final today = DateTime.now().weekday - 1; // 0=Mon

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                color: AppColors.accent.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'This Week',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isToday = i == today;
              final active = i < weekly.length ? weekly[i] : false;
              final isFuture = i > today;
              Color dotColor;
              if (active) {
                dotColor = AppColors.accent;
              } else if (isToday) {
                dotColor = Colors.amber;
              } else if (isFuture) {
                dotColor = AppColors.border;
              } else {
                dotColor = Colors.red.withValues(alpha: 0.7);
              }

              final dot = Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isFuture
                      ? Colors.transparent
                      : dotColor.withValues(
                          alpha: active ? 0.18 : (isToday ? 0.15 : 0.1),
                        ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFuture
                        ? AppColors.border.withValues(alpha: 0.2)
                        : dotColor.withValues(alpha: isToday ? 0.9 : 0.5),
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: active
                    ? Icon(Icons.check, size: 16, color: AppColors.accent)
                    : isToday && !active
                    ? Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.amber.withValues(alpha: 0.8),
                      )
                    : null,
              );

              return Column(
                children: [
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  isToday && !active
                      ? AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, child) => Transform.scale(
                            scale: _pulseScale.value,
                            child: child,
                          ),
                          child: dot,
                        )
                      : dot,
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _calendarLegend(AppColors.accent, 'Trained'),
              const SizedBox(width: 16),
              _calendarLegend(Colors.amber, 'Today'),
              const SizedBox(width: 16),
              _calendarLegend(Colors.red.withValues(alpha: 0.7), 'Missed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Charts ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _ghostChart(Map<String, dynamic> chart) {
    final isLine = (chart['type'] as String?) == 'line';
    final ghostVals = isLine
        ? [65.0, 64.5, 64.8, 64.2, 63.9, 64.1, 63.7]
        : [30.0, 50.0, 20.0, 70.0, 40.0, 60.0, 45.0];
    return {
      ...chart,
      'labels': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      'values': ghostVals,
    };
  }

  Widget _emptyChart(Map<String, dynamic> chart) {
    final isLine = (chart['type'] as String?) == 'line';
    return Stack(
      children: [
        Opacity(
          opacity: 0.12,
          child: isLine
              ? _lineChart(_ghostChart(chart), goal: 'maintain', anim: 1.0)
              : _barChart(_ghostChart(chart), anim: 1.0),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLine ? Icons.show_chart : Icons.bar_chart,
                color: AppColors.textMuted,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your first workout to see your progress',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barChart(
    Map<String, dynamic> chart, {
    double anim = 1.0,
    Color? color,
  }) {
    final c = color ?? AppColors.accent;
    final labels = (chart['labels'] as List?)?.cast<String>() ?? [];
    final values =
        (chart['values'] as List?)
            ?.map((v) => (v as num).toDouble())
            .toList() ??
        [];
    if (values.isEmpty) return const SizedBox.shrink();
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final count = values.length;
    final step = count > 0 ? 1.0 / count : 1.0;

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              rod.toY.toStringAsFixed(
                rod.toY == rod.toY.floorToDouble() ? 0 : 1,
              ),
              TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (i, _) {
                final index = i.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(values.length, (i) {
          final barAnim = CurvedAnimation(
            parent: AlwaysStoppedAnimation(anim),
            curve: Interval(
              i * step,
              (i * step + step).clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ),
          ).value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i] * barAnim,
                gradient: LinearGradient(
                  colors: [c, c.withValues(alpha: 0.5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _lineChart(
    Map<String, dynamic> chart, {
    required String goal,
    double anim = 1.0,
    Color? color,
  }) {
    final labels = (chart['labels'] as List?)?.cast<String>() ?? [];
    final values =
        (chart['values'] as List?)
            ?.map((v) => (v as num).toDouble())
            .toList() ??
        [];
    if (values.isEmpty) return const SizedBox.shrink();

    final visibleCount = (values.length * anim).ceil().clamp(1, values.length);
    final visibleValues = values.sublist(0, visibleCount);
    final spots = List.generate(
      visibleValues.length,
      (i) => FlSpot(i.toDouble(), visibleValues[i]),
    );

    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);

    Color lineColor = color ?? AppColors.accent;
    if (color == null &&
        (chart['id'] as String?) == 'bodyweight_trend' &&
        values.length >= 2) {
      final trending = values.last > values.first;
      final good = (goal == 'bulk') ? trending : !trending;
      lineColor = good ? AppColors.success : AppColors.error;
    }

    return AnimatedBuilder(
      animation: _dotPulseCtrl,
      builder: (_, _) => LineChart(
        LineChartData(
          minY: minY > 0 ? minY * 0.95 : 0,
          maxY: maxY <= 0 ? 10 : maxY * 1.05,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      s.y.toStringAsFixed(s.y == s.y.floorToDouble() ? 0 : 1),
                      TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (i, _) {
                  final index = i.toInt();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: lineColor,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: _dotRadius.value,
                  color: lineColor,
                  strokeWidth: 2,
                  strokeColor: AppColors.background,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    lineColor.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
