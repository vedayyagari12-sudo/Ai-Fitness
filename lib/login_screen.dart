import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'services/app_state_service.dart';
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
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } catch (e) {
      setState(() => message = '❌ ${e.toString()}');
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _signUp() async {
    setState(() {
      isLoading = true;
      message = '';
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      setState(() => message = '✅ Account created! Check email to verify.');
    } catch (e) {
      setState(() => message = '❌ ${e.toString()}');
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _socialAuth(String provider) async {
    setState(() => message = '$provider sign-in coming soon');
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
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Logo Icon Container
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          size: 40,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    const Text(
                      'Log in or sign up',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Welcome to AI Fitness. Train smarter today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    
                    const SizedBox(height: 40),

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
                    
                    const SizedBox(height: 32),
                    
                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style: secondaryTextStyle(context, fontSize: 13),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Social Sign-Ins
                    SocialAuthButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata,
                      onPressed: () => _socialAuth('Google'),
                    ),
                    const SizedBox(height: 12),
                    SocialAuthButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple,
                      onPressed: () => _socialAuth('Apple'),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        AppStateService.setGuestMode(true);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MainScreen()),
                        );
                      },
                      child: const Text(
                        'Continue as Guest',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            color: message.startsWith('❌') ? AppColors.error : AppColors.accent,
                          ),
                        ),
                      ),
                    ],
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
