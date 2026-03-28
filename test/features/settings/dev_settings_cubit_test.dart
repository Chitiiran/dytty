import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dytty/features/settings/cubit/dev_settings_cubit.dart';

void main() {
  group('DevSettingsCubit', () {
    late DevSettingsCubit cubit;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() => cubit.close());

    test('initial state has useMinimalPrompt false', () {
      cubit = DevSettingsCubit();
      expect(cubit.state, const DevSettingsState());
      expect(cubit.state.useMinimalPrompt, isFalse);
    });

    blocTest<DevSettingsCubit, DevSettingsState>(
      'loadSettings emits state with persisted value',
      setUp: () {
        SharedPreferences.setMockInitialValues({
          'dev_use_minimal_prompt': true,
        });
      },
      build: () {
        cubit = DevSettingsCubit();
        return cubit;
      },
      act: (c) => c.loadSettings(),
      expect: () => [const DevSettingsState(useMinimalPrompt: true)],
    );

    blocTest<DevSettingsCubit, DevSettingsState>(
      'loadSettings emits false when no saved value',
      build: () {
        cubit = DevSettingsCubit();
        return cubit;
      },
      act: (c) => c.loadSettings(),
      expect: () => [const DevSettingsState(useMinimalPrompt: false)],
    );

    blocTest<DevSettingsCubit, DevSettingsState>(
      'togglePromptVariant flips from false to true and persists',
      build: () {
        cubit = DevSettingsCubit();
        return cubit;
      },
      act: (c) => c.togglePromptVariant(),
      expect: () => [const DevSettingsState(useMinimalPrompt: true)],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('dev_use_minimal_prompt'), isTrue);
      },
    );

    blocTest<DevSettingsCubit, DevSettingsState>(
      'togglePromptVariant flips from true to false',
      seed: () => const DevSettingsState(useMinimalPrompt: true),
      build: () {
        cubit = DevSettingsCubit();
        return cubit;
      },
      act: (c) => c.togglePromptVariant(),
      expect: () => [const DevSettingsState(useMinimalPrompt: false)],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('dev_use_minimal_prompt'), isFalse);
      },
    );
  });
}
