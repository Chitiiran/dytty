import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';
import 'package:dytty/services/notification/notification_service.dart';

/// Fake NotificationService that does nothing (no platform calls).
class FakeNotificationService extends NotificationService {
  bool _enabled = false;
  int _hour = NotificationService.defaultHour;
  int _minute = NotificationService.defaultMinute;

  @override
  Future<void> init() async {}

  @override
  bool get isReminderEnabled => _enabled;

  @override
  int get reminderHour => _hour;

  @override
  int get reminderMinute => _minute;

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    _enabled = true;
    _hour = hour;
    _minute = minute;
  }

  @override
  Future<void> cancelReminder() async {
    _enabled = false;
  }

  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late JournalRepository repository;
  late FakeNotificationService notificationService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = JournalRepository(uid: 'test-user', firestore: firestore);
    notificationService = FakeNotificationService();
  });

  group('SettingsCubit', () {
    test('initial state has hideEntries false and loaded false', () {
      final cubit = SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      );
      expect(cubit.state.hideEntries, false);
      expect(cubit.state.loaded, false);
    });

    blocTest<SettingsCubit, SettingsState>(
      'loadSettings emits loaded state with defaults',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsState>()
            .having((s) => s.hideEntries, 'hideEntries', false)
            .having((s) => s.loaded, 'loaded', true),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'loadSettings reads persisted hideEntries=true',
      setUp: () async {
        await repository.ensureUserProfile('Test', 'test@test.com');
        await repository.updateUserSettings({'hideEntries': true});
      },
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsState>()
            .having((s) => s.hideEntries, 'hideEntries', true)
            .having((s) => s.loaded, 'loaded', true),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleHideEntries toggles value and persists',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(hideEntries: false, loaded: true),
      act: (cubit) => cubit.toggleHideEntries(),
      expect: () => [
        isA<SettingsState>()
            .having((s) => s.hideEntries, 'hideEntries', true)
            .having((s) => s.loaded, 'loaded', true),
      ],
      verify: (_) async {
        final settings = await repository.getUserSettings();
        expect(settings['hideEntries'], true);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleHideEntries twice returns to original',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(hideEntries: false, loaded: true),
      act: (cubit) async {
        await cubit.toggleHideEntries();
        await cubit.toggleHideEntries();
      },
      expect: () => [
        isA<SettingsState>()
            .having((s) => s.hideEntries, 'hideEntries', true),
        isA<SettingsState>()
            .having((s) => s.hideEntries, 'hideEntries', false),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleReminder enables and schedules',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(loaded: true),
      act: (cubit) => cubit.toggleReminder(),
      expect: () => [
        isA<SettingsState>()
            .having((s) => s.reminderEnabled, 'reminderEnabled', true),
      ],
      verify: (_) {
        expect(notificationService.isReminderEnabled, true);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleReminder disables and cancels',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(loaded: true, reminderEnabled: true),
      act: (cubit) => cubit.toggleReminder(),
      expect: () => [
        isA<SettingsState>()
            .having((s) => s.reminderEnabled, 'reminderEnabled', false),
      ],
      verify: (_) {
        expect(notificationService.isReminderEnabled, false);
      },
    );
  });
}
