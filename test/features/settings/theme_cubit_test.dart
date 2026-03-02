import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/settings/cubit/theme_cubit.dart';

void main() {
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
