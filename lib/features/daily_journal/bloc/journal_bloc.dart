import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';

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

class LoadMonthMarkers extends JournalEvent {
  final int year;
  final int month;

  const LoadMonthMarkers({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

// --- State ---

enum JournalStatus { initial, loading, loaded, error }

class JournalState extends Equatable {
  final JournalStatus status;
  final DateTime selectedDate;
  final List<CategoryEntry> entries;
  final Set<String> daysWithEntries;
  final String? error;

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  JournalState({
    this.status = JournalStatus.initial,
    DateTime? selectedDate,
    this.entries = const [],
    this.daysWithEntries = const {},
    this.error,
  }) : selectedDate = selectedDate ?? DateTime.now();

  String get selectedDateString => _dateFormat.format(selectedDate);

  List<CategoryEntry> entriesForCategory(JournalCategory category) {
    return entries.where((e) => e.category == category).toList();
  }

  JournalState copyWith({
    JournalStatus? status,
    DateTime? selectedDate,
    List<CategoryEntry>? entries,
    Set<String>? daysWithEntries,
    String? error,
  }) {
    return JournalState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      entries: entries ?? this.entries,
      daysWithEntries: daysWithEntries ?? this.daysWithEntries,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [status, selectedDate, entries, daysWithEntries, error];
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
    on<UpdateEntry>(_onUpdateEntry);
    on<DeleteEntry>(_onDeleteEntry);
    on<LoadMonthMarkers>(_onLoadMonthMarkers);
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
      emit(state.copyWith(
        status: JournalStatus.loaded,
        entries: entries,
        daysWithEntries: markers,
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
      emit(state.copyWith(
        status: JournalStatus.loaded,
        entries: entries,
        daysWithEntries: markers,
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
}
