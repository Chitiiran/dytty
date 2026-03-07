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

  const AddEntry({required this.category, required this.text});

  @override
  List<Object?> get props => [category, text];
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

  const AddVoiceEntry({
    required this.category,
    required this.text,
    required this.transcript,
    this.tags = const [],
  });

  @override
  List<Object?> get props => [category, text, transcript, tags];
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

enum JournalStatus { initial, loading, loaded, error }

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
      emit(state.copyWith(status: JournalStatus.loaded, entries: entries));
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
    try {
      await _repository.addCategoryEntry(
        state.selectedDateString,
        event.category,
        event.text,
      );
      final entries = await _repository.getCategoryEntries(
        state.selectedDateString,
      );
      final markers = await _repository.getDaysWithEntries(
        state.selectedDate.year,
        state.selectedDate.month,
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

  Future<void> _onAddVoiceEntry(
    AddVoiceEntry event,
    Emitter<JournalState> emit,
  ) async {
    try {
      await _repository.addCategoryEntry(
        state.selectedDateString,
        event.category,
        event.text,
        source: 'voice',
        transcript: event.transcript,
        tags: event.tags,
      );
      final entries = await _repository.getCategoryEntries(
        state.selectedDateString,
      );
      final markers = await _repository.getDaysWithEntries(
        state.selectedDate.year,
        state.selectedDate.month,
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

  Future<void> _onUpdateEntry(
    UpdateEntry event,
    Emitter<JournalState> emit,
  ) async {
    try {
      await _repository.updateCategoryEntry(
        state.selectedDateString,
        event.entryId,
        event.text,
      );
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

  Future<void> _onDeleteEntry(
    DeleteEntry event,
    Emitter<JournalState> emit,
  ) async {
    try {
      await _repository.deleteCategoryEntry(
        state.selectedDateString,
        event.entryId,
      );
      final entries = await _repository.getCategoryEntries(
        state.selectedDateString,
      );
      final markers = await _repository.getDaysWithEntries(
        state.selectedDate.year,
        state.selectedDate.month,
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
