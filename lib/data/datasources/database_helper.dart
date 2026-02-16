import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:dytty/core/constants/app_constants.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_entries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE category_entries (
        id TEXT PRIMARY KEY,
        daily_entry_id TEXT NOT NULL,
        category TEXT NOT NULL,
        text TEXT NOT NULL,
        language_hint TEXT,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (daily_entry_id) REFERENCES daily_entries (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE voice_sessions (
        id TEXT PRIMARY KEY,
        daily_entry_id TEXT NOT NULL,
        transcript TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        FOREIGN KEY (daily_entry_id) REFERENCES daily_entries (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_category_entries_daily ON category_entries (daily_entry_id)',
    );
    await db.execute(
      'CREATE INDEX idx_voice_sessions_daily ON voice_sessions (daily_entry_id)',
    );
  }

  /// For testing: close and reset the database instance
  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
