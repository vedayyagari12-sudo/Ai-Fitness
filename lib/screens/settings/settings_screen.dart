import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_state_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../../theme/theme_controller.dart';
import 'package:http/http.dart' as http;

const _backendBase = 'https://fitness-app-xayv.onrender.com';
const _appVersion = '1.0.0';
const _supportEmail = 'support@aifitness.app';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
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
                      'Settings',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: [
                              AppColors.textPrimary,
                              AppColors.textSecondary,
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Appearance'),
                    _themeToggle(),
                    const SizedBox(height: 8),
                    _sectionLabel('Legal'),
                    FeatureHubTile(
                      title: 'Privacy Policy',
                      subtitle: 'How we collect and use your data',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () => _openLegal(
                        context,
                        'Privacy Policy',
                        'assets/legal/privacy_policy.html',
                      ),
                    ),
                    FeatureHubTile(
                      title: 'Terms of Service',
                      subtitle: 'Rules and limitations of use',
                      icon: Icons.gavel_outlined,
                      onTap: () => _openLegal(
                        context,
                        'Terms of Service',
                        'assets/legal/terms_of_service.html',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sectionLabel('Support'),
                    FeatureHubTile(
                      title: 'Contact Support',
                      subtitle: _supportEmail,
                      icon: Icons.mail_outline,
                      onTap: () => _showContactDialog(context),
                    ),
                    const SizedBox(height: 8),
                    _sectionLabel('Account'),
                    FeatureHubTile(
                      title: 'Sign Out',
                      subtitle: 'Log out of your account',
                      icon: Icons.logout,
                      accentColor: AppColors.textSecondary,
                      onTap: () => _signOut(context),
                    ),
                    FeatureHubTile(
                      title: 'Delete Account',
                      subtitle: 'Permanently remove all your data',
                      icon: Icons.delete_forever_outlined,
                      accentColor: AppColors.error,
                      onTap: () => _confirmDeleteAccount(context),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'FitAI v$_appVersion',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Made with ❤️ for your health',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _openLegal(BuildContext context, String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LegalViewerScreen(title: title, assetPath: assetPath),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Contact Support',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'For support, data requests, or legal inquiries, email us at:\n\n$_supportEmail',
          style: TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    AppStateService.setGuestMode(false);
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _themeToggle() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (_, mode, _) {
        final isLight = mode == ThemeMode.light;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _themeOption(
                'Dark',
                Icons.dark_mode_outlined,
                !isLight,
                () => ThemeController.set(ThemeMode.dark),
              ),
              _themeOption(
                'Light',
                Icons.light_mode_outlined,
                isLight,
                () => ThemeController.set(ThemeMode.light),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _themeOption(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(context: context, builder: (_) => _DeleteAccountDialog());
  }
}

// ── Delete account dialog ────────────────────────────────────────────────────
class _DeleteAccountDialog extends StatefulWidget {
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken ?? '';

      final response = await http.delete(
        Uri.parse('$_backendBase/account'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        AppStateService.setGuestMode(false);
        await Supabase.instance.client.auth.signOut();
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        setState(() {
          _deleting = false;
          _error =
              'Deletion failed (${response.statusCode}). Please try again or contact support.';
        });
      }
    } catch (e) {
      setState(() {
        _deleting = false;
        _error = 'Could not connect to server. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Account?',
        style: TextStyle(
          color: AppColors.error,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete:\n\n• All workout history\n• All calorie logs\n• All physique scans\n• Your profile and account\n\nThis action cannot be undone.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
              fontSize: 14,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _deleting ? null : _delete,
          child: _deleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.error,
                  ),
                )
              : const Text(
                  'Delete Everything',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── In-app legal document viewer ─────────────────────────────────────────────
class _LegalViewerScreen extends StatefulWidget {
  const _LegalViewerScreen({required this.title, required this.assetPath});
  final String title;
  final String assetPath;

  @override
  State<_LegalViewerScreen> createState() => _LegalViewerScreenState();
}

class _LegalViewerScreenState extends State<_LegalViewerScreen> {
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
