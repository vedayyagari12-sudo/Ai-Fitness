import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/profile/profile_screen.dart' show LegalViewerScreen;
import 'theme/app_theme.dart';
import 'theme/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool showPasswordStep = false;
  String message = '';
  bool showResend = false; // offer "resend verification email"

  Future<void> _continueWithEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() => message = 'Please enter your email');
      return;
    }
    setState(() {
      showPasswordStep = true;
      message = '';
    });
  }

  Future<void> _signIn() async {
    setState(() {
      isLoading = true;
      message = '';
      showResend = false;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() {
        if (msg.contains('not confirmed')) {
          message = '❌ Your email isn\'t verified yet.';
          showResend = true;
        } else if (msg.contains('invalid')) {
          message = '❌ Wrong email or password.';
        } else {
          message = '❌ ${e.message}';
        }
      });
    } catch (e) {
      setState(
        () => message = '❌ Could not sign in — check your connection.',
      );
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _signUp() async {
    setState(() {
      isLoading = true;
      message = '';
      showResend = false;
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      setState(() {
        // session == null means Supabase requires email confirmation.
        if (res.session == null) {
          message = '✅ Account created! Check your email to verify.';
          showResend = true;
        } else {
          message = '✅ Account created!';
        }
      });
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() {
        if (msg.contains('already registered') ||
            msg.contains('already exists')) {
          message =
              '❌ This email already has an account. Sign in instead — or '
              'if you never verified it, resend the email below.';
          showResend = true;
        } else {
          message = '❌ ${e.message}';
        }
      });
    } catch (e) {
      setState(
        () => message = '❌ Could not sign up — check your connection.',
      );
    }
    if (mounted) setState(() => isLoading = false);
  }

  /// Re-sends the signup verification email — Supabase does not resend it
  /// automatically when a signup is repeated for an unconfirmed address.
  Future<void> _resendVerification() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => isLoading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      setState(
        () => message = '✅ Verification email re-sent — check your inbox.',
      );
    } on AuthException catch (e) {
      setState(
        () => message = e.message.toLowerCase().contains('rate')
            ? '❌ Too many requests — wait a minute and try again.'
            : '❌ ${e.message}',
      );
    } catch (_) {
      setState(() => message = '❌ Could not resend — try again.');
    }
    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.1),
                    blurRadius: 90,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // Main Layout
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    // FITAI wordmark
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                          children: [
                            TextSpan(
                              text: 'FIT',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                            TextSpan(
                              text: 'AI',
                              style: TextStyle(color: AppColors.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Inputs and Main Form section with cross-fade animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.05),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: !showPasswordStep
                          ? _buildEmailStep()
                          : _buildPasswordStep(),
                    ),

                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: message.startsWith('❌')
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: message.startsWith('❌')
                                ? AppColors.error.withValues(alpha: 0.3)
                                : AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: message.startsWith('❌')
                                ? AppColors.error
                                : AppColors.accent,
                          ),
                        ),
                      ),
                      if (showResend)
                        TextButton(
                          onPressed: isLoading ? null : _resendVerification,
                          child: const Text(
                            'Resend verification email',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legalLink(context, 'Privacy Policy'),
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        _legalLink(context, 'Terms of Service'),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalLink(BuildContext context, String label) {
    final isPrivacy = label.toLowerCase().contains('privacy');
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LegalViewerScreen(
            title: isPrivacy ? 'Privacy Policy' : 'Terms of Service',
            assetPath: isPrivacy
                ? 'assets/legal/privacy_policy.html'
                : 'assets/legal/terms_of_service.html',
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('email_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'name@example.com',
            prefixIcon: Icon(Icons.mail_outline, size: 20),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _continueWithEmail(),
        ),
        const SizedBox(height: 20),
        ContinueButton(
          onPressed: isLoading ? null : _continueWithEmail,
          label: 'Continue',
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      key: const ValueKey('password_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: emailController,
          enabled: false,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.mail_outline, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline, size: 20),
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: 20),
        ContinueButton(
          onPressed: isLoading ? null : _signIn,
          label: isLoading ? 'Signing In...' : 'Sign In',
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: isLoading ? null : _signUp,
              child: const Text('Create Account'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  showPasswordStep = false;
                  passwordController.clear();
                });
              },
              child: const Text('Change Email'),
            ),
          ],
        ),
      ],
    );
  }
}
