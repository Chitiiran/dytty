import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dytty/features/settings/cubit/theme_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeCubit persistence', () {
    blocTest<ThemeCubit, ThemeMode>(
      'loadTheme restores a persisted mode',
      setUp: () =>
          SharedPreferences.setMockInitialValues({'theme_mode': 'dark'}),
      build: () => ThemeCubit(),
      act: (cubit) => cubit.loadTheme(),
      expect: () => [ThemeMode.dark],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'loadTheme stays on system default when nothing persisted',
      build: () => ThemeCubit(),
      act: (cubit) => cubit.loadTheme(),
      expect: () => [],
    );

    test('setThemeMode persists the choice', () async {
      final cubit = ThemeCubit();
      cubit.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
      await cubit.close();
    });

    blocTest<ThemeCubit, ThemeMode>(
      'loadTheme ignores an unknown persisted value',
      setUp: () =>
          SharedPreferences.setMockInitialValues({'theme_mode': 'plaid'}),
      build: () => ThemeCubit(),
      act: (cubit) => cubit.loadTheme(),
      expect: () => [],
    );
  });

  group('ThemeCubit', () {
    blocTest<ThemeCubit, ThemeMode>(
      'initial state is ThemeMode.system',
      build: () => ThemeCubit(),
      verify: (cubit) => expect(cubit.state, ThemeMode.system),
    );

    blocTest<ThemeCubit, ThemeMode>(
      'emits dark when setThemeMode(dark)',
      build: () => ThemeCubit(),
      act: (cubit) => cubit.setThemeMode(ThemeMode.dark),
      expect: () => [ThemeMode.dark],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'emits light then dark',
      build: () => ThemeCubit(),
      act: (cubit) {
        cubit.setThemeMode(ThemeMode.light);
        cubit.setThemeMode(ThemeMode.dark);
      },
      expect: () => [ThemeMode.light, ThemeMode.dark],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'does not emit when same mode is set',
      build: () => ThemeCubit(),
      act: (cubit) => cubit.setThemeMode(ThemeMode.system),
      expect: () => [],
    );
  });
}
