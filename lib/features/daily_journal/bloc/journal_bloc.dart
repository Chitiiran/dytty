import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';

export 'package:dytty/data/repositories/journal_repository.dart' show StreakData;

// --- Events ---

sealed class JournalEvent extends Equatable {
  const JournalEvent();

  @override
  List<Object?> get props => [];
}

class LoadEntries extends JournalEvent {
  const LoadEntries();
}

class SelectDate extends JournalEvent {
  final DateTime date;

  const SelectDate(this.date);

  @override
  List<Object?> get props => [date];
}

class AddEntry extends JournalEvent {
  final JournalCategory category;
  final String text;
  final DateTime? date;

  const AddEntry({required this.category, required this.text, this.date});

  @override
  List<Object?> get props => [category, text, date];
}

class UpdateEntry extends JournalEvent {
  final String entryId;
  final String text;

  const UpdateEntry({required this.entryId, required this.text});

  @override
  List<Object?> get props => [entryId, text];
}

class DeleteEntry extends JournalEvent {
  final String entryId;

  const DeleteEntry(this.entryId);

  @override
  List<Object?> get props => [entryId];
}

class AddVoiceEntry extends JournalEvent {
  final JournalCategory category;
  final String text;
  final String transcript;
  final List<String> tags;
  final DateTime? date;

  const AddVoiceEntry({
    required this.category,
    required this.text,
    required this.transcript,
    this.tags = const [],
    this.date,
  });

  @override
  List<Object?> get props => [category, text, transcript, tags, date];
}

class LoadMonthMarkers extends JournalEvent {
  final int year;
  final int month;

