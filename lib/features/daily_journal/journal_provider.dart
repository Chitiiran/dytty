import 'package:flutter/foundation.dart';

import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/daily_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';

class JournalProvider extends ChangeNotifier {
  final JournalRepository _repository;

  JournalProvider(this._repository);

  DailyEntry? _currentEntry;
  List<CategoryEntry> _categoryEntries = [];
  bool _loading = false;

  DailyEntry? get currentEntry => _currentEntry;
  List<CategoryEntry> get categoryEntries => _categoryEntries;
  bool get loading => _loading;

  List<CategoryEntry> entriesFor(JournalCategory category) {
    return _categoryEntries
        .where((e) => e.category == category)
        .toList();
  }

  bool get hasAnyEntries => _categoryEntries.isNotEmpty;

  Future<void> loadDay(DateTime date) async {
    _loading = true;
    notifyListeners();

    _currentEntry = await _repository.getDailyEntry(date);
    if (_currentEntry != null) {
      _categoryEntries = await _repository.getCategoryEntries(
        _currentEntry!.id,
      );
    } else {
      _categoryEntries = [];
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> addEntry({
    required JournalCategory category,
    required String text,
    EntrySource source = EntrySource.manual,
    String? languageHint,
  }) async {
    _currentEntry ??= await _repository.getOrCreateDailyEntry(
      _currentEntry?.date ?? DateTime.now(),
    );

    final entry = await _repository.addCategoryEntry(
      dailyEntryId: _currentEntry!.id,
      category: category,
      text: text,
      source: source,
      languageHint: languageHint,
    );
    _categoryEntries.add(entry);
    notifyListeners();
  }

  Future<void> addEntryForDate({
    required DateTime date,
    required JournalCategory category,
    required String text,
    EntrySource source = EntrySource.manual,
  }) async {
    final dailyEntry = await _repository.getOrCreateDailyEntry(date);
    _currentEntry = dailyEntry;

    final entry = await _repository.addCategoryEntry(
      dailyEntryId: dailyEntry.id,
      category: category,
      text: text,
      source: source,
    );
    _categoryEntries.add(entry);
    notifyListeners();
  }

  Future<void> updateEntry(String entryId, String newText) async {
    await _repository.updateCategoryEntry(entryId, newText);
    final index = _categoryEntries.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      _categoryEntries[index] = _categoryEntries[index].copyWith(
        text: newText,
      );
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String entryId) async {
    await _repository.deleteCategoryEntry(entryId);
    _categoryEntries.removeWhere((e) => e.id == entryId);
    notifyListeners();
  }

  Future<Set<DateTime>> getDaysWithEntries(int year, int month) {
    return _repository.getDaysWithEntries(year, month);
  }
}
