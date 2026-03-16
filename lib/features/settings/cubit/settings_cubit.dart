import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/services/notification/notification_service.dart';

class SettingsState extends Equatable {
  final bool hideEntries;
  final bool loaded;
  final bool reminderEnabled;
  final TimeOfDay reminderTime;
  final bool dailyCallEnabled;
  final TimeOfDay dailyCallTime;

  const SettingsState({
    this.hideEntries = false,
    this.loaded = false,
    this.reminderEnabled = false,
    this.reminderTime = const TimeOfDay(
      hour: NotificationService.defaultHour,
      minute: NotificationService.defaultMinute,
    ),
    this.dailyCallEnabled = false,
    this.dailyCallTime = const TimeOfDay(
      hour: NotificationService.defaultHour,
      minute: NotificationService.defaultMinute,
    ),
  });

  SettingsState copyWith({
    bool? hideEntries,
    bool? loaded,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    bool? dailyCallEnabled,
    TimeOfDay? dailyCallTime,
  }) {
    return SettingsState(
      hideEntries: hideEntries ?? this.hideEntries,
      loaded: loaded ?? this.loaded,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      dailyCallEnabled: dailyCallEnabled ?? this.dailyCallEnabled,
      dailyCallTime: dailyCallTime ?? this.dailyCallTime,
    );
  }

  @override
  List<Object?> get props => [
    hideEntries,
    loaded,
    reminderEnabled,
    reminderTime,
    dailyCallEnabled,
    dailyCallTime,
  ];
}

class SettingsCubit extends Cubit<SettingsState> {
  final JournalRepository _repository;
  final NotificationService _notificationService;

  SettingsCubit({
    required JournalRepository repository,
    required NotificationService notificationService,
  }) : _repository = repository,
       _notificationService = notificationService,
       super(const SettingsState());

  Future<void> loadSettings() async {
    try {
      final settings = await _repository.getUserSettings();
      emit(
        SettingsState(
          hideEntries: settings['hideEntries'] as bool? ?? false,
          loaded: true,
          reminderEnabled: _notificationService.isReminderEnabled,
          reminderTime: TimeOfDay(
            hour: _notificationService.reminderHour,
            minute: _notificationService.reminderMinute,
          ),
          dailyCallEnabled: _notificationService.isDailyCallEnabled,
          dailyCallTime: TimeOfDay(
            hour: _notificationService.dailyCallHour,
            minute: _notificationService.dailyCallMinute,
          ),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loaded: true,
          reminderEnabled: _notificationService.isReminderEnabled,
          reminderTime: TimeOfDay(
            hour: _notificationService.reminderHour,
            minute: _notificationService.reminderMinute,
          ),
          dailyCallEnabled: _notificationService.isDailyCallEnabled,
          dailyCallTime: TimeOfDay(
            hour: _notificationService.dailyCallHour,
            minute: _notificationService.dailyCallMinute,
          ),
        ),
      );
    }
  }

  Future<void> toggleHideEntries() async {
    final newValue = !state.hideEntries;
    emit(state.copyWith(hideEntries: newValue));
    try {
      await _repository.updateUserSettings({'hideEntries': newValue});
    } catch (_) {
      emit(state.copyWith(hideEntries: !newValue));
    }
  }

  Future<void> toggleReminder() async {
    if (state.reminderEnabled) {
      await _notificationService.cancelReminder();
      emit(state.copyWith(reminderEnabled: false));
    } else {
      final granted = await _notificationService.requestPermission();
      if (granted) {
        await _notificationService.scheduleDailyReminder(
          hour: state.reminderTime.hour,
          minute: state.reminderTime.minute,
        );
        emit(state.copyWith(reminderEnabled: true));
      }
    }
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    emit(state.copyWith(reminderTime: time));
    if (state.reminderEnabled) {
      await _notificationService.scheduleDailyReminder(
        hour: time.hour,
        minute: time.minute,
      );
    }
  }

  Future<void> toggleDailyCall() async {
    if (state.dailyCallEnabled) {
      await _notificationService.cancelDailyCall();
      emit(state.copyWith(dailyCallEnabled: false));
    } else {
      final granted = await _notificationService.requestPermission();
      if (granted) {
        await _notificationService.scheduleDailyCall(
          hour: state.dailyCallTime.hour,
          minute: state.dailyCallTime.minute,
        );
        emit(state.copyWith(dailyCallEnabled: true));
      }
    }
  }

  Future<void> setDailyCallTime(TimeOfDay time) async {
    emit(state.copyWith(dailyCallTime: time));
    if (state.dailyCallEnabled) {
      await _notificationService.scheduleDailyCall(
        hour: time.hour,
        minute: time.minute,
      );
    }
  }
}
