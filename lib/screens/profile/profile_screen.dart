import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_state_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../paywall/paywall_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _onboarding;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await AppStateService.getOnboardingData();
    if (!mounted) return;
    setState(() => _onboarding = data?.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? (AppStateService.isGuestMode ? 'Guest' : 'Not signed in');
    final fitnessLevel = _onboarding?['fitness_level'] as String?;
    final goal = _onboarding?['goal'] as String?;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Profile',
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
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile Card with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.12),
                            AppColors.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Avatar with glow
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent.withValues(alpha: 0.3),
                                  AppColors.accent.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: AppColors.accent,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    fitnessLevel != null
                                        ? '$fitnessLevel • ${goal ?? 'Fitness'}'
                                        : 'Complete your profile',
                                    style: TextStyle(
                                      color: fitnessLevel != null
                                          ? AppColors.accent
                                          : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Stats Row
                    if (_onboarding != null) ...[
                      Row(
                        children: [
                          _buildMiniStat(
                            icon: Icons.straighten,
                            value: _onboarding!['height_cm'] != null
                                ? '${(_onboarding!['height_cm'] as num).toInt()}'
                                : '--',
                            label: 'Height (cm)',
                          ),
                          const SizedBox(width: 12),
                          _buildMiniStat(
                            icon: Icons.monitor_weight_outlined,
                            value: _onboarding!['weight_kg'] != null
                                ? '${(_onboarding!['weight_kg'] as num).toInt()}'
                                : '--',
                            label: 'Weight (kg)',
                          ),
                          const SizedBox(width: 12),
                          _buildMiniStat(
                            icon: Icons.cake_outlined,
                            value: _onboarding!['age'] != null
                                ? '${_onboarding!['age']}'
                                : '--',
                            label: 'Age',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Your Plan Card
                    if (_onboarding != null) ...[
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.surface, AppColors.background],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.fitness_center_outlined,
                                    size: 18, color: AppColors.accent),
                                const SizedBox(width: 8),
                                const Text(
                                  'Your Plan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _planRow('Goal', _onboarding!['goal']),
                            _planRow('Equipment', _onboarding!['equipment']),
                            _planRow('Frequency', _onboarding!['workout_frequency']),
                            _planRow('Fitness Level', _onboarding!['fitness_level']),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Actions
                    FeatureHubTile(
                      title: 'Upgrade to Pro',
                      subtitle: 'Unlock all AI features',
                      icon: Icons.workspace_premium,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaywallScreen(onComplete: () {
                            Navigator.pop(context);
                          }),
                        ),
                      ),
                    ),
                    FeatureHubTile(
                      title: 'Sign Out',
                      subtitle: 'Log out of your account',
                      icon: Icons.logout,
                      accentColor: AppColors.error,
                      onTap: () async {
                        AppStateService.setGuestMode(false);
                        await Supabase.instance.client.auth.signOut();
                      },
                    ),
                  ],
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

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              AppColors.surface.withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _planRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
