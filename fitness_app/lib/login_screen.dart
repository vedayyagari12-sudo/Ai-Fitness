import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isSignUp = false;
  String message = '';

  void handleAuth() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      if (isSignUp) {
        await Supabase.instance.client.auth.signUp(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        setState(() {
          message = '✅ Account created! Check email to verify.';
        });
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
    } catch (e) {
      setState(() {
        message = '❌ ${e.toString()}';
      });
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isSignUp ? 'Sign Up' : 'Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'AI Fitness',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : handleAuth,
              child: Text(isLoading
                  ? 'Loading...'
                  : isSignUp
                      ? 'Sign Up'
                      : 'Login'),
            ),
            TextButton(
              onPressed: () => setState(() => isSignUp = !isSignUp),
              child: Text(isSignUp
                  ? 'Already have an account? Login'
                  : 'No account? Sign up'),
            ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(message, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}