import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/daily_journal/journal_provider.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late JournalRepository repository;
  late JournalProvider provider;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = JournalRepository(uid: 'test-user', firestore: firestore);
    provider = JournalProvider();
    provider.setRepository(repository);
  });

  group('JournalProvider', () {
    group('selectDate', () {
      test('updates selectedDate and loads entries', () async {
        final date = DateTime(2026, 2, 27);
        await provider.selectDate(date);

        expect(provider.selectedDate, date);
        expect(provider.loading, false);
        expect(provider.entries, isEmpty);
      });

      test('selectedDateString matches format', () async {
        await provider.selectDate(DateTime(2026, 2, 27));
        expect(provider.selectedDateString, '2026-02-27');
      });
    });

    group('loadEntries', () {
      test('loads entries for selected date', () async {
        await provider.selectDate(DateTime(2026, 2, 27));
        await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.positive,
          'Good thing',
        );

        await provider.loadEntries();

        expect(provider.entries.length, 1);
        expect(provider.entries.first.text, 'Good thing');
      });

      test('does nothing without repository', () async {
        final noRepoProvider = JournalProvider();
        await noRepoProvider.loadEntries();

        expect(noRepoProvider.entries, isEmpty);
        expect(noRepoProvider.loading, false);
      });
    });

    group('entriesForCategory', () {
      test('filters entries by category', () async {
        await provider.selectDate(DateTime(2026, 2, 27));
        await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.positive,
          'Positive thing',
        );
        await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.negative,
          'Negative thing',
        );
        await provider.loadEntries();

        final positive =
            provider.entriesForCategory(JournalCategory.positive);
        final negative =
            provider.entriesForCategory(JournalCategory.negative);
        final gratitude =
            provider.entriesForCategory(JournalCategory.gratitude);

        expect(positive.length, 1);
        expect(positive.first.text, 'Positive thing');
        expect(negative.length, 1);
        expect(negative.first.text, 'Negative thing');
        expect(gratitude, isEmpty);
      });
    });

    group('addEntry', () {
      test('adds entry and reloads', () async {
        await provider.selectDate(DateTime(2026, 2, 27));
        await provider.addEntry(JournalCategory.beauty, 'A sunset');

        expect(provider.entries.length, 1);
        expect(provider.entries.first.text, 'A sunset');
        expect(provider.entries.first.category, JournalCategory.beauty);
      });
    });

    group('updateEntry', () {
      test('updates entry text', () async {
        await provider.selectDate(DateTime(2026, 2, 27));
        await provider.addEntry(JournalCategory.identity, 'Original');

        final entryId = provider.entries.first.id;
        await provider.updateEntry(entryId, 'Updated');

        expect(provider.entries.first.text, 'Updated');
      });
    });

    group('deleteEntry', () {
      test('removes entry', () async {
        await provider.selectDate(DateTime(2026, 2, 27));
        await provider.addEntry(JournalCategory.gratitude, 'To delete');

        final entryId = provider.entries.first.id;
        await provider.deleteEntry(entryId);

        expect(provider.entries, isEmpty);
      });
    });

    group('clear', () {
      test('resets all state', () async {
        await provider.selectDate(DateTime(2026, 2, 27));
        await provider.addEntry(JournalCategory.positive, 'Something');

        provider.clear();

        expect(provider.entries, isEmpty);
        expect(provider.daysWithEntries, isEmpty);
        expect(provider.error, isNull);
      });

      test('loadEntries does nothing after clear', () async {
        provider.clear();
        await provider.loadEntries();

        expect(provider.entries, isEmpty);
      });
    });

    group('error handling', () {
      test('error is null on success', () async {
        await provider.selectDate(DateTime(2026, 2, 27));
        expect(provider.error, isNull);
      });
    });
  });
}
