import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../api_service.dart';
import '../../services/app_state_service.dart';
import '../../services/split_service.dart';
import '../../utils/units.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../utils/snackbar.dart';

const _appVersion = '1.0.0';
const _supportEmail = 'support@aifitness.app';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _profile = {};
  TrainingSplit _split = TrainingSplit.auto;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await getUserProfile();
    final split = await SplitService.getSplit();
    if (!mounted) return;
    setState(() {
      _profile = profile ?? {};
      _split = split;
      _loading = false;
    });
  }

  Future<void> _save(String key, dynamic value) async {
    setState(() => _profile[key] = value);
    await upsertUserProfile({key: value});
    if (mounted) AppSnackbar.success(context, 'Saved');
  }

  // ── Editors ────────────────────────────────────────────────────────────────

  Future<void> _editChoice(
    String title,
    String key,
    List<(String, String)> options, { // (label, storedValue)
    // Overrides for settings that don't live in user_profiles
    // (e.g. the training split, stored as a device preference).
    String? currentOverride,
    Future<void> Function(String value)? onPick,
  }) async {
    final current = currentOverride ?? '${_profile[key] ?? ''}';
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(title.toUpperCase(), style: kLabelSmall),
              ),
              for (final (label, value) in options)
                ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: value == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: value == current
                      ? const Icon(Icons.check_rounded, color: kLime, size: 18)
                      : null,
                  onTap: () => Navigator.pop(ctx, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      if (onPick != null) {
        await onPick(picked);
      } else {
        await _save(key, picked);
      }
    }
  }

  Future<void> _editNumber(
    String title,
    String key, {
    bool decimal = false,
    String? suffix,
    // Optional unit conversion between what's stored and what's shown
    // (e.g. weight is stored in kg but entered/displayed in lbs).
    double Function(double stored)? storeToDisplay,
    double Function(double entered)? displayToStore,
  }) async {
    final stored = (_profile[key] as num?)?.toDouble();
    final initial = stored == null
        ? ''
        : storeToDisplay != null
        ? storeToDisplay(stored).toStringAsFixed(decimal ? 1 : 0)
        : '${_profile[key]}';
    final ctrl = TextEditingController(text: initial);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(), style: kLabelSmall),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              decoration: InputDecoration(suffixText: suffix),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final num? value = decimal
          ? double.tryParse(ctrl.text)
          : int.tryParse(ctrl.text);
      if (value != null) {
        final toStore = displayToStore != null
            ? double.parse(displayToStore(value.toDouble()).toStringAsFixed(2))
            : value;
        await _save(key, toStore);
      }
    }
  }

  // ── Account actions ────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    AppStateService.setGuestMode(false);
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Delete Account?',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will permanently delete:\n\n'
              '• All workout history\n'
              '• All calorie logs\n'
              '• All physique scans\n'
              '• Your profile and account\n\n'
              'This action cannot be undone.',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.6,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Everything'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await deleteAccount();
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      if (result['auth_user_deleted'] != true) {
        // Data rows are gone but the login credential survived (server is
        // missing its admin key) — tell the user instead of faking success.
        AppSnackbar.info(
          context,
          'Your data was deleted, but the login could not be fully removed '
          'yet — contact support to finish removal.',
        );
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      AppStateService.setGuestMode(false);
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      AppSnackbar.error(
        context,
        'Deletion failed — try again or contact support',
      );
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  String _display(String key, {String? suffix}) {
    final v = _profile[key];
    if (v == null || '$v'.isEmpty) return 'Set';
    return suffix != null ? '$v $suffix' : '$v';
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '—';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
                children: [
                  Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Identity card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('YOUR DETAILS', style: kLabelSmall),
                  const SizedBox(height: 4),
                  _detailRow(
                    'Goal',
                    _goalLabel('${_profile['goal'] ?? ''}'),
                    () => _editChoice('Main goal', 'goal', const [
                      ('Build Muscle', 'bulk'),
                      ('Lose Fat', 'cut'),
                      ('Stay Fit', 'maintain'),
                      ('Perform', 'athletic'),
                    ]),
                  ),
                  _detailRow(
                    'Gender',
                    _display('gender'),
                    () => _editChoice('Gender', 'gender', const [
                      ('Male', 'Male'),
                      ('Female', 'Female'),
                      ('Other', 'Other'),
                    ]),
                  ),
                  _detailRow(
                    'Age',
                    _display('age'),
                    () => _editNumber('Age', 'age'),
                  ),
                  _detailRow(
                    'Height',
                    _display('height_cm', suffix: 'cm'),
                    () => _editNumber(
                      'Height',
                      'height_cm',
                      decimal: true,
                      suffix: 'cm',
                    ),
                  ),
                  _detailRow(
                    'Weight',
                    _profile['weight_kg'] != null
                        ? '${lbsLabel(kgToLbs(_profile['weight_kg'] as num))} lbs'
                        : 'Set',
                    () => _editNumber(
                      'Weight',
                      'weight_kg',
                      decimal: true,
                      suffix: 'lbs',
                      storeToDisplay: kgToLbs,
                      displayToStore: lbsToKg,
                    ),
                  ),
                  _detailRow(
                    'Equipment',
                    _display('equipment'),
                    () => _editChoice('Equipment', 'equipment', const [
                      ('Full Gym', 'Full Gym'),
                      ('Home — Dumbbells', 'Home — Dumbbells'),
                      ('Bodyweight Only', 'Bodyweight Only'),
                    ]),
                  ),
                  _detailRow(
                    'Fitness Level',
                    _display('fitness_level'),
                    () => _editChoice('Fitness level', 'fitness_level', const [
                      ('Beginner', 'Beginner'),
                      ('Intermediate', 'Intermediate'),
                      ('Advanced', 'Advanced'),
                    ]),
                  ),
                  _detailRow(
                    'Weekly Sessions',
                    _display('workout_frequency'),
                    () => _editChoice(
                      'Weekly sessions',
                      'workout_frequency',
                      const [('1-2', '1-2'), ('3-5', '3-5'), ('6+', '6+')],
                    ),
                  ),
                  _detailRow(
                    'Training Split',
                    SplitService.label(_split),
                    () => _editChoice(
                      'Training split',
                      'training_split',
                      [
                        for (final s in TrainingSplit.values)
                          (SplitService.label(s), s.name),
                      ],
                      currentOverride: _split.name,
                      onPick: (value) async {
                        final split = TrainingSplit.values.firstWhere(
                          (s) => s.name == value,
                        );
                        await SplitService.setSplit(split);
                        if (!mounted) return;
                        setState(() => _split = split);
                        AppSnackbar.success(this.context, 'Saved');
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('APP', style: kLabelSmall),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.mode,
                    builder: (context, mode, _) => _detailRow(
                      'Appearance',
                      mode == ThemeMode.light ? 'Light' : 'Dark',
                      () => _editChoice(
                        'Appearance',
                        'appearance',
                        const [('Dark', 'dark'), ('Light', 'light')],
                        currentOverride: mode == ThemeMode.light
                            ? 'light'
                            : 'dark',
                        onPick: (value) async {
                          await ThemeController.set(
                            value == 'light' ? ThemeMode.light : ThemeMode.dark,
                          );
                        },
                      ),
                    ),
                  ),
                  _detailRow(
                    'Privacy Policy',
                    '',
                    () => _openLegal(
                      'Privacy Policy',
                      'assets/legal/privacy_policy.html',
                    ),
                  ),
                  _detailRow(
                    'Terms of Service',
                    '',
                    () => _openLegal(
                      'Terms of Service',
                      'assets/legal/terms_of_service.html',
                    ),
                  ),
                  _detailRow('Contact Support', _supportEmail, () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Contact Support',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        content: Text(
                          'For support, data requests, or legal inquiries, '
                          'email us at:\n\n$_supportEmail',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }),
                  _detailRow('App Version', _appVersion, null),
                  const SizedBox(height: 24),

                  Text('ACCOUNT', style: kLabelSmall),
                  const SizedBox(height: 4),
                  _detailRow(
                    'Log Out',
                    '',
                    _signOut,
                    color: AppColors.textSecondary,
                  ),
                  _detailRow(
                    'Delete Account',
                    '',
                    _confirmDeleteAccount,
                    color: AppColors.danger,
                  ),
                ],
              ),
      ),
    );
  }

  String _goalLabel(String stored) => switch (stored) {
    'bulk' => 'Build Muscle',
    'cut' => 'Lose Fat',
    'maintain' => 'Stay Fit',
    'athletic' => 'Perform',
    '' => 'Set',
    _ => stored,
  };

  Widget _detailRow(
    String label,
    String value,
    VoidCallback? onTap, {
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color ?? AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  void _openLegal(String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalViewerScreen(title: title, assetPath: assetPath),
      ),
    );
  }
}

// ── In-app legal document viewer ─────────────────────────────────────────────
class LegalViewerScreen extends StatefulWidget {
  const LegalViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });
  final String title;
  final String assetPath;

  @override
  State<LegalViewerScreen> createState() => _LegalViewerScreenState();
}

class _LegalViewerScreenState extends State<LegalViewerScreen> {
  String _text = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString(widget.assetPath);
    // Strip HTML tags for plain-text rendering
    final stripped = raw
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
    if (mounted) setState(() => _text = stripped);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _text.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                      child: SelectableText(
                        _text,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.7,
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
