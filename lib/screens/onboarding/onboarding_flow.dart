import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/onboarding_data.dart';
import '../../api_service.dart';
import '../../services/app_state_service.dart';
import '../../services/permission_service.dart';
import '../../services/split_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../utils/profile_options.dart';
import '../../utils/units.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _data = OnboardingData();
  TrainingSplit? _split;
  int _step = 0;

  static const _totalSteps = 9;

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    _computeFitnessLevel();
    await SplitService.setSplit(_split ?? TrainingSplit.auto);
    await AppStateService.completeOnboarding(_data);
    await syncOnboardingToProfile(_data);
    if (!mounted) return;
    widget.onComplete();
  }

  void _computeFitnessLevel() {
    final freq = _data.workoutFrequency;
    if (freq == '6+') {
      _data.fitnessLevel = 'Advanced';
    } else if (freq == '3-5') {
      _data.fitnessLevel = 'Intermediate';
    } else {
      _data.fitnessLevel = 'Beginner';
    }
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return true;
      case 1:
        return _data.goal != null;
      case 2:
        return _data.gender != null;
      case 3:
        return _data.age != null &&
            _data.heightCm != null &&
            _data.weightKg != null;
      case 4:
        return _data.workoutFrequency != null;
      case 5:
        return _data.equipment != null;
      case 6:
        return _split != null;
      case 7:
        return _data.triedOtherApps != null;
      case 8:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildStep(),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _WelcomeStep(key: const ValueKey(0), onContinue: _next);
      case 1:
        return _GoalStep(
          key: const ValueKey(1),
          selected: _data.goal,
          onSelect: (v) => setState(() => _data.goal = v),
          onBack: _back,
          onContinue: _canContinue ? _next : null,
        );
      case 2:
        return _GenderStep(
          key: const ValueKey(2),
          selected: _data.gender,
          onSelect: (v) => setState(() => _data.gender = v),
          onBack: _back,
          onContinue: _canContinue ? _next : null,
        );
      case 3:
        return _BodyStatsStep(
          key: const ValueKey(3),
          data: _data,
          onChanged: () => setState(() {}),
          onBack: _back,
          onContinue: _canContinue ? _next : null,
        );
      case 4:
        return _FrequencyStep(
          key: const ValueKey(4),
          selected: _data.workoutFrequency,
          onSelect: (v) => setState(() => _data.workoutFrequency = v),
          onBack: _back,
          onContinue: _canContinue ? _next : null,
        );
      case 5:
        return _EquipmentStep(
          key: const ValueKey(5),
          selected: _data.equipment,
          onSelect: (v) => setState(() => _data.equipment = v),
          onBack: _back,
          onContinue: _canContinue ? _next : null,
        );
      case 6:
        return _SplitStep(
          key: const ValueKey(6),
          selected: _split,
          onSelect: (v) => setState(() => _split = v),
          onBack: _back,
          onContinue: _canContinue ? _next : null,
        );
      case 7:
        return _ExperienceStep(
          key: const ValueKey(7),
          selected: _data.triedOtherApps,
          onSelect: (v) => setState(() => _data.triedOtherApps = v),
          onBack: _back,
          onContinue: _canContinue ? _next : null,
        );
      case 8:
        return _InitialPhysiqueScanStep(
          key: const ValueKey(8),
          data: _data,
          onChanged: () => setState(() {}),
          onBack: _back,
          onContinue: _next,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speedY;
  double speedX;
  double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedY,
    required this.speedX,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;

  _ParticlePainter(this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = color.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _WelcomeStep extends StatefulWidget {
  const _WelcomeStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<_WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<_WelcomeStep>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _particleController;
  final List<_Particle> _particles = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particleController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addListener(_updateParticles)
          ..repeat();

    // Initialize particles
    for (int i = 0; i < 25; i++) {
      _particles.add(_createParticle(initialY: _random.nextDouble()));
    }
  }

  _Particle _createParticle({double? initialY}) {
    return _Particle(
      x: _random.nextDouble(),
      y: initialY ?? 1.1, // Start below screen by default
      size: _random.nextDouble() * 3.5 + 1.5,
      speedY: _random.nextDouble() * 0.0015 + 0.0005,
      speedX: (_random.nextDouble() - 0.5) * 0.0006,
      opacity: _random.nextDouble() * 0.25 + 0.08,
    );
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _particles.length; i++) {
        final p = _particles[i];
        p.y -= p.speedY;
        p.x += p.speedX;
        // If out of bounds, regenerate at the bottom
        if (p.y < -0.1 || p.x < -0.1 || p.x > 1.1) {
          _particles[i] = _createParticle();
        }
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final val = _bgController.value * 2.0 * math.pi;
          // Slowly oscillate the center of the radial gradient
          final dx = math.sin(val) * 0.25;
          final dy = -0.1 + math.cos(val) * 0.15;
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(dx, dy),
                radius: 1.5,
                colors: [
                  AppColors.accent.withValues(alpha: 0.18),
                  AppColors.background,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // Floating particles layer
            Positioned.fill(
              child: CustomPaint(
                painter: _ParticlePainter(_particles, AppColors.accent),
              ),
            ),

            // Scrolls only when it has to: on a normal phone the Spacers
            // centre the content as before, on a short screen (or at a large
            // system text size) it becomes scrollable instead of overflowing.
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Spacer(),
                            // Premium badge icon with ambient glow
                            Container(
                              width: 96,
                              height: 96,
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
                                    color: AppColors.accent.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.fitness_center,
                                size: 44,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              'Train smarter\nwith AI',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.15,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Personalized workouts, calorie scanning, and physique analysis — all in one sleek app.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const Spacer(),
                            ContinueButton(
                              onPressed: widget.onContinue,
                              label: 'Get Started',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Takes about 2 minutes',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  static const _goals = [
    ('Build Muscle', Icons.fitness_center),
    ('Lose Weight', Icons.trending_down),
    ('Improve Endurance', Icons.directions_run),
    ('General Fitness', Icons.favorite_outline),
    ('Athletic Performance', Icons.emoji_events_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'What is your primary goal?',
      subtitle: 'We\'ll tailor your plan around this.',
      onBack: onBack,
      onContinue: onContinue,
      continueEnabled: onContinue != null,
      currentStep: 1,
      totalSteps: 8,
      child: Column(
        children: _goals
            .map(
              (g) => SelectionTile(
                label: g.$1,
                icon: g.$2,
                selected: selected == g.$1,
                onTap: () => onSelect(g.$1),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _GenderStep extends StatelessWidget {
  const _GenderStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Choose your gender',
      subtitle: 'This helps us calculate accurate targets.',
      onBack: onBack,
      onContinue: onContinue,
      continueEnabled: onContinue != null,
      currentStep: 2,
      totalSteps: 8,
      child: Column(
        children: ['Male', 'Female', 'Other']
            .map(
              (g) => SelectionTile(
                label: g,
                selected: selected == g,
                onTap: () => onSelect(g),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BodyStatsStep extends StatefulWidget {
  const _BodyStatsStep({
    super.key,
    required this.data,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
  });

  final OnboardingData data;
  final VoidCallback onChanged;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  @override
  State<_BodyStatsStep> createState() => _BodyStatsStepState();
}

class _BodyStatsStepState extends State<_BodyStatsStep> {
  late final _ageCtrl = TextEditingController(
    text: widget.data.age?.toString() ?? '',
  );
  late final _heightCtrl = TextEditingController(
    text: widget.data.heightCm?.toString() ?? '',
  );
  late final _weightCtrl = TextEditingController(
    text: widget.data.weightKg != null
        ? lbsLabel(kgToLbs(widget.data.weightKg!))
        : '',
  );

  void _sync() {
    widget.data.age = int.tryParse(_ageCtrl.text);
    widget.data.heightCm = double.tryParse(_heightCtrl.text);
    // Entered in lbs; stored in kg (the database unit).
    final lbs = double.tryParse(_weightCtrl.text);
    widget.data.weightKg = lbs != null
        ? double.parse(lbsToKg(lbs).toStringAsFixed(2))
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged();
    });
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Tell us about yourself',
      subtitle: 'Used to personalize calories and workouts.',
      onBack: widget.onBack,
      onContinue: widget.onContinue,
      continueEnabled: widget.onContinue != null,
      currentStep: 3,
      totalSteps: 8,
      child: Column(
        children: [
          TextField(
            controller: _ageCtrl,
            onChanged: (_) => _sync(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heightCtrl,
            onChanged: (_) => _sync(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Height (cm)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightCtrl,
            onChanged: (_) => _sync(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Weight (lbs)'),
          ),
        ],
      ),
    );
  }
}

class _FrequencyStep extends StatelessWidget {
  const _FrequencyStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'How many workouts do you do per week?',
      onBack: onBack,
      onContinue: onContinue,
      continueEnabled: onContinue != null,
      currentStep: 4,
      totalSteps: 8,
      child: Column(
        children: [
          SelectionTile(
            label: '0–2',
            subtitle: 'Workouts now and then',
            selected: selected == '0-2',
            onTap: () => onSelect('0-2'),
          ),
          SelectionTile(
            label: '3–5',
            subtitle: 'A few workouts per week',
            selected: selected == '3-5',
            onTap: () => onSelect('3-5'),
          ),
          SelectionTile(
            label: '6+',
            subtitle: 'Most days of the week',
            selected: selected == '6+',
            onTap: () => onSelect('6+'),
          ),
        ],
      ),
    );
  }
}

class _EquipmentStep extends StatelessWidget {
  const _EquipmentStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  // Only the descriptions live here. The values come from the shared list,
  // because these two screens had drifted into different vocabularies —
  // onboarding stored "Resistance Bands", which the profile picker did not
  // offer, so the setting read as unset there however often it was saved.
  static const _blurbs = {
    'Full Gym': 'All machines and free weights',
    'Home — No Equipment': 'Bodyweight only',
    'Dumbbells Only': 'Pair of dumbbells',
    'Resistance Bands': 'Bands and bodyweight',
    'Barbell Only': 'Barbell setup',
  };

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'What equipment do you have?',
      subtitle: 'We\'ll generate workouts that fit your setup.',
      onBack: onBack,
      onContinue: onContinue,
      continueEnabled: onContinue != null,
      currentStep: 5,
      totalSteps: 8,
      child: Column(
        children: kEquipmentOptions
            .map(
              (o) => SelectionTile(
                label: o.$1,
                subtitle: _blurbs[o.$2],
                selected: selected == o.$2,
                onTap: () => onSelect(o.$2),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SplitStep extends StatelessWidget {
  const _SplitStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });

  final TrainingSplit? selected;
  final ValueChanged<TrainingSplit> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  static const _subtitles = {
    TrainingSplit.ppl: 'Rotate push, pull and leg days',
    TrainingSplit.upperLower: 'Alternate upper and lower body days',
    TrainingSplit.fullBody: 'Hit everything each session',
    TrainingSplit.auto: 'We pick a balanced rotation for you',
  };

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'How do you like to split your training?',
      subtitle: 'Your daily AI session follows this split.',
      onBack: onBack,
      onContinue: onContinue,
      continueEnabled: onContinue != null,
      currentStep: 6,
      totalSteps: 8,
      child: Column(
        children: [
          for (final s in [
            TrainingSplit.ppl,
            TrainingSplit.upperLower,
            TrainingSplit.fullBody,
            TrainingSplit.auto,
          ])
            SelectionTile(
              label: SplitService.label(s),
              subtitle: _subtitles[s],
              selected: selected == s,
              onTap: () => onSelect(s),
            ),
        ],
      ),
    );
  }
}

class _ExperienceStep extends StatelessWidget {
  const _ExperienceStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });

  final bool? selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Have you tried other calorie tracking apps?',
      onBack: onBack,
      onContinue: onContinue,
      continueEnabled: onContinue != null,
      currentStep: 7,
      totalSteps: 8,
      child: Column(
        children: [
          SelectionTile(
            label: 'No',
            selected: selected == false,
            onTap: () => onSelect(false),
          ),
          SelectionTile(
            label: 'Yes',
            selected: selected == true,
            onTap: () => onSelect(true),
          ),
        ],
      ),
    );
  }
}

class _InitialPhysiqueScanStep extends StatefulWidget {
  const _InitialPhysiqueScanStep({
    super.key,
    required this.data,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
  });

  final OnboardingData data;
  final VoidCallback onChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<_InitialPhysiqueScanStep> createState() =>
      _InitialPhysiqueScanStepState();
}

class _InitialPhysiqueScanStepState extends State<_InitialPhysiqueScanStep> {
  final _picker = ImagePicker();
  Uint8List? _imageBytes;

  Future<void> _pick(ImageSource source) async {
    final granted = await PermissionService.requestCameraAndMedia(context);
    if (!granted) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _imageBytes = bytes;
          widget.data.initialPhysiqueImagePath = file.path;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onChanged();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageBytes != null;

    return OnboardingScaffold(
      title: 'Initial Physique Scan',
      subtitle:
          'Upload a starting photo to track your posture, shape, and muscle changes.',
      onBack: widget.onBack,
      onContinue: widget.onContinue,
      continueLabel: hasImage ? 'Continue' : 'Skip for Now',
      continueEnabled: true,
      currentStep: 8,
      totalSteps: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Circular Preview with ambient glow
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 145,
                  height: 145,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasImage
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    boxShadow: hasImage
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 6,
                            ),
                          ]
                        : [],
                  ),
                ),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasImage ? AppColors.accent : AppColors.border,
                      width: hasImage ? 2.5 : 1.5,
                    ),
                    color: AppColors.surface,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImage
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : Icon(
                          Icons.accessibility_new_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Camera/Gallery Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // App Store Compliant Privacy Warning Card
          AppCard(
            margin: EdgeInsets.zero,
            color: AppColors.accent.withValues(alpha: 0.08),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.security_outlined,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy & Compliance Shield',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your photos are processed securely using secure AI shape models on device. Photos are never shared, uploaded publicly, or used for third-party tracking. You can choose to skip this step or delete your images at any time in your profile.',
                        style: secondaryTextStyle(context, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
