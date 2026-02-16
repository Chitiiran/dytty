import 'package:dytty/core/constants/categories.dart';

enum EntrySource { voice, manual }

class CategoryEntry {
  final String id;
  final String dailyEntryId;
  final JournalCategory category;
  final String text;
  final String? languageHint;
  final EntrySource source;
  final DateTime createdAt;

  CategoryEntry({
    required this.id,
    required this.dailyEntryId,
    required this.category,
    required this.text,
    this.languageHint,
    required this.source,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'daily_entry_id': dailyEntryId,
      'category': category.name,
      'text': text,
      'language_hint': languageHint,
      'source': source.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CategoryEntry.fromMap(Map<String, dynamic> map) {
    return CategoryEntry(
      id: map['id'] as String,
      dailyEntryId: map['daily_entry_id'] as String,
      category: JournalCategory.values.byName(map['category'] as String),
      text: map['text'] as String,
      languageHint: map['language_hint'] as String?,
      source: EntrySource.values.byName(map['source'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  CategoryEntry copyWith({
    String? id,
    String? dailyEntryId,
    JournalCategory? category,
    String? text,
    String? languageHint,
    EntrySource? source,
    DateTime? createdAt,
  }) {
    return CategoryEntry(
      id: id ?? this.id,
      dailyEntryId: dailyEntryId ?? this.dailyEntryId,
      category: category ?? this.category,
      text: text ?? this.text,
      languageHint: languageHint ?? this.languageHint,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
