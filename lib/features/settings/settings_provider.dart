import 'package:flutter/foundation.dart';

import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/services/notification/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  final JournalRepository _repository;

  SettingsProvider(this._repository);

  int _reminderHour = 20;
  int _reminderMinute = 0;
  bool _notificationsEnabled = true;

  int get reminderHour => _reminderHour;
  int get reminderMinute => _reminderMinute;
  bool get notificationsEnabled => _notificationsEnabled;

  String get reminderTimeFormatted {
    final h = _reminderHour.toString().padLeft(2, '0');
    final m = _reminderMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> load() async {
    final hour = await _repository.getSetting('reminder_hour');
    final minute = await _repository.getSetting('reminder_minute');
    final enabled = await _repository.getSetting('notifications_enabled');

    _reminderHour = int.tryParse(hour ?? '') ?? 20;
    _reminderMinute = int.tryParse(minute ?? '') ?? 0;
    _notificationsEnabled = enabled != 'false';
    notifyListeners();
  }

  Future<void> setReminderTime(int hour, int minute) async {
    _reminderHour = hour;
    _reminderMinute = minute;
    await _repository.setSetting('reminder_hour', hour.toString());
    await _repository.setSetting('reminder_minute', minute.toString());
    if (_notificationsEnabled) {
      await NotificationService.scheduleDailyReminder(hour, minute);
    }
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _repository.setSetting(
      'notifications_enabled',
      enabled.toString(),
    );
    if (enabled) {
      await NotificationService.scheduleDailyReminder(
        _reminderHour,
        _reminderMinute,
      );
    } else {
      await NotificationService.cancelAll();
    }
    notifyListeners();
  }
}
