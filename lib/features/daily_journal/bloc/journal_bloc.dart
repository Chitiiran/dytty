import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';

export 'package:dytty/data/repositories/journal_repository.dart'
    show StreakData;

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
  final String categoryId;
  final String text;
  final DateTime? date;

  const AddEntry({required this.categoryId, required this.text, this.date});

  @override
  List<Object?> get props => [categoryId, text, date];
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
  final String categoryId;
  final String text;
  final String transcript;
  final List<String> tags;
  final DateTime? date;

  const AddVoiceEntry({
    required this.categoryId,
    required this.text,
    required this.transcript,
    this.tags = const [],
    this.date,
  });

  @override
  List<Object?> get props => [categoryId, text, transcript, tags, date];
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

/// Internal event: fired when the entry stream emits new data.
class _EntriesUpdated extends JournalEvent {
  final List<CategoryEntry> entries;

  const _EntriesUpdated(this.entries);

  @override
  List<Object?> get props => [entries];
}

// --- State ---

enum JournalStatus { initial, loading, saving, loaded, error }

class JournalState extends Equatable {
  final JournalStatus status;
  final DateTime selectedDate;
  final List<CategoryEntry> entries;
  final Map<String, Map<String, int>> monthCategoryMarkers;
  final int currentStreak;
  final String? lastJournalDate;
  final String? error;

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  JournalState({
    this.status = JournalStatus.initial,
    DateTime? selectedDate,
    this.entries = const [],
    this.monthCategoryMarkers = const {},
    this.currentStreak = 0,
    this.lastJournalDate,
    this.error,
  }) : selectedDate = selectedDate ?? DateTime.now();

  String get selectedDateString => _dateFormat.format(selectedDate);

  /// Backward-compatible derived getter — dates that have any entries.
  Set<String> get daysWithEntries => monthCategoryMarkers.keys.toSet();

  /// Whether the user has journaled today (based on monthCategoryMarkers).
  bool get journaledToday {
    final now = DateTime.now();
    final todayStr = _dateFormat.format(now);
    return daysWithEntries.contains(todayStr);
  }

  List<CategoryEntry> entriesForCategory(String categoryId) {
    return entries.where((e) => e.categoryId == categoryId).toList();
  }

  JournalState copyWith({
    JournalStatus? status,
    DateTime? selectedDate,
    List<CategoryEntry>? entries,
    Map<String, Map<String, int>>? monthCategoryMarkers,
    int? currentStreak,
    String? lastJournalDate,
    String? error,
  }) {
    return JournalState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      entries: entries ?? this.entries,
      monthCategoryMarkers: monthCategoryMarkers ?? this.monthCategoryMarkers,
      currentStreak: currentStreak ?? this.currentStreak,
      lastJournalDate: lastJournalDate ?? this.lastJournalDate,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedDate,
    entries,
    monthCategoryMarkers,
    currentStreak,
    lastJournalDate,
    error,
  ];
}

// --- Bloc ---

class JournalBloc extends Bloc<JournalEvent, JournalState> {
  final JournalRepository _repository;

  /// Month-level cache: "yyyy-MM" → per-date per-category counts.
  final Map<String, Map<String, Map<String, int>>> _markerCache = {};

  /// Active subscription to the selected date's entries.
  StreamSubscription<List<CategoryEntry>>? _entriesSubscription;

