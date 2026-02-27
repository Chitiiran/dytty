import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/categories.dart';
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
          JournalCategory.gratitude,
          'Grateful for tests',
        );

        expect(entry.category, JournalCategory.gratitude);
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

      test('reuses existing daily entry', () async {
        await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.positive,
          'First entry',
        );
        await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.negative,
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
          JournalCategory.positive,
          'Good thing',
        );
        await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.beauty,
          'Beautiful thing',
        );

        final entries = await repository.getCategoryEntries('2026-02-27');
        expect(entries.length, 2);
        expect(entries.map((e) => e.text).toList(),
            containsAll(['Good thing', 'Beautiful thing']));
      });
    });

    group('updateCategoryEntry', () {
      test('updates entry text', () async {
        final entry = await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.identity,
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
          JournalCategory.positive,
          'To be deleted',
        );

        await repository.deleteCategoryEntry('2026-02-27', entry.id);

        final entries = await repository.getCategoryEntries('2026-02-27');
        expect(entries, isEmpty);
      });

      test('deletes daily entry when last category entry removed', () async {
        final entry = await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.positive,
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
          JournalCategory.positive,
          'Keep this',
        );
        await repository.addCategoryEntry(
          '2026-02-27',
          JournalCategory.negative,
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
        await repository.addCategoryEntry(
          '2026-02-15',
          JournalCategory.positive,
          'Entry 1',
        );
        await repository.addCategoryEntry(
          '2026-02-20',
          JournalCategory.gratitude,
          'Entry 2',
        );

        final days = await repository.getDaysWithEntries(2026, 2);
        expect(days, containsAll(['2026-02-15', '2026-02-20']));
        expect(days.length, 2);
      });

      test('returns empty set for month with no entries', () async {
        final days = await repository.getDaysWithEntries(2026, 3);
        expect(days, isEmpty);
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
