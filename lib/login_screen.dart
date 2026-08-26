import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/profile/profile_screen.dart' show LegalViewerScreen;
import 'services/auth_links.dart';
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

  /// Messages are shown in the error colour unless this is cleared — the
  /// old code inferred it from a leading emoji, which broke the moment the
  /// prefixes were dropped.
  bool messageIsError = true;
  bool showResend = false; // offer "resend verification email"

  /// Set once a signup succeeds and Supabase is waiting on email
  /// confirmation. Swaps the form for a focused "check your inbox" panel so
  /// the next step is unmistakable.
  String? _pendingEmail;

  /// Supabase rate-limits confirmation emails (roughly one a minute), so the
  /// resend button counts down instead of letting people mash it into an
  /// error they can't interpret.
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  void _toggleMode() {
    setState(() {
      isSignUp = !isSignUp;
      message = '';
      messageIsError = true;
      showResend = false;
      _pendingEmail = null;
      confirmController.clear();
    });
  }

  /// Leaves the "check your inbox" panel and returns to the log-in form with
  /// the address already filled in.
  void _backToLogin() {
    _cooldownTimer?.cancel();
    setState(() {
      _pendingEmail = null;
      isSignUp = false;
      message = '';
      messageIsError = true;
      showResend = false;
      _resendCooldown = 0;
      passwordController.clear();
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
      setState(() => message = err);
      return;
    }
    setState(() {
      isLoading = true;
      message = '';
      messageIsError = true;
      showResend = false;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      // LoginScreen sits inside a StreamBuilder on onAuthStateChange
      // (main.dart), so a state change arriving while this request is in
      // flight — a verification deep link, a session restored elsewhere —
      // can dispose this screen before the response comes back.
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      setState(() {
        // Match the stable error code first; the human-readable string is
        // free to change between GoTrue releases.
        if (e.code == 'email_not_confirmed' || msg.contains('not confirmed')) {
          message =
              'Please verify your email first — check your inbox, and your '
              'spam or junk folder.';
          showResend = true;
        } else if (e.code == 'invalid_credentials' ||
            msg.contains('invalid login')) {
          message = 'Wrong email or password.';
        } else {
          message = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Could not sign in — check your connection.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signUp() async {
    final err = _validate();
    if (err != null) {
      setState(() => message = err);
      return;
    }
    setState(() {
      isLoading = true;
      message = '';
      messageIsError = true;
      showResend = false;
    });
    final email = emailController.text.trim();
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: passwordController.text.trim(),
        // Without this the confirmation link points at Supabase's default
        // redirect and opens a browser instead of the app.
        emailRedirectTo: kEmailRedirectUrl,
      );
      // Same StreamBuilder-disposal risk as _signIn — see its comment.
      if (!mounted) return;

      // Signing up with an address that already exists does NOT raise. To
      // avoid telling an attacker which emails are registered, Supabase
      // returns an ordinary success whose user has an EMPTY identities list.
      // Without this check that case shows "check your email" for a message
      // that is never sent, and the user waits forever.
      final alreadyRegistered = res.user?.identities?.isEmpty ?? false;
      if (alreadyRegistered) {
        setState(() {
          message =
              'That email already has an account. Log in instead — or if you '
              'never verified it, resend the link below.';
          showResend = true;
        });
        _startResendCooldown();
        return;
      }

      if (res.session == null) {
        // Expected path: the project requires email confirmation.
        setState(() => _pendingEmail = email);
        _startResendCooldown();
      } else {
        // Only reachable if confirmations get turned off in Supabase; the
        // auth listener takes over from here.
        setState(() {
          message = 'Account created.';
          messageIsError = false;
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      setState(() {
        if (msg.contains('already registered') ||
            msg.contains('already exists') ||
            e.code == 'user_already_exists') {
          message =
              'That email already has an account. Log in instead — or if you '
              'never verified it, resend the link below.';
          showResend = true;
        } else if (msg.contains('weak') || msg.contains('password')) {
          message = 'Password too weak — use at least 6 characters.';
        } else {
          message = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Could not sign up — check your connection.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Re-sends the signup verification email — Supabase does not resend it
  /// automatically when a signup is repeated for an unconfirmed address.
  ///
  /// Also the recovery path after deleting an account: once the auth user is
  /// gone, signing up again issues a fresh link; while it still exists, this
  /// re-sends the original one.
  Future<void> _resendVerification() async {
    final email = _pendingEmail ?? emailController.text.trim();
    if (email.isEmpty || _resendCooldown > 0) return;
    setState(() => isLoading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: kEmailRedirectUrl,
      );
      // Same StreamBuilder-disposal risk as _signIn — see its comment.
      if (!mounted) return;
      setState(() {
        message =
            'Verification email sent — check your inbox, and your spam or '
            'junk folder.';
        messageIsError = false;
      });
      _startResendCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      setState(() {
        if (msg.contains('rate') || e.code == 'over_email_send_rate_limit') {
          message = 'Too many requests — wait a minute and try again.';
          _startResendCooldown();
        } else if (msg.contains('already confirmed')) {
          // Nothing to resend: the address is verified, so log in.
          message = 'This email is already verified — you can log in.';
          messageIsError = false;
          showResend = false;
        } else {
          message = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => message = 'Could not resend — try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _verificationPanel() => VerificationPanel(
    email: _pendingEmail ?? '',
    message: message,
    isLoading: isLoading,
    resendCooldown: _resendCooldown,
    onResend: _resendVerification,
    onBack: _backToLogin,
  );

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

                    // PHYSIQO AI wordmark. Scaled to fit: at 46pt this is more
                    // than twice the width of the old "FITAI" and runs off a
                    // narrow phone otherwise.
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                            ),
                            children: [
                              TextSpan(
                                text: 'PHYSIQO',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              TextSpan(
                                text: ' AI',
                                style: TextStyle(color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _pendingEmail != null
                            ? 'One more step'
                            : isSignUp
                            ? 'Create your account'
                            : 'Log in to continue',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Awaiting email confirmation: the form would only invite
                    // the user to do the wrong thing, so replace it outright.
                    if (_pendingEmail != null) ...[
                      _verificationPanel(),
                    ] else ...[
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
                            color: messageIsError
                                ? AppColors.error.withValues(alpha: 0.1)
                                : AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: messageIsError
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
                              color: messageIsError
                                  ? AppColors.error
                                  : AppColors.accent,
                            ),
                          ),
                        ),
                        if (showResend)
                          TextButton(
                            onPressed: (isLoading || _resendCooldown > 0)
                                ? null
                                : _resendVerification,
                            child: Text(
                              _resendCooldown > 0
                                  ? 'Resend in ${_resendCooldown}s'
                                  : 'Resend verification email',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
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
                ? 'docs/privacy_policy.html'
                : 'docs/terms_of_service.html',
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

/// Shown after signup instead of the form: one instruction, one action.
///
/// Presentational and stateless so the copy can be tested without standing up
/// Supabase. This screen is where a stalled signup either recovers or the user
/// gives up, so the wording is worth pinning.
class VerificationPanel extends StatelessWidget {
  const VerificationPanel({
    super.key,
    required this.email,
    required this.message,
    required this.isLoading,
    required this.resendCooldown,
    required this.onResend,
    required this.onBack,
  });

  final String email;
  final String message;
  final bool isLoading;
  final int resendCooldown;
  final VoidCallback onResend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_unread_outlined, size: 48, color: kLime),
        const SizedBox(height: 16),
        Text(
          'Check your email to verify your account before logging in',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
            children: [
              const TextSpan(text: 'We sent a link to '),
              TextSpan(
                text: email,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '. Open it, then come back here and '),
              // Weighted because the link opens a web page, not the app.
              // Without a cue, people sit on that page waiting to be let in
              // rather than returning here to sign in normally.
              TextSpan(
                text: 'log in again',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        // A plain 11px footnote carried this before, and it was too quiet for
        // the most common reason a signup stalls: the mail is delivered, just
        // not to the inbox.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.warningText.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.warningText.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 16,
                color: AppColors.warningText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: "Don't see it? Check your "),
                      TextSpan(
                        text: 'spam or junk folder',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '. Physiqo AI is a new app, so verification '
                            'emails sometimes land there.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: (isLoading || resendCooldown > 0) ? null : onResend,
          child: Text(
            resendCooldown > 0
                ? 'Resend in ${resendCooldown}s'
                : 'Resend verification email',
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: isLoading ? null : onBack,
          child: const Text('Back to log in'),
        ),
        const SizedBox(height: 8),
        // Spam now has its own callout above, so this covers the other way a
        // signup stalls: the address was mistyped and nothing was delivered.
        Text(
          'Still nothing? Check the address above is spelled correctly.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
