import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';

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
      act: (bloc) => bloc.add(SelectDate(DateTime(2026, 3, 1))),
      expect: () => [
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loading)
            .having(
              (s) => s.selectedDate,
              'selectedDate',
              DateTime(2026, 3, 1),
            ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loaded)
            .having((s) => s.entries, 'entries', isEmpty),
      ],
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
      'AddEntry adds entry and reloads',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      act: (bloc) =>
          bloc.add(const AddEntry(categoryId: 'beauty', text: 'A sunset')),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.saving,
        ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loaded)
            .having((s) => s.entries.length, 'entries.length', 1)
            .having(
              (s) => s.entries.first.text,
              'entries.first.text',
              'A sunset',
            ),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'AddVoiceEntry saves entry with voice source and transcript',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      act: (bloc) => bloc.add(
        const AddVoiceEntry(
          categoryId: 'gratitude',
          text: 'Grateful for sunshine',
          transcript: 'I am really grateful for the sunshine today',
          tags: ['sunshine', 'gratitude'],
        ),
      ),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.saving,
        ),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loaded)
            .having((s) => s.entries.length, 'entries.length', 1)
            .having(
              (s) => s.entries.first.source,
              'entries.first.source',
              'voice',
            )
            .having(
              (s) => s.entries.first.transcript,
              'entries.first.transcript',
              'I am really grateful for the sunshine today',
            )
            .having((s) => s.entries.first.tags, 'entries.first.tags', [
              'sunshine',
              'gratitude',
            ]),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'UpdateEntry updates entry text',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      setUp: () async {
        await repository.addCategoryEntry('2026-03-01', 'identity', 'Original');
      },
      act: (bloc) async {
        // Load first to get the entry ID
        bloc.add(const LoadEntries());
        await Future.delayed(const Duration(milliseconds: 100));
        final entryId = bloc.state.entries.first.id;
        bloc.add(UpdateEntry(entryId: entryId, text: 'Updated'));
      },
      expect: () => [
        // LoadEntries: loading
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.loading,
        ),
        // LoadEntries: loaded with Original
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loaded)
            .having((s) => s.entries.first.text, 'text', 'Original'),
        // UpdateEntry: saving
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.saving,
        ),
        // UpdateEntry: loaded with Updated
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loaded)
            .having((s) => s.entries.first.text, 'text', 'Updated'),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'DeleteEntry removes entry',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      setUp: () async {
        await repository.addCategoryEntry(
          '2026-03-01',
          'gratitude',
          'To delete',
        );
      },
      act: (bloc) async {
        bloc.add(const LoadEntries());
        await Future.delayed(const Duration(milliseconds: 100));
        final entryId = bloc.state.entries.first.id;
        bloc.add(DeleteEntry(entryId));
      },
      expect: () => [
        // LoadEntries: loading
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.loading,
        ),
        // LoadEntries: loaded with 1 entry
        isA<JournalState>().having(
          (s) => s.entries.length,
          'entries.length',
          1,
        ),
        // DeleteEntry: saving
        isA<JournalState>().having(
          (s) => s.status,
          'status',
          JournalStatus.saving,
        ),
        // DeleteEntry: loaded with 0 entries
        isA<JournalState>().having((s) => s.entries, 'entries', isEmpty),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'LoadMonthMarkers updates daysWithEntries',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        await repository.addCategoryEntry('2026-03-01', 'positive', 'entry');
        await repository.addCategoryEntry('2026-03-15', 'positive', 'entry');
      },
      act: (bloc) => bloc.add(const LoadMonthMarkers(year: 2026, month: 3)),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.daysWithEntries,
          'daysWithEntries',
          {'2026-03-01', '2026-03-15'},
        ),
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
      final state = JournalState(daysWithEntries: {todayStr});
      expect(state.journaledToday, true);
    });

    test('journaledToday returns false when today has no entries', () {
      final state = JournalState(daysWithEntries: {'2025-01-01'});
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
      act: (bloc) => bloc.add(
        AddVoiceEntry(
          categoryId: 'beauty',
          text: 'Voice on specific date',
          transcript: 'voice transcript',
          date: DateTime(2026, 3, 20),
        ),
      ),
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
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(
          const AddEntry(categoryId: 'negative', text: 'Sequential test'),
        );
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
  });
}
