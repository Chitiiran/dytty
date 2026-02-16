import 'package:flutter_test/flutter_test.dart';

import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/daily_entry.dart';
import 'package:dytty/data/models/voice_session.dart';
import 'package:dytty/services/llm/mock_llm_service.dart';

void main() {
  group('DailyEntry', () {
    test('toMap and fromMap roundtrip', () {
      final now = DateTime.now();
      final entry = DailyEntry(
        id: 'test-id',
        date: DateTime(2026, 2, 16),
        createdAt: now,
        updatedAt: now,
      );
      final map = entry.toMap();
      final restored = DailyEntry.fromMap(map);

      expect(restored.id, entry.id);
      expect(restored.date.year, 2026);
      expect(restored.date.month, 2);
      expect(restored.date.day, 16);
    });
  });

  group('CategoryEntry', () {
    test('toMap and fromMap roundtrip', () {
      final entry = CategoryEntry(
        id: 'cat-1',
        dailyEntryId: 'daily-1',
        category: JournalCategory.gratitude,
        text: 'Grateful for family',
        languageHint: 'en',
        source: EntrySource.manual,
        createdAt: DateTime.now(),
      );
      final map = entry.toMap();
      final restored = CategoryEntry.fromMap(map);

      expect(restored.id, 'cat-1');
      expect(restored.category, JournalCategory.gratitude);
      expect(restored.text, 'Grateful for family');
      expect(restored.source, EntrySource.manual);
    });
  });

  group('VoiceSession', () {
    test('toMap and fromMap roundtrip', () {
      final session = VoiceSession(
        id: 'vs-1',
        dailyEntryId: 'daily-1',
        transcript: 'Hello world',
        durationSeconds: 120,
        startedAt: DateTime.now(),
      );
      final map = session.toMap();
      final restored = VoiceSession.fromMap(map);

      expect(restored.id, 'vs-1');
      expect(restored.transcript, 'Hello world');
      expect(restored.durationSeconds, 120);
    });
  });

  group('JournalCategory', () {
    test('all 5 categories exist', () {
      expect(JournalCategory.values.length, 5);
    });

    test('displayName returns non-empty strings', () {
      for (final cat in JournalCategory.values) {
        expect(cat.displayName.isNotEmpty, true);
      }
    });

    test('prompt returns non-empty strings', () {
      for (final cat in JournalCategory.values) {
        expect(cat.prompt.isNotEmpty, true);
      }
    });
  });

  group('MockLlmService', () {
    test('starts conversation with greeting', () async {
      final llm = MockLlmService();
      final response = await llm.chat([]);
      expect(response.isNotEmpty, true);
      expect(response.contains('positive'), true);
    });

    test('extracts entries from transcript', () async {
      final llm = MockLlmService();
      final entries = await llm.extractEntries(
        'Line one\nLine two\nLine three\nLine four\nLine five',
      );
      expect(entries.length, 5);
      expect(entries[0].category, JournalCategory.positive);
      expect(entries[4].category, JournalCategory.identity);
    });
  });
}