  const LoadMonthMarkers({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class LoadStreak extends JournalEvent {
  const LoadStreak();
}

// --- State ---

enum JournalStatus { initial, loading, saving, loaded, error }

class JournalState extends Equatable {
  final JournalStatus status;
  final DateTime selectedDate;
  final List<CategoryEntry> entries;
  final Set<String> daysWithEntries;
  final int currentStreak;
  final String? lastJournalDate;
  final String? error;

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  JournalState({
    this.status = JournalStatus.initial,
    DateTime? selectedDate,
    this.entries = const [],
    this.daysWithEntries = const {},
    this.currentStreak = 0,
    this.lastJournalDate,
    this.error,
  }) : selectedDate = selectedDate ?? DateTime.now();

  String get selectedDateString => _dateFormat.format(selectedDate);

  /// Whether the user has journaled today (based on daysWithEntries).
  bool get journaledToday {
    final now = DateTime.now();
    final todayStr = _dateFormat.format(now);
    return daysWithEntries.contains(todayStr);
  }

  List<CategoryEntry> entriesForCategory(JournalCategory category) {
    return entries.where((e) => e.category == category).toList();
  }

  JournalState copyWith({
    JournalStatus? status,
    DateTime? selectedDate,
    List<CategoryEntry>? entries,
    Set<String>? daysWithEntries,
    int? currentStreak,
    String? lastJournalDate,
    String? error,
  }) {
    return JournalState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      entries: entries ?? this.entries,
      daysWithEntries: daysWithEntries ?? this.daysWithEntries,
      currentStreak: currentStreak ?? this.currentStreak,
      lastJournalDate: lastJournalDate ?? this.lastJournalDate,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [status, selectedDate, entries, daysWithEntries, currentStreak, lastJournalDate, error];
}

// --- Bloc ---

class JournalBloc extends Bloc<JournalEvent, JournalState> {
  final JournalRepository _repository;

  JournalBloc({required JournalRepository repository})
      : _repository = repository,
        super(JournalState()) {
    on<LoadEntries>(_onLoadEntries);
    on<SelectDate>(_onSelectDate);
    on<AddEntry>(_onAddEntry);
    on<AddVoiceEntry>(_onAddVoiceEntry);
    on<UpdateEntry>(_onUpdateEntry);
    on<DeleteEntry>(_onDeleteEntry);
    on<LoadMonthMarkers>(_onLoadMonthMarkers);
    on<LoadStreak>(_onLoadStreak);
  }

  Future<void> _onLoadEntries(
    LoadEntries event,
    Emitter<JournalState> emit,
  ) async {
    emit(state.copyWith(status: JournalStatus.loading));
    try {
      final entries = await _repository.getCategoryEntries(
        state.selectedDateString,
      );
      emit(state.copyWith(status: JournalStatus.loaded, entries: entries));
    } catch (e) {
      emit(state.copyWith(
        status: JournalStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSelectDate(
    SelectDate event,
    Emitter<JournalState> emit,
  ) async {
    emit(state.copyWith(
      selectedDate: event.date,
      status: JournalStatus.loading,
    ));
    try {
      final dateString = JournalState._dateFormat.format(event.date);
      final entries = await _repository.getCategoryEntries(dateString);
      final markers = await _repository.getDaysWithEntries(
        event.date.year,
        event.date.month,
      );
      final streak = await _repository.getStreakData();
      emit(state.copyWith(
        status: JournalStatus.loaded,
        entries: entries,
        daysWithEntries: markers,
        currentStreak: streak.currentStreak,
        lastJournalDate: streak.lastJournalDate,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: JournalStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onAddEntry(
    AddEntry event,
    Emitter<JournalState> emit,
  ) async {
    final targetDate = event.date ?? state.selectedDate;
    final dateString = JournalState._dateFormat.format(targetDate);
    emit(state.copyWith(
      status: JournalStatus.saving,
      selectedDate: targetDate,
    ));
    try {
      final created = await _repository.addCategoryEntry(
        dateString,
        event.category,
        event.text,
      );
      // Optimistic: update UI immediately with the new entry
      final updatedEntries = [...state.entries, created];
      final updatedMarkers = {...state.daysWithEntries, dateString};
      // Optimistic streak: if this date wasn't in markers, it's a new day
      final isNewDay = !state.daysWithEntries.contains(dateString);
      final todayStr = JournalState._dateFormat.format(DateTime.now());
      final yesterdayStr = JournalState._dateFormat.format(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      int optimisticStreak = state.currentStreak;
      if (isNewDay) {
        if (dateString == todayStr || dateString == yesterdayStr) {
          optimisticStreak = state.currentStreak + 1;
        }
      }
      emit(state.copyWith(
        status: JournalStatus.loaded,
        entries: updatedEntries,
        daysWithEntries: updatedMarkers,
        currentStreak: optimisticStreak,
        lastJournalDate: dateString,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: JournalStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onAddVoiceEntry(
    AddVoiceEntry event,
    Emitter<JournalState> emit,
  ) async {
    final targetDate = event.date ?? state.selectedDate;
    final dateString = JournalState._dateFormat.format(targetDate);
    emit(state.copyWith(
      status: JournalStatus.saving,
      selectedDate: targetDate,
    ));
    try {
      final created = await _repository.addCategoryEntry(
        dateString,
        event.category,
        event.text,
        source: 'voice',
        transcript: event.transcript,
        tags: event.tags,
      );
      // Optimistic: update UI immediately with the new entry
      final updatedEntries = [...state.entries, created];
      final updatedMarkers = {...state.daysWithEntries, dateString};
      final isNewDay = !state.daysWithEntries.contains(dateString);
      final todayStr = JournalState._dateFormat.format(DateTime.now());
      final yesterdayStr = JournalState._dateFormat.format(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      int optimisticStreak = state.currentStreak;
      if (isNewDay) {
        if (dateString == todayStr || dateString == yesterdayStr) {
          optimisticStreak = state.currentStreak + 1;
        }
      }
      emit(state.copyWith(
        status: JournalStatus.loaded,
        entries: updatedEntries,
        daysWithEntries: updatedMarkers,
        currentStreak: optimisticStreak,
        lastJournalDate: dateString,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: JournalStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onUpdateEntry(
    UpdateEntry event,
    Emitter<JournalState> emit,
  ) async {
    emit(state.copyWith(status: JournalStatus.saving));
    try {
      await _repository.updateCategoryEntry(
        state.selectedDateString,
        event.entryId,
        event.text,
      );
      // Optimistic: update entry in current list
      final updatedEntries = state.entries.map((e) {
        if (e.id == event.entryId) {
          return CategoryEntry(
            id: e.id,
            category: e.category,
            text: event.text,
            source: e.source,
            createdAt: e.createdAt,
            audioUrl: e.audioUrl,
            transcript: e.transcript,
            tags: e.tags,
          );
        }
        return e;
      }).toList();
      emit(state.copyWith(status: JournalStatus.loaded, entries: updatedEntries));
    } catch (e) {
      emit(state.copyWith(
        status: JournalStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteEntry(
    DeleteEntry event,
    Emitter<JournalState> emit,
  ) async {
    emit(state.copyWith(status: JournalStatus.saving));
    try {
      await _repository.deleteCategoryEntry(
        state.selectedDateString,
        event.entryId,
      );
      // Optimistic: remove entry from current list
      final updatedEntries =
          state.entries.where((e) => e.id != event.entryId).toList();
      final updatedMarkers = updatedEntries.isEmpty
          ? (Set<String>.from(state.daysWithEntries)
            ..remove(state.selectedDateString))
          : state.daysWithEntries;
      emit(state.copyWith(
        status: JournalStatus.loaded,
        entries: updatedEntries,
        daysWithEntries: updatedMarkers,
      ));
      // Refresh streak in background (non-blocking for UI)
      try {
        final streak = await _repository.getStreakData();
        emit(state.copyWith(
          currentStreak: streak.currentStreak,
          lastJournalDate: streak.lastJournalDate,
        ));
      } catch (_) {
        // Streak refresh is non-critical
      }
    } catch (e) {
      emit(state.copyWith(
        status: JournalStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMonthMarkers(
    LoadMonthMarkers event,
    Emitter<JournalState> emit,
  ) async {
    try {
      final markers = await _repository.getDaysWithEntries(
        event.year,
        event.month,
      );
      emit(state.copyWith(daysWithEntries: markers));
    } catch (_) {
      // Non-critical — silently fail for markers
    }
  }

  Future<void> _onLoadStreak(
    LoadStreak event,
    Emitter<JournalState> emit,
  ) async {
    try {
      final streak = await _repository.getStreakData();
      emit(state.copyWith(
        currentStreak: streak.currentStreak,
        lastJournalDate: streak.lastJournalDate,
      ));
    } catch (_) {
      // Non-critical — silently fail for streak
    }
  }
}
