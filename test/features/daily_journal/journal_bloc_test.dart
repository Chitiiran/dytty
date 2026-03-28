import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

void main() {
  late FakeFirebaseFirestore firestore;
  late JournalRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = JournalRepository(uid: 'test-user', firestore: firestore);
  });

  group('JournalBloc', () {
    blocTest<JournalBloc, JournalState>(
      'initial state has status initial and empty entries',
      build: () => JournalBloc(repository: repository),
      verify: (bloc) {
        expect(bloc.state.status, JournalStatus.initial);
        expect(bloc.state.entries, isEmpty);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'SelectDate updates selectedDate and loads entries, markers, and streak',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 1)));
        // Wait for stream + parallel fetches to complete
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.status, JournalStatus.loaded);
        expect(bloc.state.selectedDate, DateTime(2026, 3, 1));
        expect(bloc.state.entries, isEmpty);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'LoadEntries loads entries for selected date',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      setUp: () async {
        await repository.addCategoryEntry(
          '2026-03-01',
          'positive',
          'Good thing',
        );
      },
      act: (bloc) => bloc.add(const LoadEntries()),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.loading,
        ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loaded)
            .having((s) => s.entries.length, 'entries.length', 1)
            .having(
              (s) => s.entries.first.text,
              'entries.first.text',
              'Good thing',
            ),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'AddEntry adds entry and stream updates entries',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      act: (bloc) async {
        // First subscribe to entries via SelectDate
        bloc.add(SelectDate(DateTime(2026, 3, 1)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'beauty', text: 'A sunset'));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.status, JournalStatus.loaded);
        expect(bloc.state.entries.length, 1);
        expect(bloc.state.entries.first.text, 'A sunset');
      },
    );

    blocTest<JournalBloc, JournalState>(
      'AddVoiceEntry saves entry with voice source and transcript',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 1)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(
          const AddVoiceEntry(
            categoryId: 'gratitude',
            text: 'Grateful for sunshine',
            transcript: 'I am really grateful for the sunshine today',
            tags: ['sunshine', 'gratitude'],
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.status, JournalStatus.loaded);
        expect(bloc.state.entries.length, 1);
        expect(bloc.state.entries.first.source, 'voice');
        expect(
          bloc.state.entries.first.transcript,
          'I am really grateful for the sunshine today',
        );
        expect(bloc.state.entries.first.tags, ['sunshine', 'gratitude']);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'UpdateEntry updates entry text',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        await repository.addCategoryEntry('2026-03-01', 'identity', 'Original');
      },
      act: (bloc) async {
        // Subscribe to stream first
        bloc.add(SelectDate(DateTime(2026, 3, 1)));
        await Future.delayed(const Duration(milliseconds: 200));
        final entryId = bloc.state.entries.first.id;
        bloc.add(UpdateEntry(entryId: entryId, text: 'Updated'));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.status, JournalStatus.loaded);
        expect(bloc.state.entries.first.text, 'Updated');
      },
    );

    blocTest<JournalBloc, JournalState>(
      'DeleteEntry removes entry',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        await repository.addCategoryEntry(
          '2026-03-01',
          'gratitude',
          'To delete',
        );
      },
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 1)));
        await Future.delayed(const Duration(milliseconds: 200));
        final entryId = bloc.state.entries.first.id;
        bloc.add(DeleteEntry(entryId));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.status, JournalStatus.loaded);
        expect(bloc.state.entries, isEmpty);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'LoadMonthMarkers updates monthCategoryMarkers',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        await repository.addCategoryEntry('2026-03-01', 'positive', 'entry');
        await repository.addCategoryEntry('2026-03-15', 'positive', 'entry');
      },
      act: (bloc) => bloc.add(const LoadMonthMarkers(year: 2026, month: 3)),
      expect: () => [
        isA<JournalState>()
            .having((s) => s.monthCategoryMarkers, 'monthCategoryMarkers', {
              '2026-03-01': {'positive': 1},
              '2026-03-15': {'positive': 1},
            })
            .having((s) => s.daysWithEntries, 'daysWithEntries', {
              '2026-03-01',
              '2026-03-15',
            }),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'LoadStreak loads streak data',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        final today = DateTime.now();
        for (int i = 0; i < 3; i++) {
          final day = today.subtract(Duration(days: i));
          final dateStr =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          await repository.addCategoryEntry(dateStr, 'positive', 'Entry $i');
        }
      },
      act: (bloc) => bloc.add(const LoadStreak()),
      expect: () => [
        isA<JournalState>().having((s) => s.currentStreak, 'currentStreak', 3),
      ],
    );

    test('journaledToday returns true when today has entries', () {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final state = JournalState(
        monthCategoryMarkers: {
          todayStr: {'positive': 1},
        },
      );
      expect(state.journaledToday, true);
    });

    test('journaledToday returns false when today has no entries', () {
      final state = JournalState(
        monthCategoryMarkers: {
          '2025-01-01': {'positive': 1},
        },
      );
      expect(state.journaledToday, false);
    });

    test('entriesForCategory filters correctly', () {
      final now = DateTime.now();
      final state = JournalState(
        entries: [
          CategoryEntry(
            id: '1',
            categoryId: 'positive',
            text: 'pos',
            createdAt: now,
          ),
          CategoryEntry(
            id: '2',
            categoryId: 'negative',
            text: 'neg',
            createdAt: now,
          ),
        ],
      );

      expect(state.entriesForCategory('positive').length, 1);
      expect(state.entriesForCategory('gratitude'), isEmpty);
    });

    blocTest<JournalBloc, JournalState>(
      'AddEntry updates daysWithEntries (calendar markers)',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 10)),
      act: (bloc) =>
          bloc.add(const AddEntry(categoryId: 'positive', text: 'marker test')),
      verify: (bloc) {
        expect(bloc.state.daysWithEntries, contains('2026-03-10'));
      },
    );

    blocTest<JournalBloc, JournalState>(
      'AddEntry updates currentStreak',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime.now()),
      act: (bloc) => bloc.add(
        const AddEntry(categoryId: 'gratitude', text: 'streak test'),
      ),
      verify: (bloc) {
        expect(bloc.state.currentStreak, greaterThanOrEqualTo(1));
      },
    );

    blocTest<JournalBloc, JournalState>(
      'AddVoiceEntry with explicit date saves to correct date',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 1, 1)),
      act: (bloc) async {
        // Subscribe to the target date first
        bloc.add(SelectDate(DateTime(2026, 3, 20)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(
          AddVoiceEntry(
            categoryId: 'beauty',
            text: 'Voice on specific date',
            transcript: 'voice transcript',
            date: DateTime(2026, 3, 20),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.selectedDate, DateTime(2026, 3, 20));
        expect(bloc.state.entries.length, 1);
        expect(bloc.state.entries.first.text, 'Voice on specific date');
        expect(bloc.state.daysWithEntries, contains('2026-03-20'));
      },
    );

    blocTest<JournalBloc, JournalState>(
      'SelectDate then AddEntry processes sequentially',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 5)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(
          const AddEntry(categoryId: 'negative', text: 'Sequential test'),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.selectedDate, DateTime(2026, 3, 5));
        expect(bloc.state.entries.length, 1);
        expect(bloc.state.entries.first.text, 'Sequential test');
      },
    );

    blocTest<JournalBloc, JournalState>(
      'journaledToday is true after AddEntry on today',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime.now()),
      act: (bloc) =>
          bloc.add(const AddEntry(categoryId: 'identity', text: 'Today entry')),
      verify: (bloc) {
        expect(bloc.state.journaledToday, true);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'SelectDate subscribes to entry stream and emits on updates',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        await repository.addCategoryEntry(
          '2026-03-01',
          'positive',
          'Initial entry',
        );
      },
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 1)));
        await Future.delayed(const Duration(milliseconds: 200));
        // Add another entry — stream should auto-update
        await repository.addCategoryEntry(
          '2026-03-01',
          'gratitude',
          'Stream update',
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.status, JournalStatus.loaded);
        expect(bloc.state.entries.length, 2);
        expect(
          bloc.state.entries.map((e) => e.text).toList(),
          containsAll(['Initial entry', 'Stream update']),
        );
      },
    );

    blocTest<JournalBloc, JournalState>(
      'switching dates cancels previous stream subscription',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        await repository.addCategoryEntry('2026-03-01', 'positive', 'March 1');
        await repository.addCategoryEntry('2026-03-02', 'positive', 'March 2');
      },
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 1)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(SelectDate(DateTime(2026, 3, 2)));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.selectedDate, DateTime(2026, 3, 2));
        expect(bloc.state.entries.length, 1);
        expect(bloc.state.entries.first.text, 'March 2');
      },
    );
  });

  group('JournalBloc state-chain: markers, streak, cross-date', () {
    blocTest<JournalBloc, JournalState>(
      'AddEntry updates monthCategoryMarkers with correct categoryId',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'test'));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        final markers = bloc.state.monthCategoryMarkers;
        expect(markers['2026-03-10'], isNotNull);
        expect(markers['2026-03-10']!['positive'], 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'AddVoiceEntry updates monthCategoryMarkers with correct categoryId',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(
          const AddVoiceEntry(
            categoryId: 'gratitude',
            text: 'voice test',
            transcript: 'raw transcript',
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        final markers = bloc.state.monthCategoryMarkers;
        expect(markers['2026-03-10'], isNotNull);
        expect(markers['2026-03-10']!['gratitude'], 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'multiple entries same category increments marker count',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'first'));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'second'));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.monthCategoryMarkers['2026-03-10']!['positive'], 2);
        expect(bloc.state.entries.length, 2);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'AddEntry with explicit date updates markers for target date',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 20)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(
          AddEntry(
            categoryId: 'beauty',
            text: 'explicit date',
            date: DateTime(2026, 3, 20),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.monthCategoryMarkers['2026-03-20'], isNotNull);
        expect(bloc.state.monthCategoryMarkers['2026-03-20']!['beauty'], 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'DeleteEntry decrements marker count',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'first'));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'second'));
        await Future.delayed(const Duration(milliseconds: 200));
        final entryId = bloc.state.entries.first.id;
        bloc.add(DeleteEntry(entryId));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.monthCategoryMarkers['2026-03-10']!['positive'], 1);
        expect(bloc.state.entries.length, 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'delete last entry removes date key from markers',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'only'));
        await Future.delayed(const Duration(milliseconds: 200));
        final entryId = bloc.state.entries.first.id;
        bloc.add(DeleteEntry(entryId));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.daysWithEntries, isNot(contains('2026-03-10')));
        expect(bloc.state.entries, isEmpty);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'cross-date add in same month — both date keys present',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 5)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'day 5'));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(
          AddEntry(
            categoryId: 'negative',
            text: 'day 15',
            date: DateTime(2026, 3, 15),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        final markers = bloc.state.monthCategoryMarkers;
        expect(markers['2026-03-05']?['positive'], 1);
        expect(markers['2026-03-15']?['negative'], 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'streak not bumped for past dates beyond yesterday',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        // Seed a streak by adding entries for recent consecutive days
        final today = DateTime.now();
        for (int i = 0; i < 3; i++) {
          final day = today.subtract(Duration(days: i));
          final dateStr =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          await repository.addCategoryEntry(dateStr, 'positive', 'Entry $i');
        }
      },
      act: (bloc) async {
        // Select a far-past date and add entry there
        bloc.add(SelectDate(DateTime(2026, 1, 1)));
        await Future.delayed(const Duration(milliseconds: 200));
        final streakBefore = bloc.state.currentStreak;
        bloc.add(
          AddEntry(
            categoryId: 'positive',
            text: 'old entry',
            date: DateTime(2026, 1, 1),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
        // Streak should not increase from adding to a far-past date
        expect(bloc.state.currentStreak, streakBefore);
      },
    );
  });

  group('JournalBloc integration: multi-action user sessions', () {
    blocTest<JournalBloc, JournalState>(
      'text + voice + delete on same date — entries and markers stay consistent',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));

        // Add text entry
        bloc.add(const AddEntry(categoryId: 'positive', text: 'text entry'));
        await Future.delayed(const Duration(milliseconds: 200));

        // Add voice entry to different category
        bloc.add(
          const AddVoiceEntry(
            categoryId: 'gratitude',
            text: 'voice summary',
            transcript: 'full voice transcript',
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));

        // Delete the text entry
        final textEntry = bloc.state.entries.firstWhere(
          (e) => e.categoryId == 'positive',
        );
        bloc.add(DeleteEntry(textEntry.id));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        // Only voice entry remains
        expect(bloc.state.entries.length, 1);
        expect(bloc.state.entries.first.categoryId, 'gratitude');
        expect(bloc.state.entries.first.source, 'voice');

        // Markers: positive removed (was 1, decremented to 0), gratitude stays
        final markers = bloc.state.monthCategoryMarkers['2026-03-10']!;
        expect(markers.containsKey('positive'), false);
        expect(markers['gratitude'], 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'navigate dates back and forth — entries and markers stay correct',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        await repository.addCategoryEntry('2026-03-05', 'positive', 'day5');
        await repository.addCategoryEntry('2026-03-05', 'negative', 'day5neg');
        await repository.addCategoryEntry('2026-03-12', 'beauty', 'day12');
      },
      act: (bloc) async {
        // Go to March 5
        bloc.add(SelectDate(DateTime(2026, 3, 5)));
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify March 5 entries loaded
        expect(bloc.state.entries.length, 2);

        // Navigate to March 12
        bloc.add(SelectDate(DateTime(2026, 3, 12)));
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify March 12 entries loaded, March 5 gone from entries
        expect(bloc.state.entries.length, 1);
        expect(bloc.state.entries.first.text, 'day12');

        // Navigate back to March 5
        bloc.add(SelectDate(DateTime(2026, 3, 5)));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        // March 5 entries should be back
        expect(bloc.state.entries.length, 2);
        expect(bloc.state.entries.map((e) => e.categoryId).toSet(), {
          'positive',
          'negative',
        });

        // Both dates should have markers
        expect(bloc.state.monthCategoryMarkers['2026-03-05'], isNotNull);
        expect(bloc.state.monthCategoryMarkers['2026-03-12'], isNotNull);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'add entries across multiple categories — per-category counts correct',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));

        // Fill all 5 categories
        for (final cat in [
          'positive',
          'negative',
          'gratitude',
          'beauty',
          'identity',
        ]) {
          bloc.add(AddEntry(categoryId: cat, text: '$cat entry'));
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // Add a second entry to positive
        bloc.add(
          const AddEntry(categoryId: 'positive', text: 'another positive'),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.entries.length, 6);

        final markers = bloc.state.monthCategoryMarkers['2026-03-10']!;
        expect(markers['positive'], 2);
        expect(markers['negative'], 1);
        expect(markers['gratitude'], 1);
        expect(markers['beauty'], 1);
        expect(markers['identity'], 1);

        // entriesForCategory should filter correctly
        expect(bloc.state.entriesForCategory('positive').length, 2);
        expect(bloc.state.entriesForCategory('beauty').length, 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'add entry on date A, navigate to B, add entry, navigate back — both dates intact',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        // Date A: March 5
        bloc.add(SelectDate(DateTime(2026, 3, 5)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'on day 5'));
        await Future.delayed(const Duration(milliseconds: 200));

        // Date B: March 20
        bloc.add(SelectDate(DateTime(2026, 3, 20)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'negative', text: 'on day 20'));
        await Future.delayed(const Duration(milliseconds: 200));

        // Navigate back to A
        bloc.add(SelectDate(DateTime(2026, 3, 5)));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        // Should see date A's entries
        expect(bloc.state.entries.length, 1);
        expect(bloc.state.entries.first.text, 'on day 5');

        // Both dates should have markers
        final markers = bloc.state.monthCategoryMarkers;
        expect(markers['2026-03-05']?['positive'], 1);
        expect(markers['2026-03-20']?['negative'], 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'delete then undo (re-add) — entry and markers restored on correct date',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));

        // Add two entries
        bloc.add(const AddEntry(categoryId: 'positive', text: 'keep'));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'gratitude', text: 'will delete'));
        await Future.delayed(const Duration(milliseconds: 200));

        // Delete the gratitude entry
        final gratitudeEntry = bloc.state.entries.firstWhere(
          (e) => e.categoryId == 'gratitude',
        );
        bloc.add(DeleteEntry(gratitudeEntry.id));
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify delete happened
        expect(bloc.state.entries.length, 1);
        expect(
          bloc.state.monthCategoryMarkers['2026-03-10']!.containsKey(
            'gratitude',
          ),
          false,
        );

        // Undo: re-add with explicit date (simulates undo snackbar)
        bloc.add(
          AddEntry(
            categoryId: 'gratitude',
            text: 'will delete',
            date: DateTime(2026, 3, 10),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        // Both entries restored
        expect(bloc.state.entries.length, 2);
        expect(bloc.state.entries.map((e) => e.categoryId).toSet(), {
          'positive',
          'gratitude',
        });

        // Markers restored
        final markers = bloc.state.monthCategoryMarkers['2026-03-10']!;
        expect(markers['positive'], 1);
        expect(markers['gratitude'], 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'markers survive SelectDate round-trip via cache',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        // Add entries on March 10
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));
        bloc.add(const AddEntry(categoryId: 'positive', text: 'cached'));
        await Future.delayed(const Duration(milliseconds: 200));

        // Navigate to different month (April)
        bloc.add(SelectDate(DateTime(2026, 4, 1)));
        await Future.delayed(const Duration(milliseconds: 200));

        // Navigate back to March — should hit marker cache
        bloc.add(const LoadMonthMarkers(year: 2026, month: 3));
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        // March markers should be intact from cache
        expect(bloc.state.monthCategoryMarkers['2026-03-10']?['positive'], 1);
      },
    );

    blocTest<JournalBloc, JournalState>(
      'mixed voice and text entries — voice metadata preserved alongside text',
      build: () => JournalBloc(repository: repository),
      act: (bloc) async {
        bloc.add(SelectDate(DateTime(2026, 3, 10)));
        await Future.delayed(const Duration(milliseconds: 200));

        // Text entry
        bloc.add(const AddEntry(categoryId: 'positive', text: 'typed'));
        await Future.delayed(const Duration(milliseconds: 200));

        // Voice entry to same category
        bloc.add(
          const AddVoiceEntry(
            categoryId: 'positive',
            text: 'spoken summary',
            transcript: 'full spoken words',
            tags: ['voice-call'],
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      },
      verify: (bloc) {
        expect(bloc.state.entries.length, 2);
        expect(bloc.state.monthCategoryMarkers['2026-03-10']!['positive'], 2);

        final textEntry = bloc.state.entries.firstWhere(
          (e) => e.source == 'manual',
        );
        final voiceEntry = bloc.state.entries.firstWhere(
          (e) => e.source == 'voice',
        );

        expect(textEntry.text, 'typed');
        expect(textEntry.transcript, isNull);

        expect(voiceEntry.text, 'spoken summary');
        expect(voiceEntry.transcript, 'full spoken words');
        expect(voiceEntry.tags, ['voice-call']);
      },
    );
  });

  group('JournalBloc error paths', () {
    late MockJournalRepository mockRepository;

    setUp(() {
      mockRepository = MockJournalRepository();
    });

    blocTest<JournalBloc, JournalState>(
      'SelectDate emits error when repository throws',
      setUp: () {
        when(
          () => mockRepository.watchCategoryEntries(any()),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => mockRepository.getMonthCategoryMarkers(any(), any()),
        ).thenThrow(Exception('markers failed'));
        when(
          () => mockRepository.getStreakData(),
        ).thenThrow(Exception('streak failed'));
      },
      build: () => JournalBloc(repository: mockRepository),
      act: (bloc) => bloc.add(SelectDate(DateTime(2026, 3, 1))),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.loading,
        ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.error)
            .having((s) => s.error, 'error', contains('markers failed')),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'LoadEntries emits error when repository throws',
      setUp: () {
        when(
          () => mockRepository.getCategoryEntries(any()),
        ).thenThrow(Exception('load failed'));
      },
      build: () => JournalBloc(repository: mockRepository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      act: (bloc) => bloc.add(const LoadEntries()),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.loading,
        ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.error)
            .having((s) => s.error, 'error', contains('load failed')),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'AddEntry emits error when repository throws',
      setUp: () {
        when(
          () => mockRepository.addCategoryEntry(
            any(),
            any(),
            any(),
            source: any(named: 'source'),
            transcript: any(named: 'transcript'),
            tags: any(named: 'tags'),
          ),
        ).thenThrow(Exception('add failed'));
      },
      build: () => JournalBloc(repository: mockRepository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      act: (bloc) =>
          bloc.add(const AddEntry(categoryId: 'positive', text: 'test')),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.saving,
        ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.error)
            .having((s) => s.error, 'error', contains('add failed')),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'UpdateEntry emits error when repository throws',
      setUp: () {
        when(
          () => mockRepository.updateCategoryEntry(any(), any(), any()),
        ).thenThrow(Exception('update failed'));
      },
      build: () => JournalBloc(repository: mockRepository),
      seed: () => JournalState(
        selectedDate: DateTime(2026, 3, 1),
        entries: [
          CategoryEntry(
            id: 'e1',
            categoryId: 'positive',
            text: 'original',
            createdAt: DateTime(2026, 3, 1),
          ),
        ],
      ),
      act: (bloc) =>
          bloc.add(const UpdateEntry(entryId: 'e1', text: 'updated')),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.saving,
        ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.error)
            .having((s) => s.error, 'error', contains('update failed')),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'DeleteEntry emits error when repository throws',
      setUp: () {
        when(
          () => mockRepository.deleteCategoryEntry(any(), any()),
        ).thenThrow(Exception('delete failed'));
      },
      build: () => JournalBloc(repository: mockRepository),
      seed: () => JournalState(
        selectedDate: DateTime(2026, 3, 1),
        entries: [
          CategoryEntry(
            id: 'e1',
            categoryId: 'positive',
            text: 'to delete',
            createdAt: DateTime(2026, 3, 1),
          ),
        ],
      ),
      act: (bloc) => bloc.add(const DeleteEntry('e1')),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.saving,
        ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.error)
            .having((s) => s.error, 'error', contains('delete failed')),
      ],
    );
  });
}
