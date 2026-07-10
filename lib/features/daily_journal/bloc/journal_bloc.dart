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

  /// Today's per-category entry counts, independent of which month
  /// [monthCategoryMarkers] currently holds. Survives month navigation so
  /// the dashboard (nudge + progress card) always reflects today (#154).
  /// Stored with the date it was computed for; read through
  /// [todayCategoryCounts] which returns empty once that date has passed
  /// (midnight rollover must not show yesterday as "today").
  final Map<String, int> _todayCategoryCounts;

  /// 'yyyy-MM-dd' the stored counts belong to.
  final String todayCountsDate;
  final int currentStreak;
  final String? lastJournalDate;
  final String? error;

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  JournalState({
    this.status = JournalStatus.initial,
    DateTime? selectedDate,
    this.entries = const [],
    this.monthCategoryMarkers = const {},
    Map<String, int>? todayCategoryCounts,
    String? todayCountsDate,
    this.currentStreak = 0,
    this.lastJournalDate,
    this.error,
  }) : selectedDate = selectedDate ?? DateTime.now(),
       // Derive from markers when not explicitly provided, so directly
       // constructed states (tests, initial load) stay consistent.
       _todayCategoryCounts =
           todayCategoryCounts ??
           Map<String, int>.from(
             monthCategoryMarkers[_dateFormat.format(DateTime.now())] ??
                 const {},
           ),
       todayCountsDate = todayCountsDate ?? _dateFormat.format(DateTime.now());

  String get selectedDateString => _dateFormat.format(selectedDate);

  /// Backward-compatible derived getter — dates that have any entries.
  Set<String> get daysWithEntries => monthCategoryMarkers.keys.toSet();

  /// Today's counts, empty when the stored counts are for a past date
  /// (midnight rollover).
  Map<String, int> get todayCategoryCounts =>
      todayCountsDate == _dateFormat.format(DateTime.now())
      ? _todayCategoryCounts
      : const {};

  /// Whether the user has journaled today.
  bool get journaledToday => todayCategoryCounts.isNotEmpty;

  List<CategoryEntry> entriesForCategory(String categoryId) {
    return entries.where((e) => e.categoryId == categoryId).toList();
  }

  JournalState copyWith({
    JournalStatus? status,
    DateTime? selectedDate,
    List<CategoryEntry>? entries,
    Map<String, Map<String, int>>? monthCategoryMarkers,
    Map<String, int>? todayCategoryCounts,
    int? currentStreak,
    String? lastJournalDate,
    String? error,
  }) {
    return JournalState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      entries: entries ?? this.entries,
      monthCategoryMarkers: monthCategoryMarkers ?? this.monthCategoryMarkers,
      todayCategoryCounts: todayCategoryCounts ?? _todayCategoryCounts,
      // Fresh counts are always computed "for now" — restamp their date.
      // Preserved counts keep their original date so the rollover gate
      // in the getter stays correct.
      todayCountsDate: todayCategoryCounts != null
          ? JournalState._dateFormat.format(DateTime.now())
          : todayCountsDate,
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
    _todayCategoryCounts,
    todayCountsDate,
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

  /// Set synchronously when close() is called — see _resubscribe.
  bool _disposed = false;

  /// Identity of the latest _resubscribe call: concurrent SelectDate
  /// handlers park on the same awaited cancel, and only the newest may
  /// subscribe (an earlier one would be overwritten and leak).
  Object? _resubscribeToken;

  /// Tombstones for optimistically deleted entries: a snapshot generated
  /// before the delete can arrive after it and resurrect the entry — and
  /// on web the corrective post-delete emit is unreliable (#205).
  /// Cleared on SelectDate (fresh subscription = fresh server truth).
  final Set<String> _pendingDeletes = {};

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

  /// Today's counts from [markers] when ([year], [month]) is the current
  /// month, else null so copyWith preserves the existing value (#154).
  Map<String, int>? _todayCountsIfCurrentMonth(
    Map<String, Map<String, int>> markers,
    int year,
    int month,
  ) {
    final now = DateTime.now();
    if (year != now.year || month != now.month) return null;
    return Map<String, int>.from(
      markers[JournalState._dateFormat.format(now)] ?? const {},
    );
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

  /// Replaces the active entry-stream subscription with one for [dateString]
  /// (cache-first, auto-updates on sync).
  Future<void> _resubscribe(String dateString) async {
    final token = Object();
    _resubscribeToken = token;
    await _entriesSubscription?.cancel();
    // The bloc can close during the await (sign-out mid date-switch);
    // subscribing then leaks the stream and add()s into a closed bloc.
    // _disposed, not isClosed: close() awaits in-flight handlers before
    // isClosed flips, so a parked handler would never see it. The token
    // drops calls superseded by a newer _resubscribe during the await.
    if (_disposed || _resubscribeToken != token) return;
    _entriesSubscription = _repository
        .watchCategoryEntries(dateString)
        .listen((entries) => add(_EntriesUpdated(entries)));
  }

  Future<void> _onSelectDate(
    SelectDate event,
    Emitter<JournalState> emit,
  ) async {
    emit(
      state.copyWith(selectedDate: event.date, status: JournalStatus.loading),
    );

    // Fresh subscription supersedes any pending delete tombstones.
    _pendingDeletes.clear();

    final dateString = JournalState._dateFormat.format(event.date);
    await _resubscribe(dateString);

    // Fetch markers and streak independently: one failure must not discard
    // the other's data (#189/#49/#151 — a failing streak query silently
    // dropped successfully-fetched month markers).
    String? loadError;

    Future<Map<String, Map<String, int>>?> fetchMarkers() async {
      try {
        return await _repository.getMonthCategoryMarkers(
          event.date.year,
          event.date.month,
        );
      } catch (e) {
        loadError = e.toString();
        return null;
      }
    }

    Future<StreakData?> fetchStreak() async {
      try {
        return await _repository.getStreakData();
      } catch (e) {
        loadError ??= e.toString();
        return null;
      }
    }

    final results = await Future.wait<Object?>([fetchMarkers(), fetchStreak()]);
    final markers = results[0] as Map<String, Map<String, int>>?;
    final streak = results[1] as StreakData?;

    if (markers != null) {
      _markerCache[_cacheKey(event.date.year, event.date.month)] = markers;
    }

    // Nothing usable loaded → error state; partial data → loaded with the
    // error surfaced so the UI can show a banner with retry (#170).
    if (markers == null && streak == null) {
      emit(state.copyWith(status: JournalStatus.error, error: loadError));
      return;
    }

    emit(
      state.copyWith(
        status: JournalStatus.loaded,
        monthCategoryMarkers: markers ?? state.monthCategoryMarkers,
        todayCategoryCounts: markers != null
            ? _todayCountsIfCurrentMonth(
                markers,
                event.date.year,
                event.date.month,
              )
            : null,
        currentStreak: streak?.currentStreak ?? state.currentStreak,
        lastJournalDate: streak?.lastJournalDate ?? state.lastJournalDate,
        error: loadError,
      ),
    );
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

    // Increment today's counts from their current value — the marker map
    // may hold a different month after calendar navigation, so deriving
    // from it would wipe today's other categories (review finding, #154).
    Map<String, int>? todayCounts;
    if (dateString == JournalState._dateFormat.format(DateTime.now())) {
      todayCounts = Map<String, int>.from(state.todayCategoryCounts);
      todayCounts[categoryId] = (todayCounts[categoryId] ?? 0) + 1;
    }

    emit(
      state.copyWith(
        status: JournalStatus.loaded,
        entries: [...state.entries.where((e) => e.id != created.id), created],
        monthCategoryMarkers: currentMarkers,
        todayCategoryCounts: todayCounts,
        currentStreak: optimisticStreak,
        lastJournalDate: dateString,
      ),
    );
  }

  /// Shared add flow for manual and voice entries: pin the target date,
  /// re-subscribe if it changed, persist, optimistic update. The two event
  /// handlers previously duplicated this block verbatim.
  Future<void> _handleAdd(
    Emitter<JournalState> emit, {
    required String categoryId,
    required String text,
    DateTime? date,
    String source = 'manual',
    String? transcript,
    List<String> tags = const [],
  }) async {
    final targetDate = date ?? state.selectedDate;
    final dateString = JournalState._dateFormat.format(targetDate);
    final previousDate = state.selectedDate;
    emit(
      state.copyWith(status: JournalStatus.saving, selectedDate: targetDate),
    );

    // Re-subscribe stream if date changed
    if (targetDate != previousDate) {
      await _resubscribe(dateString);
    }

    try {
      final created = await _repository.addCategoryEntry(
        dateString,
        categoryId,
        text,
        source: source,
        transcript: transcript,
        tags: tags,
      );
      _emitOptimisticUpdate(emit, created, categoryId, targetDate);
    } catch (e) {
      emit(state.copyWith(status: JournalStatus.error, error: e.toString()));
    }
  }

  Future<void> _onAddEntry(AddEntry event, Emitter<JournalState> emit) =>
      _handleAdd(
        emit,
        categoryId: event.categoryId,
        text: event.text,
        date: event.date,
      );

  Future<void> _onAddVoiceEntry(
    AddVoiceEntry event,
    Emitter<JournalState> emit,
  ) => _handleAdd(
    emit,
    categoryId: event.categoryId,
    text: event.text,
    date: event.date,
    source: 'voice',
    transcript: event.transcript,
    tags: event.tags,
  );

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
      _pendingDeletes.add(event.entryId);
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

      // Decrement today's counts from their current value, not from the
      // marker map (which may hold another month — review finding, #154).
      Map<String, int>? todayCounts;
      if (dateStr == JournalState._dateFormat.format(DateTime.now()) &&
          deletedEntry != null) {
        todayCounts = Map<String, int>.from(state.todayCategoryCounts);
        final count = (todayCounts[deletedEntry.categoryId] ?? 1) - 1;
        if (count <= 0) {
          todayCounts.remove(deletedEntry.categoryId);
        } else {
          todayCounts[deletedEntry.categoryId] = count;
        }
      }

      emit(
        state.copyWith(
          status: JournalStatus.loaded,
          // Optimistic removal — the web SDK's snapshots emit after a
          // local delete is unreliable (#205), same reason adds are
          // optimistic (#44). The stream reconciles later if needed.
          entries: state.entries.where((e) => e.id != event.entryId).toList(),
          monthCategoryMarkers: currentMarkers,
          todayCategoryCounts: todayCounts,
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
        final cached = _markerCache[key]!;
        emit(
          state.copyWith(
            monthCategoryMarkers: cached,
            todayCategoryCounts: _todayCountsIfCurrentMonth(
              cached,
              event.year,
              event.month,
            ),
          ),
        );
        return;
      }
      final markers = await _repository.getMonthCategoryMarkers(
        event.year,
        event.month,
      );
      _markerCache[key] = markers;
      emit(
        state.copyWith(
          monthCategoryMarkers: markers,
          todayCategoryCounts: _todayCountsIfCurrentMonth(
            markers,
            event.year,
            event.month,
          ),
        ),
      );
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
    // Preserve any pending load error — the cache-first stream otherwise
    // masks marker/streak failures and the user never sees feedback (#170).
    // Filter tombstoned deletes: a pre-delete snapshot arriving late must
    // not resurrect an optimistically removed entry (#205).
    emit(
      state.copyWith(
        status: status,
        entries: event.entries
            .where((e) => !_pendingDeletes.contains(e.id))
            .toList(),
        error: state.error,
      ),
    );
  }

  @override
  Future<void> close() {
    _disposed = true;
    _entriesSubscription?.cancel();
    return super.close();
  }
}
