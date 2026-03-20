import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_timezone/timezone_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Returns the device's IANA timezone name (e.g. "America/Toronto").
typedef TimezoneResolver = Future<String> Function();

class NotificationService {
  static const _channelId = 'dytty_daily_reminder';
  static const _channelName = 'Daily Reminder';
  static const _channelDesc = 'Reminds you to journal every day';
  static const _notificationId = 0;

  static const _callChannelId = 'dytty_daily_call';
  static const _callChannelName = 'Daily Call';
  static const _callChannelDesc = 'Daily call reminder';
  static const _callNotificationId = 1;

  static const _prefReminderEnabled = 'reminder_enabled';
  static const _prefReminderHour = 'reminder_hour';
  static const _prefReminderMinute = 'reminder_minute';

  static const _prefDailyCallEnabled = 'daily_call_enabled';
  static const _prefDailyCallHour = 'daily_call_hour';
  static const _prefDailyCallMinute = 'daily_call_minute';

  static const defaultHour = 20; // 8 PM
  static const defaultMinute = 0;

  /// Set to '/voice-call' when the user accepts the daily call notification.
  /// The app checks this on startup/resume and navigates accordingly.
  static String? pendingRoute;

  final FlutterLocalNotificationsPlugin _plugin;
  final TimezoneResolver _timezoneResolver;
  late final SharedPreferences _prefs;

  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    TimezoneResolver? timezoneResolver,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _timezoneResolver = timezoneResolver ?? _defaultTimezoneResolver;

  static Future<String> _defaultTimezoneResolver() async {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  }

  /// Top-level callback for notification responses (required by flutter_local_notifications).
  @pragma('vm:entry-point')
  static void _onNotificationResponse(NotificationResponse response) {
    // Accept action or plain tap on the daily call notification
    if (response.notificationResponseType ==
            NotificationResponseType.selectedNotificationAction &&
        response.actionId == 'accept_call') {
      pendingRoute = '/voice-call';
    } else if (response.notificationResponseType ==
            NotificationResponseType.selectedNotification &&
        response.id == _callNotificationId) {
      pendingRoute = '/voice-call';
    }
    // 'decline_call' action has cancelNotification: true, so nothing to do
  }

  Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneName = await _timezoneResolver();
    tz.setLocalLocation(tz.getLocation(timezoneName));
    _prefs = await SharedPreferences.getInstance();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Re-schedule if reminder was enabled from a previous session
    if (isReminderEnabled) {
      await scheduleDailyReminder(hour: reminderHour, minute: reminderMinute);
    }

    // Re-schedule if daily call was enabled from a previous session
    if (isDailyCallEnabled) {
      await scheduleDailyCall(hour: dailyCallHour, minute: dailyCallMinute);
    }
  }

  bool get isReminderEnabled => _prefs.getBool(_prefReminderEnabled) ?? false;

  int get reminderHour => _prefs.getInt(_prefReminderHour) ?? defaultHour;

  int get reminderMinute => _prefs.getInt(_prefReminderMinute) ?? defaultMinute;

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

  // -- Daily call notification --

  bool get isDailyCallEnabled => _prefs.getBool(_prefDailyCallEnabled) ?? false;

  int get dailyCallHour => _prefs.getInt(_prefDailyCallHour) ?? defaultHour;

  int get dailyCallMinute =>
      _prefs.getInt(_prefDailyCallMinute) ?? defaultMinute;

  Future<void> scheduleDailyCall({
    required int hour,
    required int minute,
  }) async {
    // Skip on web -- local notifications not supported
    if (kIsWeb) {
      await _prefs.setBool(_prefDailyCallEnabled, true);
      await _prefs.setInt(_prefDailyCallHour, hour);
      await _prefs.setInt(_prefDailyCallMinute, minute);
      return;
    }

    await _plugin.cancel(id: _callNotificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _callChannelId,
      _callChannelName,
      channelDescription: _callChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          'accept_call',
          'Accept',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'decline_call',
          'Decline',
          cancelNotification: true,
        ),
      ],
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: _callNotificationId,
      title: 'Time for your daily reflection',
      body: 'Dytty is ready to chat. Tap to start your daily call.',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _prefs.setBool(_prefDailyCallEnabled, true);
    await _prefs.setInt(_prefDailyCallHour, hour);
    await _prefs.setInt(_prefDailyCallMinute, minute);
  }

  Future<void> cancelDailyCall() async {
    if (!kIsWeb) {
      await _plugin.cancel(id: _callNotificationId);
    }
    await _prefs.setBool(_prefDailyCallEnabled, false);
  }

  /// Request notification permission (Android 13+, iOS).
  /// Returns true if permission is granted (including already-granted).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      // requestNotificationsPermission() can return null when permission
      // is already granted on some devices. Check areNotificationsEnabled()
      // as a fallback.
      final result = await android.requestNotificationsPermission();
      if (result == true) return true;
      return await android.areNotificationsEnabled() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
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
