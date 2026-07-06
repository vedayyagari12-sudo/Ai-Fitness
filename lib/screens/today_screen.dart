import 'package:flutter/material.dart';

import '../services/readiness_service.dart';
import '../theme/app_theme.dart';
import '../widgets/physique_mini_card.dart';
import '../widgets/readiness_card.dart';
import '../widgets/recent_scan_thumb.dart';
import '../widgets/section_label.dart';
import '../widgets/streak_chip.dart';
import '../widgets/today_session_card.dart';
import '../widgets/trend_card.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _navIndex = 0;
  final _readiness = const ReadinessService().getToday();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _header(),
            const SizedBox(height: 16),
            ReadinessCard(data: _readiness),
            const SizedBox(height: 12),
            const TrendCard(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(child: PhysiqueMiniCard()),
                SizedBox(width: 12),
                Expanded(child: TodaySessionCard()),
              ],
            ),
            const SizedBox(height: 16),
            const SectionLabel('RECENT SCANS', trailing: 'See all'),
            const SizedBox(height: 8),
            _recentScans(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        backgroundColor: kBgCard,
        selectedItemColor: kCyan,
        unselectedItemColor: kTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'TODAY'),
          BottomNavigationBarItem(
            icon: Icon(Icons.center_focus_strong),
            label: 'SCAN',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'BODY'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'TRAIN',
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SAT · JUN 21', style: kLabelSmall),
            Text('Good morning, Alex', style: kHeadlineMedium),
          ],
        ),
        Row(
          children: [
            const StreakChip(count: 12, isKeptToday: true),
            const SizedBox(width: 8),
            const CircleAvatar(radius: 16, backgroundColor: kBgElevated),
          ],
        ),
      ],
    );
  }

  Widget _recentScans() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => i == 0
            ? const RecentScanThumb(
                title: 'Chicken Bowl',
                subtitle: '642 kcal',
                tag: 'meal',
              )
            : const RecentScanThumb(
                title: 'Scan #14',
                subtitle: '18.2% BF',
                tag: 'body',
              ),
      ),
    );
  }
}
