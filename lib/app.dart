import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/theme/app_theme.dart';
import 'package:dytty/data/repositories/category_repository.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/auth/login_screen.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/daily_journal/daily_journal_screen.dart';
import 'package:dytty/features/daily_journal/home_screen.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';
import 'package:dytty/features/settings/cubit/theme_cubit.dart';
import 'package:dytty/features/settings/settings_screen.dart';
import 'package:dytty/features/voice_call/voice_call_screen.dart';
import 'package:dytty/main.dart' show geminiApiKey, notificationService;
import 'package:dytty/services/notification/notification_service.dart';
import 'package:dytty/services/auth/auth_service.dart';
import 'package:dytty/services/llm/gemini_llm_service.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/llm/no_op_llm_service.dart';
import 'package:dytty/services/speech/speech_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';

class DyttyApp extends StatelessWidget {
  const DyttyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(authService: AuthService())),
        BlocProvider(create: (_) => ThemeCubit()),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is AuthLoading || authState is AuthInitial) {
            return _themedApp(
              context,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (authState is Authenticated) {
            return _AuthenticatedApp(authState: authState);
          }

          // Unauthenticated or AuthError
          return _themedApp(context, home: const LoginScreen());
        },
      ),
    );
  }
}

class _AuthenticatedApp extends StatefulWidget {
  final Authenticated authState;

  const _AuthenticatedApp({required this.authState});

  @override
  State<_AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<_AuthenticatedApp> {
  late JournalRepository _repository;
  late CategoryRepository _categoryRepository;
  bool _profileEnsured = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _repository = JournalRepository(uid: widget.authState.uid);
    _categoryRepository = CategoryRepository(uid: widget.authState.uid);
    _ensureProfile();
    _checkPendingRoute();
  }

  void _checkPendingRoute() {
    final route = NotificationService.pendingRoute;
    if (route != null) {
      NotificationService.pendingRoute = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.pushNamed(route);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authState.uid != widget.authState.uid) {
      _repository = JournalRepository(uid: widget.authState.uid);
      _categoryRepository = CategoryRepository(uid: widget.authState.uid);
      _profileEnsured = false;
      _ensureProfile();
    }
  }

  void _ensureProfile() {
    if (!_profileEnsured) {
      _profileEnsured = true;
      _repository
          .ensureUserProfile(
            widget.authState.displayName ?? '',
            widget.authState.email ?? '',
          )
          .catchError((e) {
            debugPrint('Failed to ensure user profile: $e');
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LlmService>(
          create: (_) => geminiApiKey.isNotEmpty
              ? GeminiLlmService(apiKey: geminiApiKey) as LlmService
              : NoOpLlmService(),
        ),
        RepositoryProvider<SpeechService>(create: (_) => SpeechService()),
        RepositoryProvider<AudioStorageService>(
          create: (_) => AudioStorageService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            key: ValueKey(widget.authState.uid),
            create: (_) => JournalBloc(repository: _repository),
          ),
          BlocProvider(
            create: (_) => SettingsCubit(
              repository: _repository,
              notificationService: notificationService,
            )..loadSettings(),
          ),
          BlocProvider(
            create: (_) =>
                CategoryCubit(repository: _categoryRepository)
                  ..loadCategories(),
          ),
        ],
        child: _themedApp(
          context,
          home: const HomeScreen(),
          routes: true,
          navigatorKey: _navigatorKey,
        ),
      ),
    );
  }
}

Widget _themedApp(
  BuildContext context, {
  required Widget home,
  bool routes = false,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return BlocBuilder<ThemeCubit, ThemeMode>(
    builder: (context, themeMode) {
      return MaterialApp(
        title: 'Dytty',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: home,
        onGenerateRoute: routes ? _generateRoute : null,
      );
    },
  );
}

Route<dynamic>? _generateRoute(RouteSettings settings) {
  final routes = <String, WidgetBuilder>{
    '/daily-journal': (_) => const DailyJournalScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/voice-call': (_) => const VoiceCallScreen(),
  };

  final builder = routes[settings.name];
  if (builder != null) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
  return null;
}
