import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/settings/cubit/dev_settings_cubit.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';
import 'package:dytty/features/settings/cubit/theme_cubit.dart';
import 'package:dytty/features/settings/settings_screen.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class MockDevSettingsCubit extends MockCubit<DevSettingsState>
    implements DevSettingsCubit {}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockSettingsCubit mockSettingsCubit;
  late MockDevSettingsCubit mockDevSettingsCubit;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockSettingsCubit = MockSettingsCubit();
    mockDevSettingsCubit = MockDevSettingsCubit();

    when(() => mockAuthBloc.state).thenReturn(
      const Authenticated(uid: 'u1', displayName: 'Test', email: 't@t.com'),
    );
    when(() => mockSettingsCubit.state).thenReturn(const SettingsState());
    when(() => mockDevSettingsCubit.state).thenReturn(const DevSettingsState());
    when(
      () => mockDevSettingsCubit.togglePromptVariant(),
    ).thenAnswer((_) async {});
  });

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: mockAuthBloc),
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        BlocProvider<SettingsCubit>.value(value: mockSettingsCubit),
        BlocProvider<DevSettingsCubit>.value(value: mockDevSettingsCubit),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  group('Developer section', () {
    Future<void> scrollToDeveloper(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Developer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }

    testWidgets('shows Developer section label', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await scrollToDeveloper(tester);

      expect(find.text('Developer'), findsOneWidget);
    });

    testWidgets('shows minimal prompt toggle off by default', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await scrollToDeveloper(tester);

      final switchFinder = find.widgetWithText(
        SwitchListTile,
        'Minimal system prompt',
      );
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);
    });

    testWidgets('toggle calls togglePromptVariant', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final switchFinder = find.widgetWithText(
        SwitchListTile,
        'Minimal system prompt',
      );
      await tester.scrollUntilVisible(
        switchFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      verify(() => mockDevSettingsCubit.togglePromptVariant()).called(1);
    });

    testWidgets('shows active indicator when toggle is on', (tester) async {
      when(
        () => mockDevSettingsCubit.state,
      ).thenReturn(const DevSettingsState(useMinimalPrompt: true));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await scrollToDeveloper(tester);

      expect(find.textContaining('Active:'), findsOneWidget);
    });

    testWidgets('hides active indicator when toggle is off', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await scrollToDeveloper(tester);

      expect(find.textContaining('Active:'), findsNothing);
    });
  });
}
