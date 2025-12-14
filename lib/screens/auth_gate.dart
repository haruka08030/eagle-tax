import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'tax_monitor_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Just check if we have a user
        final hasUser = snapshot.hasData && snapshot.data?.session?.user != null;

        if (hasUser) {
          return const TaxMonitorScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
