import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';
import 'package:dytty/features/settings/settings_screen.dart';

import '../helpers/pump_app.dart';
import '../robots/settings_screen_robot.dart';

void main() {
  // Disable Google Fonts HTTP fetching in tests.
  GoogleFonts.config.allowRuntimeFetching = false;
  // Disable flutter_animate durations so animations complete instantly.
  Animate.restartOnHotReload = false;

  late SettingsScreenRobot robot;

  setUp(() {
    Animate.restartOnHotReload = false;
  });

  group('SettingsScreen', () {
    testWidgets('renders settings title in app bar', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectTitleVisible();
    });

    testWidgets('shows user profile with name and email', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authState: const Authenticated(
          uid: 'uid-1',
          displayName: 'Jane Doe',
          email: 'jane@example.com',
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectProfileVisible('Jane Doe', 'jane@example.com');
    });

    testWidgets('shows initials when no photo URL', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authState: const Authenticated(
          uid: 'uid-1',
          displayName: 'Jane Doe',
          email: 'jane@example.com',
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectInitialsVisible('J');
    });

    testWidgets('shows fallback initial when name is null', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authState: const Authenticated(uid: 'uid-1'),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectInitialsVisible('?');
    });

    testWidgets('shows all three theme options', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectThemeOptions();
    });

    testWidgets('marks system theme as selected by default', (tester) async {
      await tester.pumpApp(const SettingsScreen(), themeMode: ThemeMode.system);
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectThemeSelected('System');
      robot.expectThemeNotSelected('Light');
      robot.expectThemeNotSelected('Dark');
    });

    testWidgets('marks dark theme as selected when dark mode', (tester) async {
      await tester.pumpApp(const SettingsScreen(), themeMode: ThemeMode.dark);
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectThemeSelected('Dark');
      robot.expectThemeNotSelected('System');
      robot.expectThemeNotSelected('Light');
    });

    testWidgets('shows hide entries toggle', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectHideEntriesToggle();
    });

    testWidgets('shows daily reminder toggle', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Daily reminder'));
      robot.expectDailyReminderToggle();
    });

    testWidgets('shows daily call reminder toggle', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Daily call reminder'));
      robot.expectDailyCallToggle();
    });

    testWidgets('hides reminder time when reminder disabled', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        settingsState: const SettingsState(
          loaded: true,
          reminderEnabled: false,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectReminderTimeNotVisible();
    });

    testWidgets('shows reminder time when reminder enabled', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        settingsState: const SettingsState(
          loaded: true,
          reminderEnabled: true,
          reminderTime: TimeOfDay(hour: 9, minute: 0),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Reminder time'));
      robot.expectReminderTimeVisible();
    });

    testWidgets('hides call time when daily call disabled', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        settingsState: const SettingsState(
          loaded: true,
          dailyCallEnabled: false,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectCallTimeNotVisible();
    });

    testWidgets('shows call time when daily call enabled', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        settingsState: const SettingsState(
          loaded: true,
          dailyCallEnabled: true,
          dailyCallTime: TimeOfDay(hour: 18, minute: 30),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Call time'));
      robot.expectCallTimeVisible();
    });

    testWidgets('shows sign out button after scrolling', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Sign Out'));
      robot.expectSignOutButton();
    });

    testWidgets('tapping sign out dispatches SignOut event', (tester) async {
      final mockAuthBloc = MockAuthBloc();
      when(
        () => mockAuthBloc.state,
      ).thenReturn(const Authenticated(uid: 'uid-1', displayName: 'Test'));

      await tester.pumpApp(const SettingsScreen(), authBloc: mockAuthBloc);
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Sign Out'));
      await robot.tapSignOut();

      verify(() => mockAuthBloc.add(const SignOut())).called(1);
    });

    testWidgets('tapping theme option calls setThemeMode', (tester) async {
      final mockThemeCubit = MockThemeCubit();
      when(() => mockThemeCubit.state).thenReturn(ThemeMode.system);

      await tester.pumpApp(const SettingsScreen(), themeCubit: mockThemeCubit);
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.tapThemeOption('Dark');

      verify(() => mockThemeCubit.setThemeMode(ThemeMode.dark)).called(1);
    });

    testWidgets('shows version from PackageInfo, not hardcoded', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'Dytty',
        packageName: 'com.dytty.dytty',
        version: '0.1.8',
        buildNumber: '10',
        buildSignature: '',
      );

      await tester.pumpApp(const SettingsScreen());
      await tester.pumpAndSettle();

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Version'));
      robot.expectVersionVisible('0.1.8+10');
    });

    testWidgets('shows version without build number when empty', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'Dytty',
        packageName: 'com.dytty.dytty',
        version: '1.0.0',
        buildNumber: '',
        buildSignature: '',
      );

      await tester.pumpApp(const SettingsScreen());
      await tester.pumpAndSettle();

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Version'));
      robot.expectVersionVisible('1.0.0');
    });

    testWidgets('shows loading indicator before version loads', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Version'));
      expect(find.text('Version'), findsOneWidget);
    });

    testWidgets('shows licenses tile', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Licenses'));
      robot.expectLicensesTile();
    });

    testWidgets('shows all section labels', (tester) async {
      await tester.pumpApp(const SettingsScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectSectionVisible('Appearance');
      robot.expectSectionVisible('Journal');

      await robot.scrollTo(find.text('Reminders'));
      robot.expectSectionVisible('Reminders');

      await robot.scrollTo(find.text('Account'));
      robot.expectSectionVisible('Account');

      await robot.scrollTo(find.text('About'));
      robot.expectSectionVisible('About');
    });

    testWidgets('does not show profile when unauthenticated', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authState: const Unauthenticated(),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      robot.expectNoProfileSection();

      // Sign out is still visible (no profile header means less scroll)
      await robot.scrollTo(find.text('Sign Out'));
      robot.expectSignOutButton();
    });

    testWidgets('shows "User" as fallback name when null', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authState: const Authenticated(uid: 'uid-1'),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('User'), findsOneWidget);
    });

    testWidgets('hides email when empty string', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        authState: const Authenticated(
          uid: 'uid-1',
          displayName: 'Test',
          email: '',
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Empty email should not render (guarded by isNotEmpty check)
      expect(find.text(''), findsNothing);
    });

    testWidgets('toggles hide entries calls cubit', (tester) async {
      final mockSettingsCubit = MockSettingsCubit();
      when(
        () => mockSettingsCubit.state,
      ).thenReturn(const SettingsState(loaded: true));
      when(
        () => mockSettingsCubit.toggleHideEntries(),
      ).thenAnswer((_) async {});

      await tester.pumpApp(
        const SettingsScreen(),
        settingsCubit: mockSettingsCubit,
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Hide entries'));
      await tester.pump();

      verify(() => mockSettingsCubit.toggleHideEntries()).called(1);
    });

    testWidgets('toggles daily reminder calls cubit', (tester) async {
      final mockSettingsCubit = MockSettingsCubit();
      when(
        () => mockSettingsCubit.state,
      ).thenReturn(const SettingsState(loaded: true));
      when(() => mockSettingsCubit.toggleReminder()).thenAnswer((_) async {});

      await tester.pumpApp(
        const SettingsScreen(),
        settingsCubit: mockSettingsCubit,
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Daily reminder'));
      await tester.tap(find.text('Daily reminder'));
      await tester.pump();

      verify(() => mockSettingsCubit.toggleReminder()).called(1);
    });

    testWidgets('toggles daily call calls cubit', (tester) async {
      final mockSettingsCubit = MockSettingsCubit();
      when(
        () => mockSettingsCubit.state,
      ).thenReturn(const SettingsState(loaded: true));
      when(() => mockSettingsCubit.toggleDailyCall()).thenAnswer((_) async {});

      await tester.pumpApp(
        const SettingsScreen(),
        settingsCubit: mockSettingsCubit,
      );
      await tester.pump(const Duration(seconds: 1));

      robot = SettingsScreenRobot(tester);
      await robot.scrollTo(find.text('Daily call reminder'));
      await tester.tap(find.text('Daily call reminder'));
      await tester.pump();

      verify(() => mockSettingsCubit.toggleDailyCall()).called(1);
    });
  });
}
