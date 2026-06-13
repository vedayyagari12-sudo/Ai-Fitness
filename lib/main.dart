import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/workouts/workouts_hub_screen.dart';
import 'api_service.dart';
import 'services/app_state_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://jfopizywtgaqhkbkjlyz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impmb3Bpenl3dGdhcWhrYmtqbHl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNDU0NTYsImV4cCI6MjA5MDcyMTQ1Nn0.Y2CbDOSoVA3AP8E6JZJ0Vi6p1LE8U4WO87PXAkRQIOk',
  );
  await _initRevenueCat();
  runApp(const MyApp());
}

Future<void> _initRevenueCat() async {
  try {
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration('YOUR_REVENUECAT_API_KEY'),
    );
  } catch (_) {
    // RevenueCat keys are configured per platform before release.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Fitness',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _loading = true;
  bool _onboardingComplete = false;

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    final done = await AppStateService.isOnboardingComplete();
    if (!mounted) return;
    setState(() {
      _onboardingComplete = done;
      _loading = false;
    });
  }

  void _onOnboardingDone() {
    setState(() => _onboardingComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_onboardingComplete) {
      return OnboardingFlow(onComplete: _onOnboardingDone);
    }
    return const AuthGate();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null || AppStateService.isGuestMode) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
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
    DashboardScreen(),
    WorkoutsHubScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _syncOnboardingProfile();
  }

  Future<void> _syncOnboardingProfile() async {
    final data = await AppStateService.getOnboardingData();
    if (data != null) {
      await syncOnboardingToProfile(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = [
      (Icons.home_outlined, Icons.home, 'Dashboard'),
      (Icons.fitness_center_outlined, Icons.fitness_center, 'Workouts'),
      (Icons.person_outline, Icons.person, 'Profile'),
    ];

    return Scaffold(
      extendBody: true, // Scroll content behind bottom navigation bar
      body: screens[currentIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final itemWidth = width / 3;
                    return Stack(
                      children: [
                        // Animated sliding pill background
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack, // slight overshoot for physical premium feel
                          left: currentIndex * itemWidth,
                          top: 8,
                          bottom: 8,
                          width: itemWidth,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent.withValues(alpha: 0.16),
                                  AppColors.accent.withValues(alpha: 0.04),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.25),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                        
                        // Tab items
                        Row(
                          children: List.generate(navItems.length, (index) {
                            final item = navItems[index];
                            final isSelected = index == currentIndex;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => currentIndex = index),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        isSelected ? item.$2 : item.$1,
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.$3,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
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
        ),
      ),
    );
  }
}
