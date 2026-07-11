import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'screens/today_screen.dart' show TodayScreen;
import 'login_screen.dart';
import 'screens/onboarding/goal_picker_screen.dart';
import 'screens/body/body_screen.dart';
import 'screens/scan/scan_tab_screen.dart';
import 'services/app_state_service.dart';
import 'services/nav_service.dart';
import 'theme/app_theme.dart';
import 'screens/workouts/workouts_tab_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://jfopizywtgaqhkbkjlyz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impmb3Bpenl3dGdhcWhrYmtqbHl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNDU0NTYsImV4cCI6MjA5MDcyMTQ1Nn0.Y2CbDOSoVA3AP8E6JZJ0Vi6p1LE8U4WO87PXAkRQIOk',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dark-only: the design system is built for a near-black canvas.
    AppColors.brightness = Brightness.dark;
    return MaterialApp(
      title: 'FitAI',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AppBootstrap(),
    );
  }
}

// Auth stream comes first — no onboarding before login.
class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data?.session;
        if (session == null) return const LoginScreen();
        return const _OnboardingGate();
      },
    );
  }
}

// After auth, check whether onboarding is needed.
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Fast path: local flag set on this device
    if (await AppStateService.isOnboardingComplete()) {
      if (mounted) setState(() => _onboardingDone = true);
      return;
    }
    // Reinstall / new device: check if profile exists in Supabase
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      try {
        final row = await Supabase.instance.client
            .from('user_profiles')
            .select('id')
            .eq('id', uid)
            .maybeSingle();
        if (row != null) {
          await AppStateService.markOnboardingComplete();
          if (mounted) setState(() => _onboardingDone = true);
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _onboardingDone = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_onboardingDone!) {
      return GoalPickerScreen(
        onComplete: () => setState(() => _onboardingDone = true),
      );
    }
    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final screens = const [
    TodayScreen(),
    ScanTabScreen(),
    BodyScreen(),
    WorkoutsTabScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _syncOnboardingProfile();
    mainTabIndex.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final index = mainTabIndex.value;
    if (index != currentIndex && mounted) {
      if (index == 0) triggerTodayRefresh();
      setState(() => currentIndex = index);
    }
  }

  Future<void> _syncOnboardingProfile() async {
    final data = await AppStateService.getOnboardingData();
    if (data != null) {
      await syncOnboardingToProfile(data);
    }
  }

  // Each tab owns an accent colour (matches the reference design):
  // TODAY lime · SCAN blue · BODY pink · TRAIN cyan.
  static const tabAccents = [kLime, kBlue, kPink, kCyan];

  @override
  Widget build(BuildContext context) {
    final navItems = [
      (Icons.home_outlined, Icons.home_rounded, 'TODAY'),
      (Icons.center_focus_weak_rounded, Icons.center_focus_strong_rounded, 'SCAN'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'BODY'),
      (Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'TRAIN'),
    ];
    final accent = tabAccents[currentIndex];

    return Scaffold(
      extendBody: true,
      body: screens[currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / navItems.length;
                return Stack(
                  children: [
                    // Active indicator — thin accent bar under the selected tab
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      left: currentIndex * itemWidth + itemWidth / 2 - 14,
                      top: 0,
                      width: 28,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(2),
                          ),
                          boxShadow: [
                            BoxShadow(color: accent, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(navItems.length, (index) {
                        final item = navItems[index];
                        final isSelected = index == currentIndex;
                        final color =
                            isSelected ? accent : AppColors.textMuted;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Refresh dashboard when switching back to it
                              if (index == 0 && currentIndex != 0) {
                                triggerTodayRefresh();
                              }
                              mainTabIndex.value = index;
                              setState(() => currentIndex = index);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSelected ? item.$2 : item.$1,
                                  color: color,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.$3,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
