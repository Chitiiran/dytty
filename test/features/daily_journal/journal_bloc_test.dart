import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/categories.dart';
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
      'SelectDate updates selectedDate and loads entries',
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
          JournalCategory.positive,
          'Good thing',
        );
      },
      act: (bloc) => bloc.add(const LoadEntries()),
      expect: () => [
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loading),
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
      act: (bloc) => bloc.add(
        const AddEntry(category: JournalCategory.beauty, text: 'A sunset'),
      ),
      expect: () => [
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
          category: JournalCategory.gratitude,
          text: 'Grateful for sunshine',
          transcript: 'I am really grateful for the sunshine today',
          tags: ['sunshine', 'gratitude'],
        ),
      ),
      expect: () => [
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
            .having(
              (s) => s.entries.first.tags,
              'entries.first.tags',
              ['sunshine', 'gratitude'],
            ),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'UpdateEntry updates entry text',
      build: () => JournalBloc(repository: repository),
      seed: () => JournalState(selectedDate: DateTime(2026, 3, 1)),
      setUp: () async {
        await repository.addCategoryEntry(
          '2026-03-01',
          JournalCategory.identity,
          'Original',
        );
      },
      act: (bloc) async {
        // Load first to get the entry ID
        bloc.add(const LoadEntries());
        await Future.delayed(const Duration(milliseconds: 100));
        final entryId = bloc.state.entries.first.id;
        bloc.add(UpdateEntry(entryId: entryId, text: 'Updated'));
      },
      expect: () => [
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loading),
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loaded)
            .having((s) => s.entries.first.text, 'text', 'Original'),
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
          JournalCategory.gratitude,
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
        isA<JournalState>()
            .having((s) => s.status, 'status', JournalStatus.loading),
        isA<JournalState>()
            .having((s) => s.entries.length, 'entries.length', 1),
        isA<JournalState>()
            .having((s) => s.entries, 'entries', isEmpty),
      ],
    );

    blocTest<JournalBloc, JournalState>(
      'LoadMonthMarkers updates daysWithEntries',
      build: () => JournalBloc(repository: repository),
      setUp: () async {
        await repository.addCategoryEntry(
          '2026-03-01',
          JournalCategory.positive,
          'entry',
        );
        await repository.addCategoryEntry(
          '2026-03-15',
          JournalCategory.positive,
          'entry',
        );
      },
      act: (bloc) =>
          bloc.add(const LoadMonthMarkers(year: 2026, month: 3)),
      expect: () => [
        isA<JournalState>().having(
          (s) => s.daysWithEntries,
          'daysWithEntries',
          {'2026-03-01', '2026-03-15'},
        ),
      ],
    );

    test('entriesForCategory filters correctly', () {
      final now = DateTime.now();
      final state = JournalState(
        entries: [
          CategoryEntry(
            id: '1',
            category: JournalCategory.positive,
            text: 'pos',
            createdAt: now,
          ),
          CategoryEntry(
            id: '2',
            category: JournalCategory.negative,
            text: 'neg',
            createdAt: now,
          ),
        ],
      );

      expect(
        state.entriesForCategory(JournalCategory.positive).length,
        1,
      );
      expect(
        state.entriesForCategory(JournalCategory.gratitude),
        isEmpty,
      );
    });
  });
}