  /// Exposes the repository for sibling blocs that share the same data source.
  JournalRepository get repository => _repository;

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
    on<_EntriesUpdated>(_onEntriesUpdated);
  }

  String _cacheKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  /// Deep-copies monthCategoryMarkers to avoid mutating frozen state.
  Map<String, Map<String, int>> _cloneMarkers(
    Map<String, Map<String, int>> source,
  ) {
    return source.map((k, v) => MapEntry(k, Map<String, int>.from(v)));
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
      emit(state.copyWith(status: JournalStatus.error, error: e.toString()));
    }
  }

  Future<void> _onSelectDate(
    SelectDate event,
    Emitter<JournalState> emit,
  ) async {
    emit(
      state.copyWith(selectedDate: event.date, status: JournalStatus.loading),
    );

    // Cancel previous date's subscription
    await _entriesSubscription?.cancel();

    try {
      final dateString = JournalState._dateFormat.format(event.date);

      // Subscribe to entry stream (cache-first, auto-updates on sync)
      _entriesSubscription = _repository
          .watchCategoryEntries(dateString)
          .listen((entries) => add(_EntriesUpdated(entries)));

      // Fetch markers and streak in parallel
      final results = await Future.wait([
        _repository.getMonthCategoryMarkers(event.date.year, event.date.month),
        _repository.getStreakData(),
      ]);

      final markers = results[0] as Map<String, Map<String, int>>;
      final streak = results[1] as StreakData;

      final key = _cacheKey(event.date.year, event.date.month);
      _markerCache[key] = markers;

      emit(
        state.copyWith(
          status: JournalStatus.loaded,
          monthCategoryMarkers: markers,
          currentStreak: streak.currentStreak,
          lastJournalDate: streak.lastJournalDate,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: JournalStatus.error, error: e.toString()));
    }
  }

  /// Shared optimistic update for both AddEntry and AddVoiceEntry.
  /// Immediately adds the created entry to state.entries so the UI refreshes
  /// without waiting for the Firestore stream (critical on real devices with
  /// network latency). Also updates markers and streak.
  void _emitOptimisticUpdate(
    Emitter<JournalState> emit,
    CategoryEntry created,
    String categoryId,
    DateTime targetDate,
  ) {
    final dateString = JournalState._dateFormat.format(targetDate);

    final currentMarkers = _cloneMarkers(state.monthCategoryMarkers);
    final dateMarkers = currentMarkers[dateString] ?? {};
    dateMarkers[categoryId] = (dateMarkers[categoryId] ?? 0) + 1;
    currentMarkers[dateString] = dateMarkers;

    final focusKey = _cacheKey(targetDate.year, targetDate.month);
    _markerCache[focusKey] = currentMarkers;

    final isNewDay = !state.daysWithEntries.contains(dateString);
    final todayStr = JournalState._dateFormat.format(DateTime.now());
    final yesterdayStr = JournalState._dateFormat.format(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    int optimisticStreak = state.currentStreak;
    if (isNewDay && (dateString == todayStr || dateString == yesterdayStr)) {
      optimisticStreak = state.currentStreak + 1;
    }

    emit(
      state.copyWith(
        status: JournalStatus.loaded,
        entries: [...state.entries.where((e) => e.id != created.id), created],
        monthCategoryMarkers: currentMarkers,
        currentStreak: optimisticStreak,
        lastJournalDate: dateString,
      ),
    );
  }

  Future<void> _onAddEntry(AddEntry event, Emitter<JournalState> emit) async {
    final targetDate = event.date ?? state.selectedDate;
    final dateString = JournalState._dateFormat.format(targetDate);
    final previousDate = state.selectedDate;
    emit(
      state.copyWith(status: JournalStatus.saving, selectedDate: targetDate),
    );

    // Re-subscribe stream if date changed
    if (targetDate != previousDate) {
      await _entriesSubscription?.cancel();
      _entriesSubscription = _repository
          .watchCategoryEntries(dateString)
          .listen((entries) => add(_EntriesUpdated(entries)));
    }

    try {
      final created = await _repository.addCategoryEntry(
        dateString,
        event.categoryId,
        event.text,
      );
      _emitOptimisticUpdate(emit, created, event.categoryId, targetDate);
    } catch (e) {
      emit(state.copyWith(status: JournalStatus.error, error: e.toString()));
    }
  }

  Future<void> _onAddVoiceEntry(
    AddVoiceEntry event,
    Emitter<JournalState> emit,
  ) async {
    final targetDate = event.date ?? state.selectedDate;
    final dateString = JournalState._dateFormat.format(targetDate);
    final previousDate = state.selectedDate;
    emit(
      state.copyWith(status: JournalStatus.saving, selectedDate: targetDate),
    );

    // Re-subscribe stream if date changed
    if (targetDate != previousDate) {
      await _entriesSubscription?.cancel();
      _entriesSubscription = _repository
          .watchCategoryEntries(dateString)
          .listen((entries) => add(_EntriesUpdated(entries)));
    }

    try {
      final created = await _repository.addCategoryEntry(
        dateString,
        event.categoryId,
        event.text,
        source: 'voice',
        transcript: event.transcript,
        tags: event.tags,
      );
      _emitOptimisticUpdate(emit, created, event.categoryId, targetDate);
    } catch (e) {
      emit(state.copyWith(status: JournalStatus.error, error: e.toString()));
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
      // Entries are updated via the stream subscription (_EntriesUpdated).
      emit(state.copyWith(status: JournalStatus.loaded));
    } catch (e) {
      emit(state.copyWith(status: JournalStatus.error, error: e.toString()));
    }
  }

  Future<void> _onDeleteEntry(
    DeleteEntry event,
    Emitter<JournalState> emit,
  ) async {
    emit(state.copyWith(status: JournalStatus.saving));
    try {
      // Look up the deleted entry's category before removing from list.
      // Use indexed search with null fallback to avoid StateError on stale state.
      final deletedEntryIndex = state.entries.indexWhere(
        (e) => e.id == event.entryId,
      );
      final deletedEntry = deletedEntryIndex >= 0
          ? state.entries[deletedEntryIndex]
          : null;

      await _repository.deleteCategoryEntry(
        state.selectedDateString,
        event.entryId,
      );
      // Entries are updated via the stream subscription (_EntriesUpdated).
      // Optimistically update markers only.
      final currentMarkers = _cloneMarkers(state.monthCategoryMarkers);
      final dateStr = state.selectedDateString;
      final dateMarkers = currentMarkers[dateStr];
      if (dateMarkers != null && deletedEntry != null) {
        final count = (dateMarkers[deletedEntry.categoryId] ?? 1) - 1;
        if (count <= 0) {
          dateMarkers.remove(deletedEntry.categoryId);
        } else {
          dateMarkers[deletedEntry.categoryId] = count;
        }
        if (dateMarkers.isEmpty) {
          currentMarkers.remove(dateStr);
        }
      }

      final focusKey = _cacheKey(
        state.selectedDate.year,
        state.selectedDate.month,
      );
      _markerCache[focusKey] = currentMarkers;

      emit(
        state.copyWith(
          status: JournalStatus.loaded,
          monthCategoryMarkers: currentMarkers,
        ),
      );
      // Refresh streak in background (non-blocking for UI)
      try {
        final streak = await _repository.getStreakData();
        emit(
          state.copyWith(
            currentStreak: streak.currentStreak,
            lastJournalDate: streak.lastJournalDate,
          ),
        );
      } catch (_) {
        // Streak refresh is non-critical
      }
    } catch (e) {
      emit(state.copyWith(status: JournalStatus.error, error: e.toString()));
    }
  }

  Future<void> _onLoadMonthMarkers(
    LoadMonthMarkers event,
    Emitter<JournalState> emit,
  ) async {
    try {
      final key = _cacheKey(event.year, event.month);
      if (_markerCache.containsKey(key)) {
        emit(state.copyWith(monthCategoryMarkers: _markerCache[key]));
        return;
      }
      final markers = await _repository.getMonthCategoryMarkers(
        event.year,
        event.month,
      );
      _markerCache[key] = markers;
      emit(state.copyWith(monthCategoryMarkers: markers));
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
      emit(
        state.copyWith(
          currentStreak: streak.currentStreak,
          lastJournalDate: streak.lastJournalDate,
        ),
      );
    } catch (_) {
      // Non-critical — silently fail for streak
    }
  }

  void _onEntriesUpdated(_EntriesUpdated event, Emitter<JournalState> emit) {
    // Don't override saving status — let mutation handlers control transitions.
    final status = state.status == JournalStatus.saving
        ? JournalStatus.saving
        : JournalStatus.loaded;
    emit(state.copyWith(status: status, entries: event.entries));
  }

  @override
  Future<void> close() {
    _entriesSubscription?.cancel();
    return super.close();
  }
}
