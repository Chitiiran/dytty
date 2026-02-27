import 'package:flutter/foundation.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:intl/intl.dart';

class JournalProvider extends ChangeNotifier {
  JournalRepository? _repository;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  DateTime _selectedDate = DateTime.now();
  List<CategoryEntry> _entries = [];
  Set<String> _daysWithEntries = {};
  bool _loading = false;
  String? _error;

  DateTime get selectedDate => _selectedDate;
  List<CategoryEntry> get entries => _entries;
  Set<String> get daysWithEntries => _daysWithEntries;
  bool get loading => _loading;
  String? get error => _error;

  String get selectedDateString => _dateFormat.format(_selectedDate);

  /// Sets the repository (called when user authenticates).
  void setRepository(JournalRepository repository) {
    _repository = repository;
    notifyListeners();
  }

  /// Clears state (called on sign-out).
  void clear() {
    _repository = null;
    _entries = [];
    _daysWithEntries = {};
    _error = null;
    notifyListeners();
  }

  /// Selects a date and loads its entries.
  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    notifyListeners();
    await loadEntries();
  }

  /// Loads entries for the currently selected date.
  Future<void> loadEntries() async {
    if (_repository == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository!.getCategoryEntries(selectedDateString);
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads calendar markers for a given month.
  Future<void> loadMonthMarkers(int year, int month) async {
    if (_repository == null) return;

    try {
      _daysWithEntries = await _repository!.getDaysWithEntries(year, month);
      notifyListeners();
    } catch (e) {
      // Silently fail for markers — non-critical
    }
  }

  /// Gets entries filtered by category.
  List<CategoryEntry> entriesForCategory(JournalCategory category) {
    return _entries.where((e) => e.category == category).toList();
  }

  /// Adds a new entry.
  Future<void> addEntry(JournalCategory category, String text) async {
    if (_repository == null) return;

    try {
      await _repository!.addCategoryEntry(
        selectedDateString,
        category,
        text,
      );
      await loadEntries();
      // Refresh markers for the current month
      await loadMonthMarkers(_selectedDate.year, _selectedDate.month);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Updates an existing entry.
  Future<void> updateEntry(String entryId, String text) async {
    if (_repository == null) return;

    try {
      await _repository!.updateCategoryEntry(
        selectedDateString,
        entryId,
        text,
      );
      await loadEntries();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Deletes an entry.
  Future<void> deleteEntry(String entryId) async {
    if (_repository == null) return;

    try {
      await _repository!.deleteCategoryEntry(selectedDateString, entryId);
      await loadEntries();
      await loadMonthMarkers(_selectedDate.year, _selectedDate.month);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
