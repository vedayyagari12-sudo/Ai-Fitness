import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const stepChart = [0.3, 0.5, 0.7, 0.4, 0.9, 0.6, 0.8];
    const distChart = [0.2, 0.4, 0.6, 0.5, 0.7, 0.3, 0.9];
    const calorieHistory = [380.0, 450.0, 310.0, 620.0, 480.0, 720.0, 580.0];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            foreground: Paint()
                              ..shader = const LinearGradient(
                                colors: [AppColors.textPrimary, AppColors.textSecondary],
                              ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'YOUR ACTIVITY TODAY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: const Icon(Icons.person_outline, size: 22, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),

            // Lifetime Stats Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildLifetimeCard(
                        title: 'Workouts',
                        value: '42',
                        icon: Icons.fitness_center_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLifetimeCard(
                        title: 'Calories',
                        value: '18,450',
                        unit: 'kcal',
                        icon: Icons.local_fire_department_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLifetimeCard(
                        title: 'Active Min',
                        value: '1,280',
                        unit: 'm',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Activity Ring Section with Ambient Glow
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient background radial glow (Electric Blue/Pink tint)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              blurRadius: 80,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                      ),
                      ActivityRing(
                        label: 'Move',
                        current: 46,
                        goal: 250,
                        color: AppColors.ringMove,
                        size: 190,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Weekly Calorie Burn Line Graph
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.surface, AppColors.background],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.show_chart_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Weekly Calorie Burn',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Avg: 480 kcal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const PremiumLineChart(
                        values: calorieHistory,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Stat Cards Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildListDelegate([
                  _buildStatCard(
                    title: 'Step Count',
                    value: '1,552',
                    unit: 'steps',
                    chart: const MiniBarChart(values: stepChart, barColor: AppColors.ringExercise),
                  ),
                  _buildStatCard(
                    title: 'Step Distance',
                    value: '0.69',
                    unit: 'MI',
                    chart: const MiniBarChart(values: distChart, barColor: AppColors.ringStand),
                  ),
                ]),
              ),
            ),

            // Sessions and Awards
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildListDelegate([
                  _buildStatCard(
                    title: 'Sessions',
                    value: '4',
                    unit: 'this week',
                    icon: Icons.calendar_today_outlined,
                    iconColor: AppColors.accent,
                  ),
                  _buildStatCard(
                    title: 'Awards',
                    value: '2',
                    unit: 'earned',
                    icon: Icons.emoji_events_outlined,
                    iconColor: Colors.amber,
                  ),
                ]),
              ),
            ),

            // Weekly Overview Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.insights_outlined, size: 20, color: AppColors.accent),
                            const SizedBox(width: 8),
                            const Text(
                              'Weekly Overview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Text(
                            'Easy to understand at a glance',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniRing('Exercise', 12, 30, AppColors.ringExercise, '40%'),
                            _miniRing('Stand', 8, 12, AppColors.ringStand, '66%'),
                            _miniRing('Move', 46, 250, AppColors.ringMove, '18%'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLifetimeCard({
    required String title,
    required String value,
    String? unit,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.surface.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    Widget? chart,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (icon != null)
                Icon(icon, size: 18, color: iconColor ?? AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (chart != null) ...[
            const Spacer(),
            chart,
          ],
        ],
      ),
    );
  }

  Widget _miniRing(String label, double current, double goal, Color color, String percent) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ActivityRing(
              label: '',
              current: current,
              goal: goal,
              color: color,
              size: 76,
            ),
            Text(
              percent,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class PremiumLineChart extends StatelessWidget {
  const PremiumLineChart({super.key, required this.values, this.color = AppColors.accent});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(values: values, color: color),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days
              .map((d) => Text(
                    d,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final width = size.width;
    final height = size.height;

    // Grid lines
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw 3 horizontal grid lines
    for (int i = 1; i <= 3; i++) {
      final y = height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    final maxVal = values.reduce(math.max);
    final minVal = values.reduce(math.min);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final points = <Offset>[];
    final stepX = width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final ratio = (values[i] - minVal) / range;
      final y = height - 10 - (ratio * (height - 20));
      points.add(Offset(x, y));
    }

    // Draw smooth cubic path
    final linePath = Path();
    final fillPath = Path();

    linePath.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;

      linePath.cubicTo(
        controlPointX, p0.dy,
        controlPointX, p1.dy,
        p1.dx, p1.dy,
      );
      fillPath.cubicTo(
        controlPointX, p0.dy,
        controlPointX, p1.dy,
        p1.dx, p1.dy,
      );
    }

    fillPath.lineTo(width, height);
    fillPath.close();

    // Fill shader
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.3), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    // Line paint
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw paths
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    // Draw dots at data points
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final outerDotPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;

    for (final pt in points) {
      canvas.drawCircle(pt, 5.0, dotPaint);
      canvas.drawCircle(pt, 2.5, outerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values || old.color != color;
}
