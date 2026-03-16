import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';
import 'package:dytty/features/settings/cubit/theme_cubit.dart';
import 'package:dytty/data/models/category_config.dart';

/// Mock Blocs/Cubits for widget testing.
class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockJournalBloc extends MockBloc<JournalEvent, JournalState>
    implements JournalBloc {}

class MockCategoryCubit extends MockCubit<CategoryState>
    implements CategoryCubit {}

class MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class MockThemeCubit extends MockCubit<ThemeMode> implements ThemeCubit {}

/// Pumps a widget wrapped with all required providers for testing.
///
/// Use [authState] to control authentication state.
/// Use [journalState] to control journal data.
/// Use [categoryState] to control categories.
/// Use [settingsState] to control settings.
/// Use [themeMode] to control theme.
///
/// Pass pre-configured mocks via the bloc/cubit parameters when you need
/// to verify interactions (e.g. `verify(() => bloc.add(...))`).
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    AuthState? authState,
    JournalState? journalState,
    CategoryState? categoryState,
    SettingsState? settingsState,
    ThemeMode? themeMode,
    MockAuthBloc? authBloc,
    MockJournalBloc? journalBloc,
    MockCategoryCubit? categoryCubit,
    MockSettingsCubit? settingsCubit,
    MockThemeCubit? themeCubit,
  }) async {
    final mockAuthBloc = authBloc ?? MockAuthBloc();
    final mockJournalBloc = journalBloc ?? MockJournalBloc();
    final mockCategoryCubit = categoryCubit ?? MockCategoryCubit();
    final mockSettingsCubit = settingsCubit ?? MockSettingsCubit();
    final mockThemeCubit = themeCubit ?? MockThemeCubit();

    // Set default states
    when(() => mockAuthBloc.state).thenReturn(
      authState ??
          const Authenticated(
            uid: 'test-uid',
            displayName: 'Test User',
            email: 'test@test.com',
          ),
    );
    when(
      () => mockJournalBloc.state,
    ).thenReturn(journalState ?? JournalState());
    when(() => mockCategoryCubit.state).thenReturn(
      categoryState ??
          CategoryState(categories: CategoryConfig.defaults, loaded: true),
    );
    when(
      () => mockSettingsCubit.state,
    ).thenReturn(settingsState ?? const SettingsState(loaded: true));
    when(() => mockThemeCubit.state).thenReturn(themeMode ?? ThemeMode.system);

    await pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          BlocProvider<JournalBloc>.value(value: mockJournalBloc),
          BlocProvider<CategoryCubit>.value(value: mockCategoryCubit),
          BlocProvider<SettingsCubit>.value(value: mockSettingsCubit),
          BlocProvider<ThemeCubit>.value(value: mockThemeCubit),
        ],
        child: MaterialApp(home: widget),
      ),
    );
  }
}
