import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dytty/core/theme/app_theme.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/auth/auth_provider.dart';
import 'package:dytty/features/auth/login_screen.dart';
import 'package:dytty/features/daily_journal/daily_journal_screen.dart';
import 'package:dytty/features/daily_journal/home_screen.dart';
import 'package:dytty/features/daily_journal/journal_provider.dart';
import 'package:dytty/features/settings/settings_screen.dart';
import 'package:dytty/features/settings/theme_provider.dart';
import 'package:dytty/services/auth/auth_service.dart';

class DyttyApp extends StatelessWidget {
  const DyttyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService: AuthService()),
        ),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const _AppWithAuth(),
    );
  }
}

class _AppWithAuth extends StatefulWidget {
  const _AppWithAuth();

  @override
  State<_AppWithAuth> createState() => _AppWithAuthState();
}

class _AppWithAuthState extends State<_AppWithAuth> {
  String? _previousUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
    final journalProvider = context.read<JournalProvider>();

    final uid = authProvider.user?.uid;
    if (uid != null && uid != _previousUid) {
      _previousUid = uid;
      final repo = JournalRepository(uid: uid);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        journalProvider.setRepository(repo);
        repo
            .ensureUserProfile(
              authProvider.user!.displayName ?? '',
              authProvider.user!.email ?? '',
            )
            .catchError((e) {
              debugPrint('Failed to ensure user profile: $e');
            });
      });
    } else if (uid == null && _previousUid != null) {
      _previousUid = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        journalProvider.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Dytty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      home: authProvider.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : authProvider.isAuthenticated
          ? const HomeScreen()
          : const LoginScreen(),
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/daily-journal': (_) => const DailyJournalScreen(),
          '/settings': (_) => const SettingsScreen(),
        };

        final builder = routes[settings.name];
        if (builder != null) {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) =>
                builder(context),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 300),
          );
        }
        return null;
      },
    );
  }
}
