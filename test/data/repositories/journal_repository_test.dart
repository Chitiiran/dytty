import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/review_summary.dart';
import 'package:dytty/data/repositories/journal_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late JournalRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = JournalRepository(uid: 'test-user', firestore: firestore);
  });

  group('JournalRepository', () {
    group('addCategoryEntry', () {
      test('creates daily entry and category entry', () async {
        final entry = await repository.addCategoryEntry(
          '2026-02-27',
          'gratitude',
          'Grateful for tests',
        );

        expect(entry.categoryId, 'gratitude');
        expect(entry.text, 'Grateful for tests');
        expect(entry.id, isNotEmpty);

        // Verify daily entry was created
        final dailyDoc = await firestore
            .collection('users')
            .doc('test-user')
            .collection('dailyEntries')
            .doc('2026-02-27')
            .get();
        expect(dailyDoc.exists, true);
      });

      test('with voice fields saves transcript, source, tags', () async {
        final entry = await repository.addCategoryEntry(
          '2026-02-27',
          'gratitude',
          'AI summary of speech',
          source: 'voice',
          transcript: 'I am really grateful for my health today',
          tags: ['health', 'gratitude'],
        );

        expect(entry.source, 'voice');
        expect(entry.transcript, 'I am really grateful for my health today');
        expect(entry.tags, ['health', 'gratitude']);

        // Verify persisted in Firestore
        final entries = await repository.getCategoryEntries('2026-02-27');
        expect(entries.first.source, 'voice');
        expect(
          entries.first.transcript,
          'I am really grateful for my health today',
        );
        expect(entries.first.tags, ['health', 'gratitude']);
      });

      test('defaults to manual source with no optional params', () async {
        final entry = await repository.addCategoryEntry(
          '2026-02-27',
          'positive',
          'A good thing',
        );

        expect(entry.source, 'manual');
        expect(entry.transcript, isNull);
        expect(entry.tags, isEmpty);
      });

      test('reuses existing daily entry', () async {
        await repository.addCategoryEntry(
          '2026-02-27',
          'positive',
          'First entry',
        );
        await repository.addCategoryEntry(
          '2026-02-27',
          'negative',
          'Second entry',
        );

        final entries = await repository.getCategoryEntries('2026-02-27');
        expect(entries.length, 2);
      });
    });

    group('getCategoryEntries', () {
      test('returns empty list for date with no entries', () async {
        final entries = await repository.getCategoryEntries('2026-01-01');
        expect(entries, isEmpty);
      });

      test('returns all entries for a date', () async {
        await repository.addCategoryEntry(
          '2026-02-27',
          'positive',
          'Good thing',
        );
        await repository.addCategoryEntry(
          '2026-02-27',
          'beauty',
          'Beautiful thing',
        );

        final entries = await repository.getCategoryEntries('2026-02-27');
        expect(entries.length, 2);
        expect(
          entries.map((e) => e.text).toList(),
          containsAll(['Good thing', 'Beautiful thing']),
        );
      });
    });

    group('updateCategoryEntry', () {
      test('updates entry text', () async {
        final entry = await repository.addCategoryEntry(
          '2026-02-27',
          'identity',
          'Original text',
        );

        await repository.updateCategoryEntry(
          '2026-02-27',
          entry.id,
          'Updated text',
        );

        final entries = await repository.getCategoryEntries('2026-02-27');
        expect(entries.first.text, 'Updated text');
      });
    });

    group('deleteCategoryEntry', () {
      test('removes entry', () async {
        final entry = await repository.addCategoryEntry(
          '2026-02-27',
          'positive',
          'To be deleted',
        );

        await repository.deleteCategoryEntry('2026-02-27', entry.id);

        final entries = await repository.getCategoryEntries('2026-02-27');
        expect(entries, isEmpty);
      });

      test('deletes daily entry when last category entry removed', () async {
        final entry = await repository.addCategoryEntry(
          '2026-02-27',
          'positive',
          'Only entry',
        );

        await repository.deleteCategoryEntry('2026-02-27', entry.id);

        final dailyDoc = await firestore
            .collection('users')
            .doc('test-user')
            .collection('dailyEntries')
            .doc('2026-02-27')
            .get();
        expect(dailyDoc.exists, false);
      });

      test('keeps daily entry when other category entries remain', () async {
        final entry1 = await repository.addCategoryEntry(
          '2026-02-27',
          'positive',
          'Keep this',
        );
        await repository.addCategoryEntry(
          '2026-02-27',
          'negative',
          'Delete this',
        );

        // Delete the first, second should remain
        await repository.deleteCategoryEntry('2026-02-27', entry1.id);

        final dailyDoc = await firestore
            .collection('users')
            .doc('test-user')
            .collection('dailyEntries')
            .doc('2026-02-27')
            .get();
        expect(dailyDoc.exists, true);
      });
    });

    group('getDaysWithEntries', () {
      test('returns dates that have entries', () async {
        await repository.addCategoryEntry('2026-02-15', 'positive', 'Entry 1');
        await repository.addCategoryEntry('2026-02-20', 'gratitude', 'Entry 2');

        final days = await repository.getDaysWithEntries(2026, 2);
        expect(days, containsAll(['2026-02-15', '2026-02-20']));
        expect(days.length, 2);
      });

      test('returns empty set for month with no entries', () async {
        final days = await repository.getDaysWithEntries(2026, 3);
        expect(days, isEmpty);
      });
    });

    group('getMonthCategoryMarkers', () {
      test('returns empty map for month with no entries', () async {
        final result = await repository.getMonthCategoryMarkers(2026, 6);
        expect(result, isEmpty);
      });

      test('returns correct category counts per date', () async {
        await repository.addCategoryEntry('2026-03-01', 'positive', 'A');
        await repository.addCategoryEntry('2026-03-01', 'positive', 'B');
        await repository.addCategoryEntry('2026-03-01', 'gratitude', 'C');
        await repository.addCategoryEntry('2026-03-15', 'negative', 'D');

        final result = await repository.getMonthCategoryMarkers(2026, 3);

        expect(result, {
          '2026-03-01': {'positive': 2, 'gratitude': 1},
          '2026-03-15': {'negative': 1},
        });
      });

      test('does not include entries from other months', () async {
        await repository.addCategoryEntry('2026-03-01', 'positive', 'March');
        await repository.addCategoryEntry('2026-04-01', 'positive', 'April');

        final result = await repository.getMonthCategoryMarkers(2026, 3);

        expect(result.keys, contains('2026-03-01'));
        expect(result.containsKey('2026-04-01'), isFalse);
      });
    });

    group('getStreakData', () {
      test('returns 0 streak when no entries exist', () async {
        final streak = await repository.getStreakData();
        expect(streak.currentStreak, 0);
        expect(streak.longestStreak, 0);
        expect(streak.lastJournalDate, isNull);
      });

      test('returns 1 day streak for entry today', () async {
        final today = DateTime.now();
        final dateStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await repository.addCategoryEntry(dateStr, 'positive', 'Today entry');

        final streak = await repository.getStreakData();
        expect(streak.currentStreak, 1);
        expect(streak.lastJournalDate, dateStr);
      });

      test('counts consecutive days as streak', () async {
        final today = DateTime.now();
        for (int i = 0; i < 5; i++) {
          final day = today.subtract(Duration(days: i));
          final dateStr =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          await repository.addCategoryEntry(dateStr, 'positive', 'Entry $i');
        }

        final streak = await repository.getStreakData();
        expect(streak.currentStreak, 5);
        expect(streak.longestStreak, 5);
      });

      test('gap breaks current streak', () async {
        final today = DateTime.now();
        // Today
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await repository.addCategoryEntry(todayStr, 'positive', 'Today');
        // 3 days ago (gap of 1 day)
        final threeDaysAgo = today.subtract(const Duration(days: 3));
        final threeStr =
            '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';
        await repository.addCategoryEntry(
          threeStr,
          'positive',
          'Three days ago',
        );

        final streak = await repository.getStreakData();
        expect(streak.currentStreak, 1);
      });

      test('streak starts from yesterday if no entry today', () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final dayBefore = DateTime.now().subtract(const Duration(days: 2));

        for (final day in [yesterday, dayBefore]) {
          final dateStr =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          await repository.addCategoryEntry(dateStr, 'positive', 'Entry');
        }

        final streak = await repository.getStreakData();
        expect(streak.currentStreak, 2);
      });
    });

    group('getUserSettings / updateUserSettings', () {
      test('returns default settings when no profile exists', () async {
        final settings = await repository.getUserSettings();
        expect(settings['hideEntries'], false);
      });

      test('persists and retrieves hideEntries', () async {
        await repository.ensureUserProfile('Test', 'test@test.com');
        await repository.updateUserSettings({'hideEntries': true});

        final settings = await repository.getUserSettings();
        expect(settings['hideEntries'], true);
      });
    });

    group('getCategoryEntriesForDateRange', () {
      test('returns entries grouped by date for a category', () async {
        await repository.addCategoryEntry('2026-03-17', 'positive', 'Good day');
        await repository.addCategoryEntry('2026-03-17', 'negative', 'Bad day');
        await repository.addCategoryEntry(
          '2026-03-18',
          'positive',
          'Another good day',
        );

        final result = await repository.getCategoryEntriesForDateRange(
          'positive',
          ['2026-03-17', '2026-03-18'],
        );

        expect(result.keys, containsAll(['2026-03-17', '2026-03-18']));
        expect(result['2026-03-17']!.length, 1);
        expect(result['2026-03-17']!.first.text, 'Good day');
        expect(result['2026-03-18']!.length, 1);
        expect(result['2026-03-18']!.first.text, 'Another good day');
      });

      test('returns empty map for dates with no matching entries', () async {
        await repository.addCategoryEntry('2026-03-17', 'negative', 'Bad day');

        final result = await repository.getCategoryEntriesForDateRange(
          'positive',
          ['2026-03-17'],
        );

        expect(result['2026-03-17'], isEmpty);
      });

      test('returns empty lists for dates with no entries at all', () async {
        final result = await repository.getCategoryEntriesForDateRange(
          'positive',
          ['2026-03-01'],
        );

        expect(result['2026-03-01'], isEmpty);
      });

      test('handles multiple entries same date same category', () async {
        await repository.addCategoryEntry('2026-03-18', 'gratitude', 'First');
        await repository.addCategoryEntry('2026-03-18', 'gratitude', 'Second');

        final result = await repository.getCategoryEntriesForDateRange(
          'gratitude',
          ['2026-03-18'],
        );

        expect(result['2026-03-18']!.length, 2);
      });
    });

    group('markEntryReviewed', () {
      test('sets isReviewed to true on an entry', () async {
        final entry = await repository.addCategoryEntry(
          '2026-03-18',
          'positive',
          'Test entry',
        );

        await repository.markEntryReviewed('2026-03-18', entry.id);

        final entries = await repository.getCategoryEntries('2026-03-18');
        expect(entries.first.isReviewed, true);
      });
    });

    group('saveReviewSummary', () {
      test('creates a new review summary', () async {
        final now = DateTime(2026, 3, 18);
        final summary = ReviewSummary(
          id: '',
          categoryId: 'positive',
          weekStart: '2026-03-16',
          summary: 'Great week!',
          createdAt: now,
          updatedAt: now,
        );

        await repository.saveReviewSummary(summary);

        final retrieved = await repository.getReviewSummary(
          'positive',
          '2026-03-16',
        );
        expect(retrieved, isNotNull);
        expect(retrieved!.summary, 'Great week!');
        expect(retrieved.categoryId, 'positive');
        expect(retrieved.weekStart, '2026-03-16');
      });

      test(
        'upserts existing review summary for same category and week',
        () async {
          final now = DateTime(2026, 3, 18);
          final first = ReviewSummary(
            id: '',
            categoryId: 'positive',
            weekStart: '2026-03-16',
            summary: 'First review',
            createdAt: now,
            updatedAt: now,
          );
          await repository.saveReviewSummary(first);

          final updated = ReviewSummary(
            id: '',
            categoryId: 'positive',
            weekStart: '2026-03-16',
            summary: 'Updated review',
            createdAt: now,
            updatedAt: DateTime(2026, 3, 19),
          );
          await repository.saveReviewSummary(updated);

          final retrieved = await repository.getReviewSummary(
            'positive',
            '2026-03-16',
          );
          expect(retrieved!.summary, 'Updated review');

          // Verify only one doc exists (upsert, not duplicate)
          final allDocs = await firestore
              .collection('users')
              .doc('test-user')
              .collection('reviewSummaries')
              .where('categoryId', isEqualTo: 'positive')
              .where('weekStart', isEqualTo: '2026-03-16')
              .get();
          expect(allDocs.docs.length, 1);
        },
      );
    });

    group('getReviewSummary', () {
      test('returns null when no summary exists', () async {
        final result = await repository.getReviewSummary(
          'positive',
          '2026-03-16',
        );
        expect(result, isNull);
      });

      test('returns summary for matching category and week', () async {
        final now = DateTime(2026, 3, 18);
        // Add summaries for different categories
        await repository.saveReviewSummary(
          ReviewSummary(
            id: '',
            categoryId: 'positive',
            weekStart: '2026-03-16',
            summary: 'Positive review',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.saveReviewSummary(
          ReviewSummary(
            id: '',
            categoryId: 'negative',
            weekStart: '2026-03-16',
            summary: 'Negative review',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final result = await repository.getReviewSummary(
          'positive',
          '2026-03-16',
        );
        expect(result!.summary, 'Positive review');
      });
    });

    group('ensureUserProfile', () {
      test('creates profile if it does not exist', () async {
        await repository.ensureUserProfile('Test User', 'test@example.com');

        final profileDoc = await firestore
            .collection('users')
            .doc('test-user')
            .get();
        expect(profileDoc.exists, true);
        expect(profileDoc.data()?['displayName'], 'Test User');
        expect(profileDoc.data()?['email'], 'test@example.com');
      });

      test('does not overwrite existing profile', () async {
        await repository.ensureUserProfile('Original', 'original@test.com');
        await repository.ensureUserProfile('Updated', 'updated@test.com');

        final profileDoc = await firestore
            .collection('users')
            .doc('test-user')
            .get();
        expect(profileDoc.data()?['displayName'], 'Original');
      });
    });
  });
}
