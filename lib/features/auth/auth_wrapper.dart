import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/services/auth_service.dart';
import 'package:manga_sonic/features/home/home_screen.dart';
import 'package:manga_sonic/features/auth/auth_screen.dart';

/// Wrapper that shows auth screen when not signed in, home screen when signed in
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Show loading while initializing
        if (!authService.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Show auth screen if not signed in
        if (!authService.isSignedIn) {
          return const AuthScreen();
        }

        // Show home screen if signed in
        return const HomeScreen();
      },
    );
  }
}