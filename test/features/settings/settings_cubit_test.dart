import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late JournalRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = JournalRepository(uid: 'test-user', firestore: firestore);
  });

  group('SettingsCubit', () {
    test('initial state has hideEntries false and loaded false', () {
      final cubit = SettingsCubit(repository: repository);
      expect(cubit.state.hideEntries, false);
      expect(cubit.state.loaded, false);
    });

    blocTest<SettingsCubit, SettingsState>(
      'loadSettings emits loaded state with defaults',
      build: () => SettingsCubit(repository: repository),
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        const SettingsState(hideEntries: false, loaded: true),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'loadSettings reads persisted hideEntries=true',
      setUp: () async {
        await repository.ensureUserProfile('Test', 'test@test.com');
        await repository.updateUserSettings({'hideEntries': true});
      },
      build: () => SettingsCubit(repository: repository),
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        const SettingsState(hideEntries: true, loaded: true),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleHideEntries toggles value and persists',
      build: () => SettingsCubit(repository: repository),
      seed: () => const SettingsState(hideEntries: false, loaded: true),
      act: (cubit) => cubit.toggleHideEntries(),
      expect: () => [
        const SettingsState(hideEntries: true, loaded: true),
      ],
      verify: (_) async {
        final settings = await repository.getUserSettings();
        expect(settings['hideEntries'], true);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleHideEntries twice returns to original',
      build: () => SettingsCubit(repository: repository),
      seed: () => const SettingsState(hideEntries: false, loaded: true),
      act: (cubit) async {
        await cubit.toggleHideEntries();
        await cubit.toggleHideEntries();
      },
      expect: () => [
        const SettingsState(hideEntries: true, loaded: true),
        const SettingsState(hideEntries: false, loaded: true),
      ],
    );
  });
}
