import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../services/app_state_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _purchasing = false;
  List<Package> _packages = [];
  String? _error;
  late final AnimationController _shimmerCtrl;

  static const _features = [
    (
      'AI Workout Generator',
      'Custom plans tailored to your body',
      Icons.bolt
    ),
    (
      'Calorie & Physique Scan',
      'Snap food and track your body changes',
      Icons.camera_alt_outlined
    ),
    (
      'Unlimited History',
      'Review all past sessions and progress',
      Icons.history
    ),
    (
      'Advanced Stats & Insights',
      'Deep analytics on your performance',
      Icons.insights
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadOfferings();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOfferings() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final offerings = await Purchases.getOfferings();
      if (!mounted) return;
      setState(() {
        _packages = offerings.current?.availablePackages ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'RevenueCat not configured yet';
        _loading = false;
      });
    }
  }

  Future<void> _purchase(Package? package) async {
    if (package == null) {
      await _skip();
      return;
    }
    setState(() => _purchasing = true);
    try {
      await Purchases.purchasePackage(package);
      await AppStateService.markPaywallSeen();
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Purchase cancelled or failed');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _skip() async {
    await AppStateService.markPaywallSeen();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _packages.isNotEmpty ? _packages.first : null;

    return Scaffold(
      body: Stack(
        children: [
          // Top ambient glow
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.2),
                    AppColors.accent.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: TextButton(
                      onPressed: _purchasing ? null : _skip,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Premium badge icon with glow
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accent.withValues(alpha: 0.25),
                                AppColors.accent.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.workspace_premium,
                            size: 44,
                            color: AppColors.accent,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppColors.textPrimary,
                              AppColors.accent,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Unlock AI Fitness Pro',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                        const Text(
                          'Get the full experience — personalized AI coaching at your fingertips.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Feature cards
                        ...List.generate(_features.length, (i) {
                          final f = _features[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
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
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Icon(f.$3,
                                        color: AppColors.accent, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f.$1,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          f.$2,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Bottom CTA Section
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.background.withValues(alpha: 0.0),
                        AppColors.background,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: CircularProgressIndicator(),
                        )
                      else ...[
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),

                        // Glowing CTA button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ContinueButton(
                            label: _purchasing
                                ? 'Processing...'
                                : monthly != null
                                    ? 'Subscribe — ${monthly.storeProduct.priceString}/mo'
                                    : 'Start Free Trial',
                            onPressed:
                                _purchasing ? null : () => _purchase(monthly),
                          ),
                        ),

                        const SizedBox(height: 14),
                        Text(
                          'Cancel anytime · Restore purchases in settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
