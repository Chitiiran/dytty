import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/constants/voice_note_handling.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/services/notification/notification_service.dart';

export 'package:dytty/core/constants/voice_note_handling.dart'
    show VoiceNoteHandling;

class SettingsState extends Equatable {
  final bool hideEntries;
  final VoiceNoteHandling voiceNoteHandling;
  final bool loaded;
  final bool reminderEnabled;
  final TimeOfDay reminderTime;
  final bool dailyCallEnabled;
  final TimeOfDay dailyCallTime;

  const SettingsState({
    this.hideEntries = false,
    this.voiceNoteHandling = VoiceNoteHandling.ask,
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
    VoiceNoteHandling? voiceNoteHandling,
    bool? loaded,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    bool? dailyCallEnabled,
    TimeOfDay? dailyCallTime,
  }) {
    return SettingsState(
      hideEntries: hideEntries ?? this.hideEntries,
      voiceNoteHandling: voiceNoteHandling ?? this.voiceNoteHandling,
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
    voiceNoteHandling,
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
          voiceNoteHandling: VoiceNoteHandling.fromStorage(
            settings['voiceNoteHandling'] as String?,
          ),
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

  /// Persists the voice-note handling preference (#32), reverting on
  /// repository failure -- same optimistic pattern as toggleHideEntries.
  Future<void> setVoiceNoteHandling(VoiceNoteHandling handling) async {
    final previous = state.voiceNoteHandling;
    if (previous == handling) return;
    emit(state.copyWith(voiceNoteHandling: handling));
    try {
      await _repository.updateUserSettings({
        'voiceNoteHandling': handling.storageValue,
      });
    } catch (_) {
      emit(state.copyWith(voiceNoteHandling: previous));
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
