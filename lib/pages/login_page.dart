import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A simple login page using Supabase email/password authentication.
/// Provides both sign in and sign up flows in one page.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignIn = true;

      Future<void> _authenticate() async {
        final isValid = _formKey.currentState?.validate() ?? false;
        if (!isValid) return;
        setState(() => _isLoading = true);
        final auth = Supabase.instance.client.auth;
        try {
          if (_isSignIn) {
            // Attempt to sign in
            await auth.signInWithPassword(
              email: _emailController.text,
              password: _passwordController.text,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed in successfully')), 
              );
            }
          } else {
            // Attempt to sign up. In Supabase v1 this does not automatically
            // sign the user in. Show a success message and switch to sign in
            await auth.signUp(
              email: _emailController.text,
              password: _passwordController.text,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account created! Check your email to verify your address.')), 
              );
              // Switch back to sign in mode so the user can log in
              setState(() => _isSignIn = true);
            }
          }
        } on AuthException catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.message)),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignIn ? 'Sign in' : 'Sign up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                      // App heading for better branding
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          children: [
                            Icon(Icons.fitness_center, size: 48, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 8),
                            Text(
                              'Armwrestling Fitness',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _authenticate,
                          child: Text(_isSignIn ? 'Sign in' : 'Sign up'),
                        ),
                  TextButton(
                    onPressed: () => setState(() => _isSignIn = !_isSignIn),
                    child: Text(_isSignIn
                        ? 'Don\'t have an account? Sign up'
                        : 'Already have an account? Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}