import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/datasources/database_helper.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/daily_entry.dart';
import 'package:dytty/data/models/voice_session.dart';

class JournalRepository {
  static const _uuid = Uuid();

  // -- Daily Entries --

  Future<DailyEntry> getOrCreateDailyEntry(DateTime date) async {
    final db = await DatabaseHelper.database;
    final dateStr = _dateToString(date);
    final results = await db.query(
      'daily_entries',
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    if (results.isNotEmpty) {
      return DailyEntry.fromMap(results.first);
    }

    final now = DateTime.now();
    final entry = DailyEntry(
      id: _uuid.v4(),
      date: date,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('daily_entries', entry.toMap());
    return entry;
  }

  Future<DailyEntry?> getDailyEntry(DateTime date) async {
    final db = await DatabaseHelper.database;
    final dateStr = _dateToString(date);
    final results = await db.query(
      'daily_entries',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    if (results.isEmpty) return null;
    return DailyEntry.fromMap(results.first);
  }

  Future<List<DailyEntry>> getDailyEntriesInRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'daily_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [_dateToString(start), _dateToString(end)],
      orderBy: 'date DESC',
    );
    return results.map((m) => DailyEntry.fromMap(m)).toList();
  }

  /// Returns dates that have entries in the given month
  Future<Set<DateTime>> getDaysWithEntries(int year, int month) async {
    final db = await DatabaseHelper.database;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final results = await db.query(
      'daily_entries',
      columns: ['date'],
      where: 'date >= ? AND date <= ?',
      whereArgs: [_dateToString(start), _dateToString(end)],
    );
    return results
        .map((m) => DateTime.parse(m['date'] as String))
        .toSet();
  }

  // -- Category Entries --

  Future<List<CategoryEntry>> getCategoryEntries(String dailyEntryId) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'category_entries',
      where: 'daily_entry_id = ?',
      whereArgs: [dailyEntryId],
      orderBy: 'created_at ASC',
    );
    return results.map((m) => CategoryEntry.fromMap(m)).toList();
  }

  Future<List<CategoryEntry>> getCategoryEntriesByType(
    String dailyEntryId,
    JournalCategory category,
  ) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'category_entries',
      where: 'daily_entry_id = ? AND category = ?',
      whereArgs: [dailyEntryId, category.name],
      orderBy: 'created_at ASC',
    );
    return results.map((m) => CategoryEntry.fromMap(m)).toList();
  }

  Future<CategoryEntry> addCategoryEntry({
    required String dailyEntryId,
    required JournalCategory category,
    required String text,
    String? languageHint,
    EntrySource source = EntrySource.manual,
  }) async {
    final db = await DatabaseHelper.database;
    final entry = CategoryEntry(
      id: _uuid.v4(),
      dailyEntryId: dailyEntryId,
      category: category,
      text: text,
      languageHint: languageHint,
      source: source,
      createdAt: DateTime.now(),
    );
    await db.insert('category_entries', entry.toMap());
    await _touchDailyEntry(dailyEntryId);
    return entry;
  }

  Future<void> updateCategoryEntry(String id, String newText) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'category_entries',
      {'text': newText},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategoryEntry(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('category_entries', where: 'id = ?', whereArgs: [id]);
  }

  // -- Voice Sessions --

  Future<VoiceSession> saveVoiceSession({
    required String dailyEntryId,
    required String transcript,
    required int durationSeconds,
    required DateTime startedAt,
  }) async {
    final db = await DatabaseHelper.database;
    final session = VoiceSession(
      id: _uuid.v4(),
      dailyEntryId: dailyEntryId,
      transcript: transcript,
      durationSeconds: durationSeconds,
      startedAt: startedAt,
    );
    await db.insert('voice_sessions', session.toMap());
    return session;
  }

  Future<List<VoiceSession>> getVoiceSessions(String dailyEntryId) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'voice_sessions',
      where: 'daily_entry_id = ?',
      whereArgs: [dailyEntryId],
      orderBy: 'started_at DESC',
    );
    return results.map((m) => VoiceSession.fromMap(m)).toList();
  }

  // -- Settings --

  Future<String?> getSetting(String key) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // -- Helpers --

  Future<void> _touchDailyEntry(String dailyEntryId) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'daily_entries',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [dailyEntryId],
    );
  }

  String _dateToString(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }
}
