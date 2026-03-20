import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:dytty/core/utils/date_utils.dart' as app_date;
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/review_summary.dart';
import 'package:dytty/data/repositories/journal_repository.dart';

// --- Events ---

sealed class CategoryDetailEvent extends Equatable {
  const CategoryDetailEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategoryDetail extends CategoryDetailEvent {
  final String categoryId;

  const LoadCategoryDetail(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class ToggleDateGroup extends CategoryDetailEvent {
  final String date;

  const ToggleDateGroup(this.date);

  @override
  List<Object?> get props => [date];
}

class StartInlineEdit extends CategoryDetailEvent {
  final String entryId;

  const StartInlineEdit(this.entryId);

  @override
  List<Object?> get props => [entryId];
}

class SaveInlineEdit extends CategoryDetailEvent {
  final String date;
  final String entryId;
  final String newText;

  const SaveInlineEdit({
    required this.date,
    required this.entryId,
    required this.newText,
  });

  @override
  List<Object?> get props => [date, entryId, newText];
}

class CancelInlineEdit extends CategoryDetailEvent {
  const CancelInlineEdit();
}

class EntryAddedFromCall extends CategoryDetailEvent {
  final CategoryEntry entry;
  final String date;

  const EntryAddedFromCall({required this.entry, required this.date});

  @override
  List<Object?> get props => [entry, date];
}

class EntryEditedFromCall extends CategoryDetailEvent {
  final String entryId;
  final String newText;

  const EntryEditedFromCall({required this.entryId, required this.newText});

  @override
  List<Object?> get props => [entryId, newText];
}

class EntryReference extends Equatable {
  final String date;
  final String entryId;

  const EntryReference({required this.date, required this.entryId});

  @override
  List<Object?> get props => [date, entryId];
}

class MarkEntriesReviewed extends CategoryDetailEvent {
  final List<EntryReference> entries;

  const MarkEntriesReviewed({required this.entries});

  @override
  List<Object?> get props => [entries];
}

class SaveReviewSummaryEvent extends CategoryDetailEvent {
  final ReviewSummary summary;

  const SaveReviewSummaryEvent(this.summary);

  @override
  List<Object?> get props => [summary];
}

// --- State ---

enum CategoryDetailStatus { initial, loading, loaded, error }

class DateGroup extends Equatable {
  final String date;
  final String displayDate;
  final List<CategoryEntry> entries;
  final bool isCollapsed;

  const DateGroup({
    required this.date,
    required this.displayDate,
    required this.entries,
    this.isCollapsed = false,
  });

  DateGroup copyWith({
    String? date,
    String? displayDate,
    List<CategoryEntry>? entries,
    bool? isCollapsed,
  }) {
    return DateGroup(
      date: date ?? this.date,
      displayDate: displayDate ?? this.displayDate,
      entries: entries ?? this.entries,
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }

  @override
  List<Object?> get props => [date, displayDate, entries, isCollapsed];
}

class CategoryDetailState extends Equatable {
  final CategoryDetailStatus status;
  final String categoryId;
  final List<DateGroup> recentEntries;
  final List<DateGroup> olderEntries;
  final ReviewSummary? reviewSummary;
  final bool hasRecentEntries;
  final String? editingEntryId;
  final String? error;

  const CategoryDetailState({
    this.status = CategoryDetailStatus.initial,
    this.categoryId = '',
    this.recentEntries = const [],
    this.olderEntries = const [],
    this.reviewSummary,
    this.hasRecentEntries = false,
    this.editingEntryId,
    this.error,
  });

  CategoryDetailState copyWith({
    CategoryDetailStatus? status,
    String? categoryId,
    List<DateGroup>? recentEntries,
    List<DateGroup>? olderEntries,
    ReviewSummary? reviewSummary,
    bool? hasRecentEntries,
    String? editingEntryId,
    String? error,
    bool clearEditingEntryId = false,
    bool clearReviewSummary = false,
  }) {
    return CategoryDetailState(
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      recentEntries: recentEntries ?? this.recentEntries,
      olderEntries: olderEntries ?? this.olderEntries,
      reviewSummary: clearReviewSummary
          ? null
          : (reviewSummary ?? this.reviewSummary),
      hasRecentEntries: hasRecentEntries ?? this.hasRecentEntries,
      editingEntryId: clearEditingEntryId
          ? null
          : (editingEntryId ?? this.editingEntryId),
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categoryId,
    recentEntries,
    olderEntries,
    reviewSummary,
    hasRecentEntries,
    editingEntryId,
    error,
  ];
}

// --- Bloc ---

class CategoryDetailBloc
    extends Bloc<CategoryDetailEvent, CategoryDetailState> {
  final JournalRepository _repository;
  final DateTime Function() _clock;

  /// Number of days shown in the "recent entries" window.
  static const recentDaysCount = 7;

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  CategoryDetailBloc({
    required JournalRepository repository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now,
       super(const CategoryDetailState()) {
    on<LoadCategoryDetail>(_onLoadCategoryDetail);
    on<ToggleDateGroup>(_onToggleDateGroup);
    on<StartInlineEdit>(_onStartInlineEdit);
    on<SaveInlineEdit>(_onSaveInlineEdit);
    on<CancelInlineEdit>(_onCancelInlineEdit);
    on<EntryAddedFromCall>(_onEntryAddedFromCall);
    on<EntryEditedFromCall>(_onEntryEditedFromCall);
    on<MarkEntriesReviewed>(_onMarkEntriesReviewed);
    on<SaveReviewSummaryEvent>(_onSaveReviewSummary);
  }

  Future<void> _onLoadCategoryDetail(
    LoadCategoryDetail event,
    Emitter<CategoryDetailState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CategoryDetailStatus.loading,
        categoryId: event.categoryId,
      ),
    );

    try {
      final now = _clock();
      final dates = <String>[];
      for (int i = 0; i < recentDaysCount; i++) {
        final day = now.subtract(Duration(days: i));
        dates.add(_dateFormat.format(day));
      }

      // Get days with entries for current and previous month
      final currentMonthDays = await _repository.getDaysWithEntries(
        now.year,
        now.month,
      );
      Set<String> prevMonthDays = {};
      // If the recent-days window could span into the previous month
      if (now.day <= recentDaysCount) {
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        prevMonthDays = await _repository.getDaysWithEntries(
          prevYear,
          prevMonth,
        );
      }
      final allDaysWithEntries = {...currentMonthDays, ...prevMonthDays};

      // Only query dates that have entries
      final datesToQuery = dates
          .where((d) => allDaysWithEntries.contains(d))
          .toList();

      final entriesByDate = await _repository.getCategoryEntriesForDateRange(
        event.categoryId,
        datesToQuery,
      );

      // Build date groups
      final recentGroups = <DateGroup>[];
      for (final date in dates) {
        final entries = entriesByDate[date] ?? [];
        if (entries.isEmpty) continue;

        recentGroups.add(
          DateGroup(
            date: date,
            displayDate: _relativeDate(date, now),
            entries: entries,
            isCollapsed: false,
          ),
        );
      }

      // Get review summary for this week
      final weekStart = app_date.mondayOfWeek(now);
      final summary = await _repository.getReviewSummary(
        event.categoryId,
        _dateFormat.format(weekStart),
      );

      final hasRecent = recentGroups.any((g) => g.entries.isNotEmpty);

      emit(
        state.copyWith(
          status: CategoryDetailStatus.loaded,
          categoryId: event.categoryId,
          recentEntries: recentGroups,
          reviewSummary: summary,
          hasRecentEntries: hasRecent,
          clearReviewSummary: summary == null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: CategoryDetailStatus.error, error: e.toString()),
      );
    }
  }

  Future<void> _onToggleDateGroup(
    ToggleDateGroup event,
    Emitter<CategoryDetailState> emit,
  ) async {
    final updatedGroups = state.recentEntries.map((group) {
      if (group.date == event.date) {
        return group.copyWith(isCollapsed: !group.isCollapsed);
      }
      return group;
    }).toList();

    emit(state.copyWith(recentEntries: updatedGroups));
  }

  Future<void> _onStartInlineEdit(
    StartInlineEdit event,
    Emitter<CategoryDetailState> emit,
  ) async {
    emit(state.copyWith(editingEntryId: event.entryId));
  }

  Future<void> _onSaveInlineEdit(
    SaveInlineEdit event,
    Emitter<CategoryDetailState> emit,
  ) async {
    final previousGroups = state.recentEntries;

    // Optimistic update
    final updatedGroups = state.recentEntries.map((group) {
      if (group.date == event.date) {
        final updatedEntries = group.entries.map((entry) {
          if (entry.id == event.entryId) {
            return entry.copyWith(text: event.newText);
          }
          return entry;
        }).toList();
        return group.copyWith(entries: updatedEntries);
      }
      return group;
    }).toList();

    emit(
      state.copyWith(recentEntries: updatedGroups, clearEditingEntryId: true),
    );

    // Persist to Firestore
    try {
      await _repository.updateCategoryEntry(
        event.date,
        event.entryId,
        event.newText,
      );
    } catch (e) {
      emit(
        state.copyWith(
          recentEntries: previousGroups,
          error: 'Failed to save edit: $e',
        ),
      );
    }
  }

  Future<void> _onCancelInlineEdit(
    CancelInlineEdit event,
    Emitter<CategoryDetailState> emit,
  ) async {
    emit(state.copyWith(clearEditingEntryId: true));
  }

  Future<void> _onEntryAddedFromCall(
    EntryAddedFromCall event,
    Emitter<CategoryDetailState> emit,
  ) async {
    final now = _clock();
    final updatedGroups = List<DateGroup>.from(state.recentEntries);

    // Find the date group for this entry
    final groupIndex = updatedGroups.indexWhere((g) => g.date == event.date);
    if (groupIndex >= 0) {
      final group = updatedGroups[groupIndex];
      updatedGroups[groupIndex] = group.copyWith(
        entries: [...group.entries, event.entry],
      );
    } else {
      // New date group
      updatedGroups.insert(
        0,
        DateGroup(
          date: event.date,
          displayDate: _relativeDate(event.date, now),
          entries: [event.entry],
        ),
      );
    }

    emit(state.copyWith(recentEntries: updatedGroups, hasRecentEntries: true));
  }

  Future<void> _onEntryEditedFromCall(
    EntryEditedFromCall event,
    Emitter<CategoryDetailState> emit,
  ) async {
    final updatedGroups = state.recentEntries.map((group) {
      final updatedEntries = group.entries.map((entry) {
        if (entry.id == event.entryId) {
          return entry.copyWith(text: event.newText);
        }
        return entry;
      }).toList();
      return group.copyWith(entries: updatedEntries);
    }).toList();

    emit(state.copyWith(recentEntries: updatedGroups));
  }

  Future<void> _onMarkEntriesReviewed(
    MarkEntriesReviewed event,
    Emitter<CategoryDetailState> emit,
  ) async {
    // Optimistic update
    final entryIdSet = event.entries.map((e) => e.entryId).toSet();
    final updatedGroups = state.recentEntries.map((group) {
      final updatedEntries = group.entries.map((entry) {
        if (entryIdSet.contains(entry.id)) {
          return entry.copyWith(isReviewed: true);
        }
        return entry;
      }).toList();
      return group.copyWith(entries: updatedEntries);
    }).toList();

    emit(state.copyWith(recentEntries: updatedGroups));

    // Persist to Firestore
    for (final ref in event.entries) {
      try {
        await _repository.markEntryReviewed(ref.date, ref.entryId);
      } catch (e) {
        emit(state.copyWith(error: 'Failed to mark entry as reviewed: $e'));
      }
    }
  }

  Future<void> _onSaveReviewSummary(
    SaveReviewSummaryEvent event,
    Emitter<CategoryDetailState> emit,
  ) async {
    emit(state.copyWith(reviewSummary: event.summary));

    try {
      await _repository.saveReviewSummary(event.summary);
    } catch (e) {
      emit(state.copyWith(error: 'Failed to save review summary: $e'));
    }
  }

  String _relativeDate(String dateStr, DateTime now) {
    final date = DateTime.parse(dateStr);
    final todayStr = _dateFormat.format(now);
    final yesterdayStr = _dateFormat.format(
      now.subtract(const Duration(days: 1)),
    );

    if (dateStr == todayStr) return 'Today';
    if (dateStr == yesterdayStr) return 'Yesterday';

    final diff = now.difference(date).inDays;
    if (diff <= 6) return '$diff days ago';

    return DateFormat('MMM d').format(date);
  }
}
