import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';
import 'package:dytty/services/notification/notification_service.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

/// Fake NotificationService that does nothing (no platform calls).
class FakeNotificationService extends NotificationService {
  bool _enabled = false;
  int _hour = NotificationService.defaultHour;
  int _minute = NotificationService.defaultMinute;

  bool _callEnabled = false;
  int _callHour = NotificationService.defaultHour;
  int _callMinute = NotificationService.defaultMinute;

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
  bool get isDailyCallEnabled => _callEnabled;

  @override
  int get dailyCallHour => _callHour;

  @override
  int get dailyCallMinute => _callMinute;

  @override
  Future<void> scheduleDailyCall({
    required int hour,
    required int minute,
  }) async {
    _callEnabled = true;
    _callHour = hour;
    _callMinute = minute;
  }

  @override
  Future<void> cancelDailyCall() async {
    _callEnabled = false;
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
        isA<SettingsState>().having((s) => s.hideEntries, 'hideEntries', true),
        isA<SettingsState>().having((s) => s.hideEntries, 'hideEntries', false),
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
        isA<SettingsState>().having(
          (s) => s.reminderEnabled,
          'reminderEnabled',
          true,
        ),
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
        isA<SettingsState>().having(
          (s) => s.reminderEnabled,
          'reminderEnabled',
          false,
        ),
      ],
      verify: (_) {
        expect(notificationService.isReminderEnabled, false);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleDailyCall enables and schedules',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(loaded: true),
      act: (cubit) => cubit.toggleDailyCall(),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.dailyCallEnabled,
          'dailyCallEnabled',
          true,
        ),
      ],
      verify: (_) {
        expect(notificationService.isDailyCallEnabled, true);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleDailyCall disables and cancels',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(loaded: true, dailyCallEnabled: true),
      act: (cubit) => cubit.toggleDailyCall(),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.dailyCallEnabled,
          'dailyCallEnabled',
          false,
        ),
      ],
      verify: (_) {
        expect(notificationService.isDailyCallEnabled, false);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'setDailyCallTime updates time and reschedules when call enabled',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(loaded: true, dailyCallEnabled: true),
      act: (cubit) =>
          cubit.setDailyCallTime(const TimeOfDay(hour: 9, minute: 30)),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.dailyCallTime,
          'dailyCallTime',
          const TimeOfDay(hour: 9, minute: 30),
        ),
      ],
      verify: (_) {
        expect(notificationService.dailyCallHour, 9);
        expect(notificationService.dailyCallMinute, 30);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'setDailyCallTime updates time without scheduling when call disabled',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(loaded: true, dailyCallEnabled: false),
      act: (cubit) =>
          cubit.setDailyCallTime(const TimeOfDay(hour: 14, minute: 0)),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.dailyCallTime,
          'dailyCallTime',
          const TimeOfDay(hour: 14, minute: 0),
        ),
      ],
      verify: (_) {
        // Should not have scheduled — callHour/callMinute stay at defaults
        expect(
          notificationService.dailyCallHour,
          NotificationService.defaultHour,
        );
        expect(
          notificationService.dailyCallMinute,
          NotificationService.defaultMinute,
        );
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'setReminderTime updates time and reschedules when reminder enabled',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(loaded: true, reminderEnabled: true),
      act: (cubit) =>
          cubit.setReminderTime(const TimeOfDay(hour: 7, minute: 15)),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.reminderTime,
          'reminderTime',
          const TimeOfDay(hour: 7, minute: 15),
        ),
      ],
      verify: (_) {
        expect(notificationService.reminderHour, 7);
        expect(notificationService.reminderMinute, 15);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'setReminderTime updates time without scheduling when reminder disabled',
      build: () => SettingsCubit(
        repository: repository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(loaded: true, reminderEnabled: false),
      act: (cubit) =>
          cubit.setReminderTime(const TimeOfDay(hour: 18, minute: 45)),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.reminderTime,
          'reminderTime',
          const TimeOfDay(hour: 18, minute: 45),
        ),
      ],
      verify: (_) {
        // Should not have scheduled — hour/minute stay at defaults
        expect(
          notificationService.reminderHour,
          NotificationService.defaultHour,
        );
        expect(
          notificationService.reminderMinute,
          NotificationService.defaultMinute,
        );
      },
    );
  });

  group('SettingsCubit error paths', () {
    late MockJournalRepository mockRepository;
    late FakeNotificationService notificationService;

    setUp(() {
      mockRepository = MockJournalRepository();
      notificationService = FakeNotificationService();
    });

    blocTest<SettingsCubit, SettingsState>(
      'loadSettings emits loaded with defaults when repository throws',
      setUp: () {
        when(
          () => mockRepository.getUserSettings(),
        ).thenThrow(Exception('Firestore unavailable'));
      },
      build: () => SettingsCubit(
        repository: mockRepository,
        notificationService: notificationService,
      ),
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsState>()
            .having((s) => s.loaded, 'loaded', true)
            .having((s) => s.hideEntries, 'hideEntries', false),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleHideEntries reverts on repository error',
      setUp: () {
        when(
          () => mockRepository.updateUserSettings(any()),
        ).thenThrow(Exception('Write failed'));
      },
      build: () => SettingsCubit(
        repository: mockRepository,
        notificationService: notificationService,
      ),
      seed: () => const SettingsState(hideEntries: false, loaded: true),
      act: (cubit) => cubit.toggleHideEntries(),
      expect: () => [
        // Optimistically flips to true
        isA<SettingsState>().having((s) => s.hideEntries, 'hideEntries', true),
        // Reverts to false on error
        isA<SettingsState>().having((s) => s.hideEntries, 'hideEntries', false),
      ],
    );
  });
}
