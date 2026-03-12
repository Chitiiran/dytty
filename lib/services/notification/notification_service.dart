import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _channelId = 'dytty_daily_reminder';
  static const _channelName = 'Daily Reminder';
  static const _channelDesc = 'Reminds you to journal every day';
  static const _notificationId = 0;

  static const _prefReminderEnabled = 'reminder_enabled';
  static const _prefReminderHour = 'reminder_hour';
  static const _prefReminderMinute = 'reminder_minute';

  static const defaultHour = 20; // 8 PM
  static const defaultMinute = 0;

  final FlutterLocalNotificationsPlugin _plugin;
  late final SharedPreferences _prefs;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    _prefs = await SharedPreferences.getInstance();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);

    // Re-schedule if reminder was enabled from a previous session
    if (isReminderEnabled) {
      await scheduleDailyReminder(
        hour: reminderHour,
        minute: reminderMinute,
      );
    }
  }

  bool get isReminderEnabled =>
      _prefs.getBool(_prefReminderEnabled) ?? false;

  int get reminderHour =>
      _prefs.getInt(_prefReminderHour) ?? defaultHour;

  int get reminderMinute =>
      _prefs.getInt(_prefReminderMinute) ?? defaultMinute;

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    // Skip on web — local notifications not supported
    if (kIsWeb) {
      await _prefs.setBool(_prefReminderEnabled, true);
      await _prefs.setInt(_prefReminderHour, hour);
      await _prefs.setInt(_prefReminderMinute, minute);
      return;
    }

    await _plugin.cancel(id: _notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Time to reflect',
      body: "Take a moment to journal today's experiences.",
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _prefs.setBool(_prefReminderEnabled, true);
    await _prefs.setInt(_prefReminderHour, hour);
    await _prefs.setInt(_prefReminderMinute, minute);
  }

  Future<void> cancelReminder() async {
    if (!kIsWeb) {
      await _plugin.cancel(id: _notificationId);
    }
    await _prefs.setBool(_prefReminderEnabled, false);
  }

  /// Request notification permission (Android 13+, iOS).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }
}
