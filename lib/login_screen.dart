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
  final confirmController = TextEditingController();
  bool isLoading = false;
  bool isSignUp = false; // false = log in (default), true = create account
  String message = '';
  bool showResend = false; // offer "resend verification email"

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      isSignUp = !isSignUp;
      message = '';
      showResend = false;
      confirmController.clear();
    });
  }

  Future<void> _submit() => isSignUp ? _signUp() : _signIn();

  /// Shared field validation before hitting the network.
  String? _validate() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (password.isEmpty) return 'Please enter your password.';
    if (isSignUp) {
      if (password.length < 6) {
        return 'Password must be at least 6 characters.';
      }
      if (password != confirmController.text.trim()) {
        return 'Passwords don\'t match.';
      }
    }
    return null;
  }

  Future<void> _signIn() async {
    final err = _validate();
    if (err != null) {
      setState(() => message = '❌ $err');
      return;
    }
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
      setState(() => message = '❌ Could not sign in — check your connection.');
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _signUp() async {
    final err = _validate();
    if (err != null) {
      setState(() => message = '❌ $err');
      return;
    }
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
              '❌ This email already has an account. Log in instead — or '
              'if you never verified it, resend the email below.';
          showResend = true;
        } else {
          message = '❌ ${e.message}';
        }
      });
    } catch (e) {
      setState(() => message = '❌ Could not sign up — check your connection.');
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

          // Main layout
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
                    const SizedBox(height: 20),

                    // FITAI wordmark
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
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
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        isSignUp ? 'Create your account' : 'Log in to continue',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Log In / Sign Up toggle
                    _modeToggle(),
                    const SizedBox(height: 24),

                    // Email
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'name@example.com',
                        prefixIcon: Icon(Icons.mail_outline, size: 20),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: isSignUp ? 'At least 6 characters' : null,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      ),
                      obscureText: true,
                      textInputAction: isSignUp
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: (_) => isSignUp ? null : _submit(),
                    ),

                    // Confirm password (sign up only)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: isSignUp
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 12),
                                TextField(
                                  controller: confirmController,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm Password',
                                    hintText: 'Re-enter your password',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      size: 20,
                                    ),
                                  ),
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),

                    ContinueButton(
                      onPressed: isLoading ? null : _submit,
                      label: isLoading
                          ? (isSignUp ? 'Creating...' : 'Logging In...')
                          : (isSignUp ? 'Create Account' : 'Log In'),
                    ),

                    // Toggle prompt
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isSignUp
                              ? 'Already have an account?'
                              : "Don't have an account?",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: isLoading ? null : _toggleMode,
                          child: Text(isSignUp ? 'Log in' : 'Sign up'),
                        ),
                      ],
                    ),

                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 12),
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A pill segmented control: LOG IN | SIGN UP.
  Widget _modeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _modeTab('LOG IN', !isSignUp, () {
            if (isSignUp) _toggleMode();
          }),
          _modeTab('SIGN UP', isSignUp, () {
            if (!isSignUp) _toggleMode();
          }),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
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
}
