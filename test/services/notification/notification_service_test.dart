import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:dytty/services/notification/notification_service.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late NotificationService service;

  setUpAll(() {
    // Register fallback values for types used in verify/when matchers
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime.now(tz.UTC));
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
  });

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    service = NotificationService(plugin: mockPlugin);

    // Default stubs for plugin methods
    when(
      () => mockPlugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
        onDidReceiveBackgroundNotificationResponse: any(
          named: 'onDidReceiveBackgroundNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);

    when(
      () => mockPlugin.cancel(
        id: any(named: 'id'),
        tag: any(named: 'tag'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockPlugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);

    when(
      () => mockPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);
  });

  group('NotificationService constructor', () {
    test('accepts an injected plugin', () {
      final svc = NotificationService(plugin: mockPlugin);
      expect(svc, isNotNull);
    });

    test('creates default plugin when none provided', () {
      final svc = NotificationService();
      expect(svc, isNotNull);
    });
  });

  group('NotificationService.init', () {
    test('initializes plugin and timezone', () async {
      SharedPreferences.setMockInitialValues({});

      await service.init();

      verify(
        () => mockPlugin.initialize(
          settings: any(named: 'settings'),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).called(1);
    });

    test('re-schedules reminder if previously enabled', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_enabled': true,
        'reminder_hour': 9,
        'reminder_minute': 30,
      });

      await service.init();

      // init calls scheduleDailyReminder which calls cancel then zonedSchedule
      verify(() => mockPlugin.cancel(id: 0, tag: any(named: 'tag'))).called(1);
      verify(
        () => mockPlugin.zonedSchedule(
          id: 0,
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('re-schedules daily call if previously enabled', () async {
      SharedPreferences.setMockInitialValues({
        'daily_call_enabled': true,
        'daily_call_hour': 14,
        'daily_call_minute': 0,
      });

      await service.init();

      // scheduleDailyCall calls cancel(id: 1) then zonedSchedule(id: 1)
      verify(() => mockPlugin.cancel(id: 1, tag: any(named: 'tag'))).called(1);
      verify(
        () => mockPlugin.zonedSchedule(
          id: 1,
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test(
      'does not schedule anything when nothing was previously enabled',
      () async {
        SharedPreferences.setMockInitialValues({});

        await service.init();

        verifyNever(
          () => mockPlugin.cancel(
            id: any(named: 'id'),
            tag: any(named: 'tag'),
          ),
        );
        verifyNever(
          () => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          ),
        );
      },
    );

    test('re-schedules both reminder and daily call if both enabled', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_enabled': true,
        'reminder_hour': 8,
        'reminder_minute': 0,
        'daily_call_enabled': true,
        'daily_call_hour': 20,
        'daily_call_minute': 0,
      });

      await service.init();

      // Two cancel calls (id 0 and id 1)
      verify(() => mockPlugin.cancel(id: 0, tag: any(named: 'tag'))).called(1);
      verify(() => mockPlugin.cancel(id: 1, tag: any(named: 'tag'))).called(1);
    });
  });

  group('preference getters', () {
    test('isReminderEnabled defaults to false', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();
      expect(service.isReminderEnabled, isFalse);
    });

    test('isReminderEnabled returns true when set', () async {
      SharedPreferences.setMockInitialValues({'reminder_enabled': true});
      await service.init();
      expect(service.isReminderEnabled, isTrue);
    });

    test('reminderHour defaults to 20', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();
      expect(service.reminderHour, 20);
    });

    test('reminderHour returns stored value', () async {
      SharedPreferences.setMockInitialValues({'reminder_hour': 7});
      await service.init();
      expect(service.reminderHour, 7);
    });

    test('reminderMinute defaults to 0', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();
      expect(service.reminderMinute, 0);
    });

    test('reminderMinute returns stored value', () async {
      SharedPreferences.setMockInitialValues({'reminder_minute': 45});
      await service.init();
      expect(service.reminderMinute, 45);
    });

    test('isDailyCallEnabled defaults to false', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();
      expect(service.isDailyCallEnabled, isFalse);
    });

    test('isDailyCallEnabled returns true when set', () async {
      SharedPreferences.setMockInitialValues({'daily_call_enabled': true});
      await service.init();
      expect(service.isDailyCallEnabled, isTrue);
    });

    test('dailyCallHour defaults to 20', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();
      expect(service.dailyCallHour, 20);
    });

    test('dailyCallHour returns stored value', () async {
      SharedPreferences.setMockInitialValues({'daily_call_hour': 15});
      await service.init();
      expect(service.dailyCallHour, 15);
    });

    test('dailyCallMinute defaults to 0', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();
      expect(service.dailyCallMinute, 0);
    });

    test('dailyCallMinute returns stored value', () async {
      SharedPreferences.setMockInitialValues({'daily_call_minute': 30});
      await service.init();
      expect(service.dailyCallMinute, 30);
    });
  });

  group('default constants', () {
    test('defaultHour is 20 (8 PM)', () {
      expect(NotificationService.defaultHour, 20);
    });

    test('defaultMinute is 0', () {
      expect(NotificationService.defaultMinute, 0);
    });
  });

  group('scheduleDailyReminder', () {
    test('cancels existing and schedules new notification', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();

      await service.scheduleDailyReminder(hour: 9, minute: 15);

      verify(() => mockPlugin.cancel(id: 0, tag: any(named: 'tag'))).called(1);
      verify(
        () => mockPlugin.zonedSchedule(
          id: 0,
          title: 'Time to reflect',
          body: "Take a moment to journal today's experiences.",
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('persists enabled state and time to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();

      await service.scheduleDailyReminder(hour: 7, minute: 30);

      expect(service.isReminderEnabled, isTrue);
      expect(service.reminderHour, 7);
      expect(service.reminderMinute, 30);
    });

    test('updates time when rescheduled', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_enabled': true,
        'reminder_hour': 8,
        'reminder_minute': 0,
      });
      await service.init();

      await service.scheduleDailyReminder(hour: 21, minute: 45);

      expect(service.reminderHour, 21);
      expect(service.reminderMinute, 45);
    });
  });

  group('cancelReminder', () {
    test('cancels notification and sets enabled to false', () async {
      SharedPreferences.setMockInitialValues({'reminder_enabled': true});
      await service.init();
      // Reset interactions from init's re-scheduling
      reset(mockPlugin);
      when(
        () => mockPlugin.cancel(
          id: any(named: 'id'),
          tag: any(named: 'tag'),
        ),
      ).thenAnswer((_) async {});

      await service.cancelReminder();

      verify(() => mockPlugin.cancel(id: 0, tag: any(named: 'tag'))).called(1);
      expect(service.isReminderEnabled, isFalse);
    });

    test('sets enabled to false even when already disabled', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();

      await service.cancelReminder();

      expect(service.isReminderEnabled, isFalse);
    });
  });

  group('scheduleDailyCall', () {
    test('cancels existing and schedules new call notification', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();

      await service.scheduleDailyCall(hour: 14, minute: 0);

      verify(() => mockPlugin.cancel(id: 1, tag: any(named: 'tag'))).called(1);
      verify(
        () => mockPlugin.zonedSchedule(
          id: 1,
          title: 'Time for your daily reflection',
          body: 'Dytty is ready to chat. Tap to start your daily call.',
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('persists enabled state and time to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();

      await service.scheduleDailyCall(hour: 18, minute: 30);

      expect(service.isDailyCallEnabled, isTrue);
      expect(service.dailyCallHour, 18);
      expect(service.dailyCallMinute, 30);
    });

    test('updates time when rescheduled', () async {
      SharedPreferences.setMockInitialValues({
        'daily_call_enabled': true,
        'daily_call_hour': 14,
        'daily_call_minute': 0,
      });
      await service.init();

      await service.scheduleDailyCall(hour: 19, minute: 15);

      expect(service.dailyCallHour, 19);
      expect(service.dailyCallMinute, 15);
    });
  });

  group('cancelDailyCall', () {
    test('cancels notification and sets enabled to false', () async {
      SharedPreferences.setMockInitialValues({'daily_call_enabled': true});
      await service.init();
      // Reset interactions from init's re-scheduling
      reset(mockPlugin);
      when(
        () => mockPlugin.cancel(
          id: any(named: 'id'),
          tag: any(named: 'tag'),
        ),
      ).thenAnswer((_) async {});

      await service.cancelDailyCall();

      verify(() => mockPlugin.cancel(id: 1, tag: any(named: 'tag'))).called(1);
      expect(service.isDailyCallEnabled, isFalse);
    });

    test('sets enabled to false even when already disabled', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();

      await service.cancelDailyCall();

      expect(service.isDailyCallEnabled, isFalse);
    });
  });

  group('requestPermission', () {
    test('returns false when no platform implementation available', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();

      final result = await service.requestPermission();

      expect(result, isFalse);
    });
  });

  group('pendingRoute (static)', () {
    setUp(() {
      // Reset static state between tests
      NotificationService.pendingRoute = null;
    });

    test('defaults to null', () {
      expect(NotificationService.pendingRoute, isNull);
    });

    test('can be set to a route string', () {
      NotificationService.pendingRoute = '/voice-call';
      expect(NotificationService.pendingRoute, '/voice-call');
    });

    test('can be cleared', () {
      NotificationService.pendingRoute = '/voice-call';
      NotificationService.pendingRoute = null;
      expect(NotificationService.pendingRoute, isNull);
    });
  });
}
