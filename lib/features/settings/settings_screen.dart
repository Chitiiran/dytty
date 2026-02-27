import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dytty/features/auth/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child:
                    user.photoURL == null ? const Icon(Icons.person) : null,
              ),
              title: Text(user.displayName ?? 'User'),
              subtitle: Text(user.email ?? ''),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Dytty v0.1.0'),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Sign Out',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}
