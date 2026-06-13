import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final _weightController = TextEditingController();
  bool _savingWeight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await getDashboard();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      _error = data == null ? 'Could not load dashboard data' : null;
    });
  }

  Future<void> _logWeight() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) return;
    setState(() => _savingWeight = true);
    final ok = await logBodyweight(weight);
    if (!mounted) return;
    setState(() => _savingWeight = false);
    if (ok) {
      _weightController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight logged')),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.accent,
          child: _loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [
                              AppColors.textPrimary,
                              AppColors.textSecondary,
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _goalLabel(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _weightLogCard(),
                    const SizedBox(height: 16),
                    if (_error != null)
                      AppCard(
                        margin: EdgeInsets.zero,
                        child: Text(_error!, textAlign: TextAlign.center),
                      )
                    else if (_data != null)
                      ..._buildCharts(),
                  ],
                ),
        ),
      ),
    );
  }

  String _goalLabel() {
    final goal = (_data?['goal'] as String?) ?? 'maintain';
    switch (goal) {
      case 'bulk':
        return 'Goal: Bulk / Weight Gain';
      case 'cut':
        return 'Goal: Cut / Lose Weight';
      case 'athletic':
        return 'Goal: Athletic Performance';
      default:
        return 'Goal: Maintain';
    }
  }

  Widget _weightLogCard() {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Log Today\'s Weight',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'e.g. 75.5',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _savingWeight ? null : _logWeight,
                child: Text(_savingWeight ? '...' : 'Log'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCharts() {
    final charts = _data!['charts'] as List<dynamic>? ?? [];
    return charts.map((c) {
      final chart = c as Map<String, dynamic>;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chart['title'] as String? ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: (chart['type'] as String?) == 'line'
                    ? _lineChart(chart)
                    : _barChart(chart),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _barChart(Map<String, dynamic> chart) {
    final labels = (chart['labels'] as List?)?.cast<String>() ?? [];
    final values = (chart['values'] as List?)
            ?.map((v) => (v as num).toDouble())
            .toList() ??
        [];
    if (values.isEmpty) {
      return const Center(child: Text('No data yet'));
    }
    final maxY = values.reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
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
                    style: const TextStyle(
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
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: AppColors.accent,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _lineChart(Map<String, dynamic> chart) {
    final labels = (chart['labels'] as List?)?.cast<String>() ?? [];
    final values = (chart['values'] as List?)
            ?.map((v) => (v as num).toDouble())
            .toList() ??
        [];
    if (values.isEmpty) {
      return const Center(child: Text('No data yet'));
    }
    final spots = List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: minY > 0 ? minY * 0.9 : 0,
        maxY: maxY <= 0 ? 10 : maxY * 1.1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
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
                    style: const TextStyle(
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
            color: AppColors.accent,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
