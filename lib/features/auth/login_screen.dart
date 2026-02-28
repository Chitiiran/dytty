import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dytty/features/auth/auth_provider.dart';
import 'package:dytty/main.dart' show useEmulators;

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.book_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Dytty',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your daily journal',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              if (authProvider.error != null) ...[
                Text(
                  authProvider.error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              Semantics(
                label: 'Sign in with Google',
                button: true,
                child: ElevatedButton.icon(
                  onPressed:
                      authProvider.loading ? null : authProvider.signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: Text(
                    authProvider.loading
                        ? 'Signing in...'
                        : 'Sign in with Google',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              if (useEmulators) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: authProvider.loading
                      ? null
                      : authProvider.signInAnonymously,
                  icon: const Icon(Icons.developer_mode),
                  label: const Text('Sign in anonymously (emulator)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
