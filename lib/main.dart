import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'screens/today_screen.dart' show TodayScreen;
import 'login_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/body/body_screen.dart';
import 'screens/scan/scan_tab_screen.dart';
import 'services/app_state_service.dart';
import 'services/auth_links.dart';
import 'services/error_reporter.dart';
import 'services/nav_service.dart';
import 'services/today_cache.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/workouts/workouts_tab_screen.dart';

void main() {
  // runZonedGuarded so an async error thrown outside a widget callback is
  // caught too — otherwise it reaches the platform and takes the app down
  // with nothing recorded about why.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        ErrorReporter.report(
          details.exception,
          stack: details.stack,
          context: 'flutter:${details.library ?? 'widgets'}',
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        ErrorReporter.report(error, stack: stack, context: 'platform');
        return true;
      };
      // A framework error normally paints the grey/red error box. Users read
      // that as "the app is broken"; this at least says so in the app's own
      // voice.
      ErrorWidget.builder = (details) => const _AppErrorBox();

      await ThemeController.load();
      await Supabase.initialize(
        url: 'https://jfopizywtgaqhkbkjlyz.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impmb3Bpenl3dGdhcWhrYmtqbHl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNDU0NTYsImV4cCI6MjA5MDcyMTQ1Nn0.Y2CbDOSoVA3AP8E6JZJ0Vi6p1LE8U4WO87PXAkRQIOk',
      );
      // Onboarding state used to be stored device-wide; drop those keys so a
      // new account on this device is gated on its own (per-user) flag.
      await AppStateService.clearLegacyOnboardingState();

      // Wake the backend while the user is still on the login/onboarding
      // screen. The host sleeps when idle, and a cold start on the first real
      // request otherwise lands as a ~50s wait on a spinner.
      unawaited(warmUpBackend());

      _watchVerificationLinks();

      runApp(const MyApp());
    },
    (error, stack) =>
        ErrorReporter.report(error, stack: stack, context: 'uncaught'),
  );
}

/// App-level messenger, so a snackbar raised while the auth state is
/// changing survives the route swap that follows it. A screen-level
/// ScaffoldMessenger would be torn down mid-animation and show nothing.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Reports the outcome of tapping a verification link.
///
/// supabase_flutter already consumes the link and turns its tokens into a
/// session, and AppBootstrap routes onward the moment that lands — so the
/// user is signed in without doing anything. What it does not do is say why
/// the app suddenly opened logged in, or explain a link that carried an
/// error instead of tokens. That is all this adds.
void _watchVerificationLinks() {
  final links = AppLinks();

  void handle(Uri uri) {
    if (!isEmailVerificationLink(uri)) return;

    final error = verificationLinkError(uri);
    // The session arrives asynchronously, so give Supabase a moment to
    // process the same link before deciding what to tell the user.
    Future.delayed(const Duration(milliseconds: 600), () {
      final signedIn = Supabase.instance.client.auth.currentSession != null;
      final messenger = appMessengerKey.currentState;
      if (messenger == null) return;

      final String text;
      if (error != null) {
        text = error;
      } else if (signedIn) {
        text = 'Email verified — you\'re signed in.';
      } else {
        // Link looked valid but produced no session: usually already used.
        text = 'Email verified. Please log in to continue.';
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(text),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    });
  }

  // Cold start: the link that launched the app.
  unawaited(
    links
        .getInitialLink()
        .then((uri) {
          if (uri != null) handle(uri);
        })
        .catchError((Object e, StackTrace s) {
          ErrorReporter.report(e, stack: s, context: 'initialAuthLink');
        }),
  );

  // Warm start: the app was already running and got the link via onNewIntent.
  links.uriLinkStream.listen(
    handle,
    onError: (Object e, StackTrace s) =>
        ErrorReporter.report(e, stack: s, context: 'authLinkStream'),
  );
}

/// Shown in place of the framework's grey error box.
class _AppErrorBox extends StatelessWidget {
  const _AppErrorBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Text(
        "Something went wrong here.\nPull to refresh, or reopen the app.",
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        // Tokens (kBgCard, kTextPrimary, …) resolve through this, so it must
        // be set before any themed widget builds.
        AppColors.brightness = mode == ThemeMode.light
            ? Brightness.light
            : Brightness.dark;
        return MaterialApp(
          title: 'Physiqo AI',
          scaffoldMessengerKey: appMessengerKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const AppBootstrap(),
        );
      },
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
        if (session == null) {
          // Drop the previous user's in-memory state the moment they sign
          // out, rather than waiting for the next screen to notice.
          TodayCache.reset();
          return const LoginScreen();
        }
        // Keyed by user id so switching accounts tears down the old gate state
        // instead of reusing the previous user's "already onboarded" answer.
        return _OnboardingGate(key: ValueKey(session.user.id));
      },
    );
  }
}

// After auth, check whether onboarding is needed.
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate({super.key});

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
    // Fast path: local flag, set per account on this device
    if (await AppStateService.isOnboardingComplete()) {
      if (mounted) setState(() => _onboardingDone = true);
      return;
    }
    // Reinstall / new device: check if this account already answered onboarding.
    // A bare row isn't enough — other screens can create one — so require a
    // field only onboarding fills in.
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      try {
        final row = await Supabase.instance.client
            .from('user_profiles')
            .select('id, goal, age')
            .eq('id', uid)
            .maybeSingle();
        if (row != null && row['goal'] != null && row['age'] != null) {
          await AppStateService.markOnboardingComplete();
          if (mounted) setState(() => _onboardingDone = true);
          return;
        }
      } catch (e, s) {
        // Falls through to showing onboarding. Worth recording: if this is
        // failing, returning users get sent back through onboarding.
        ErrorReporter.report(e, stack: s, context: 'onboardingGate');
      }
    }
    if (mounted) setState(() => _onboardingDone = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_onboardingDone!) {
      return OnboardingFlow(
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

  // Deliberately NOT const: a const list hands the framework identical widget
  // instances, which short-circuits the rebuild — so a live theme flip would
  // leave whichever tab is showing painted in the old palette.
  List<Widget> get screens => [
    const TodayScreen(),
    const ScanTabScreen(),
    const BodyScreen(),
    const WorkoutsTabScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _syncOnboardingProfile();
    mainTabIndex.addListener(_onTabRequest);
    // The nav bar reads AppColors directly, so a theme flip must re-run build.
    ThemeController.mode.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onTabRequest);
    ThemeController.mode.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
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
      (
        Icons.center_focus_weak_rounded,
        Icons.center_focus_strong_rounded,
        'SCAN',
      ),
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
                          boxShadow: [BoxShadow(color: accent, blurRadius: 8)],
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(navItems.length, (index) {
                        final item = navItems[index];
                        final isSelected = index == currentIndex;
                        final color = isSelected ? accent : AppColors.textMuted;
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
