import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/core/theme/app_colors.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';
import 'package:dytty/features/settings/cubit/theme_cubit.dart';
import 'package:dytty/data/models/category_config.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class MockJournalBloc extends MockBloc<JournalEvent, JournalState>
    implements JournalBloc {}

class MockCategoryCubit extends MockCubit<CategoryState>
    implements CategoryCubit {}

class MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class MockThemeCubit extends MockCubit<ThemeMode> implements ThemeCubit {}

/// Test-safe themes that don't use Google Fonts (avoids network requests).
/// Uses the same color scheme as AppTheme but with default Material fonts.
ThemeData get _testLightTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.seedColor,
        brightness: Brightness.light,
        surface: AppColors.lightSurface,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
    );

ThemeData get _testDarkTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.seedColor,
        brightness: Brightness.dark,
        surface: AppColors.darkSurface,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
    );

/// Wraps a widget with the full provider tree and Material theme for golden
/// tests. Uses test-safe themes (no Google Fonts) to avoid network errors.
Widget goldenWrapper(
  Widget child, {
  AuthState? authState,
  JournalState? journalState,
  CategoryState? categoryState,
  SettingsState? settingsState,
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(400, 800),
}) {
  final mockAuthBloc = MockAuthBloc();
  final mockJournalBloc = MockJournalBloc();
  final mockCategoryCubit = MockCategoryCubit();
  final mockSettingsCubit = MockSettingsCubit();
  final mockThemeCubit = MockThemeCubit();

  when(() => mockAuthBloc.state).thenReturn(
    authState ??
        const Authenticated(
          uid: 'test-uid',
          displayName: 'Test User',
          email: 'test@test.com',
        ),
  );
  when(() => mockJournalBloc.state).thenReturn(
    journalState ?? JournalState(),
  );
  when(() => mockCategoryCubit.state).thenReturn(
    categoryState ??
        CategoryState(categories: CategoryConfig.defaults, loaded: true),
  );
  when(() => mockSettingsCubit.state).thenReturn(
    settingsState ?? const SettingsState(loaded: true),
  );
  when(() => mockThemeCubit.state).thenReturn(themeMode);

  // Stream stubs (needed for BlocBuilder to work)
  when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => mockJournalBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => mockCategoryCubit.stream)
      .thenAnswer((_) => const Stream.empty());
  when(() => mockSettingsCubit.stream)
      .thenAnswer((_) => const Stream.empty());
  when(() => mockThemeCubit.stream).thenAnswer((_) => const Stream.empty());

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: mockAuthBloc),
      BlocProvider<JournalBloc>.value(value: mockJournalBloc),
      BlocProvider<CategoryCubit>.value(value: mockCategoryCubit),
      BlocProvider<SettingsCubit>.value(value: mockSettingsCubit),
      BlocProvider<ThemeCubit>.value(value: mockThemeCubit),
    ],
    child: MaterialApp(
      theme: _testLightTheme,
      darkTheme: _testDarkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: SizedBox(
        width: size.width,
        height: size.height,
        child: child,
      ),
    ),
  );
}
