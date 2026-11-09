import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/services/auth_service.dart';
import 'package:manga_sonic/services/theme_service.dart';
import 'package:manga_sonic/features/home/home_screen.dart';

/// Authentication screen with sign in and sign up forms
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final accentColor = themeService.primaryColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Consumer<AuthService>(
                  builder: (context, authService, child) {
                    // Show email confirmation screen if needed
                    if (authService.authState == AuthState.needsEmailConfirmation) {
                      return _buildEmailConfirmationScreen(authService, accentColor);
                    }
                    
                    return _buildAuthForm(accentColor);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailConfirmationScreen(AuthService authService, Color accentColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: Colors.orangeAccent,
        ),
        const SizedBox(height: 16),
        const Text(
          'Confirm Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ve sent a confirmation email to\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please check your inbox and click the link to verify your account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 32),
        Consumer<AuthService>(
          builder: (context, authService, child) {
            return ElevatedButton(
              onPressed: authService.authState == AuthState.loading
                  ? null
                  : () async {
                      final success = await authService.resendConfirmationEmail(_emailController.text);
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Confirmation email sent!')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authService.authState == AuthState.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Resend Confirmation Email',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            authService.signOut();
            setState(() {
              _isSignUp = false;
              _formKey.currentState?.reset();
              _emailController.clear();
              _passwordController.clear();
              _confirmPasswordController.clear();
            });
          },
          child: const Text(
            'Back to Sign In',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm(Color accentColor) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo/Title
          Icon(
            Icons.menu_book_rounded,
            size: 80,
            color: accentColor,
          ),
          const SizedBox(height: 16),
          Text(
            'MangaSonic',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSignUp ? 'Create your account' : 'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 40),

          // Auth Form
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  'Email',
                  Icons.email_outlined,
                  accentColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: _isSignUp 
                    ? TextInputAction.next 
                    : TextInputAction.done,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  'Password',
                  Icons.lock_outline,
                  accentColor,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword 
                          ? Icons.visibility_off 
                          : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => 
                      _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (_isSignUp && value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _handleSubmit(),
              ),
              const SizedBox(height: 16),

              // Confirm Password Field (Sign Up only)
              if (_isSignUp) ...[
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Confirm Password',
                    Icons.lock_outline,
                    accentColor,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword 
                            ? Icons.visibility_off 
                            : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => 
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleSubmit(),
                ),
                const SizedBox(height: 16),
              ],

              // Error Message
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  if (authService.authError != null) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        authService.authError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Submit Button
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  return ElevatedButton(
                    onPressed: authService.authState == AuthState.loading
                        ? null
                        : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: authService.authState == AuthState.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Toggle Sign Up / Sign In
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isSignUp ? 'Already have an account? ' : 'Don\'t have an account? ',
                style: const TextStyle(color: Colors.white54),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _formKey.currentState?.reset();
                    _emailController.clear();
                    _passwordController.clear();
                    _confirmPasswordController.clear();
                    context.read<AuthService>().clearError();
                  });
                },
                child: Text(
                  _isSignUp ? 'Sign In' : 'Sign Up',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Continue as Guest
          TextButton(
            onPressed: () {
              // Allow using app without account (local only)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(),
                ),
              );
            },
            child: Text(
              'Continue as Guest (Local Only)',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
    Color accentColor,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool success;
    if (_isSignUp) {
      success = await authService.signUp(email: email, password: password);
    } else {
      success = await authService.signIn(email: email, password: password);
    }

    if (success && mounted) {
      // Navigation is handled by AuthWrapper listening to auth state
    }
  }
}