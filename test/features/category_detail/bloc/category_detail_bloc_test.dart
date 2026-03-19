import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/review_summary.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/category_detail/bloc/category_detail_bloc.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late JournalRepository repository;
  // Fixed clock: 2026-03-18 (Wednesday)
  DateTime fixedClock() => DateTime(2026, 3, 18);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = JournalRepository(uid: 'test-user', firestore: firestore);
  });

  group('CategoryDetailBloc', () {
    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'initial state has status initial',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      verify: (bloc) {
        expect(bloc.state.status, CategoryDetailStatus.initial);
        expect(bloc.state.recentEntries, isEmpty);
        expect(bloc.state.categoryId, '');
      },
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'LoadCategoryDetail loads entries grouped by date',
      setUp: () async {
        // Add entries on two different dates
        await repository.addCategoryEntry(
          '2026-03-18', 'positive', 'Today entry');
        await repository.addCategoryEntry(
          '2026-03-17', 'positive', 'Yesterday entry');
        // Add a non-matching category entry (should not appear)
        await repository.addCategoryEntry(
          '2026-03-18', 'negative', 'Negative entry');
      },
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      act: (bloc) => bloc.add(const LoadCategoryDetail('positive')),
      expect: () => [
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loading)
            .having((s) => s.categoryId, 'categoryId', 'positive'),
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loaded)
            .having(
              (s) => s.recentEntries.length,
              'recentEntries.length',
              2,
            )
            .having(
              (s) => s.recentEntries[0].displayDate,
              'first group label',
              'Today',
            )
            .having(
              (s) => s.recentEntries[0].entries.first.text,
              'today entry text',
              'Today entry',
            )
            .having(
              (s) => s.recentEntries[1].displayDate,
              'second group label',
              'Yesterday',
            )
            .having((s) => s.hasRecentEntries, 'hasRecentEntries', true),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'LoadCategoryDetail with no entries shows empty state',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      act: (bloc) => bloc.add(const LoadCategoryDetail('positive')),
      expect: () => [
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loading),
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loaded)
            .having((s) => s.recentEntries, 'recentEntries', isEmpty)
            .having((s) => s.hasRecentEntries, 'hasRecentEntries', false),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'LoadCategoryDetail loads review summary',
      setUp: () async {
        await repository.addCategoryEntry(
          '2026-03-18', 'positive', 'Entry');
        final now = DateTime(2026, 3, 18);
        await repository.saveReviewSummary(ReviewSummary(
          id: '',
          categoryId: 'positive',
          weekStart: '2026-03-16', // Monday of that week
          summary: 'Weekly review',
          createdAt: now,
          updatedAt: now,
        ));
      },
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      act: (bloc) => bloc.add(const LoadCategoryDetail('positive')),
      expect: () => [
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loading),
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loaded)
            .having(
              (s) => s.reviewSummary?.summary,
              'review summary',
              'Weekly review',
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'ToggleDateGroup toggles collapsed state',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () => CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        recentEntries: [
          DateGroup(
            date: '2026-03-18',
            displayDate: 'Today',
            entries: [
              CategoryEntry(
                id: 'e1',
                categoryId: 'positive',
                text: 'Entry',
                createdAt: DateTime(2026, 3, 18),
              ),
            ],
            isCollapsed: false,
          ),
        ],
        hasRecentEntries: true,
      ),
      act: (bloc) => bloc.add(const ToggleDateGroup('2026-03-18')),
      expect: () => [
        isA<CategoryDetailState>()
            .having(
              (s) => s.recentEntries.first.isCollapsed,
              'isCollapsed',
              true,
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'StartInlineEdit sets editingEntryId',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () => const CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
      ),
      act: (bloc) => bloc.add(const StartInlineEdit('entry-1')),
      expect: () => [
        isA<CategoryDetailState>()
            .having((s) => s.editingEntryId, 'editingEntryId', 'entry-1'),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'CancelInlineEdit clears editingEntryId',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () => const CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        editingEntryId: 'entry-1',
      ),
      act: (bloc) => bloc.add(const CancelInlineEdit()),
      expect: () => [
        isA<CategoryDetailState>()
            .having((s) => s.editingEntryId, 'editingEntryId', isNull),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'SaveInlineEdit updates entry text optimistically',
      setUp: () async {
        // Create parent daily entry doc + category entry so persist succeeds
        final dayDoc = firestore
            .collection('users')
            .doc('test-user')
            .collection('dailyEntries')
            .doc('2026-03-18');
        await dayDoc.set({
          'createdAt': DateTime(2026, 3, 18),
          'updatedAt': DateTime(2026, 3, 18),
        });
        await dayDoc
            .collection('categoryEntries')
            .doc('e1')
            .set({
          'category': 'positive',
          'text': 'Original text',
          'source': 'manual',
          'createdAt': DateTime(2026, 3, 18),
        });
      },
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () {
        return CategoryDetailState(
          status: CategoryDetailStatus.loaded,
          categoryId: 'positive',
          editingEntryId: 'e1',
          recentEntries: [
            DateGroup(
              date: '2026-03-18',
              displayDate: 'Today',
              entries: [
                CategoryEntry(
                  id: 'e1',
                  categoryId: 'positive',
                  text: 'Original text',
                  createdAt: DateTime(2026, 3, 18),
                ),
              ],
            ),
          ],
          hasRecentEntries: true,
        );
      },
      act: (bloc) => bloc.add(const SaveInlineEdit(
        date: '2026-03-18',
        entryId: 'e1',
        newText: 'Updated text',
      )),
      expect: () => [
        isA<CategoryDetailState>()
            .having((s) => s.editingEntryId, 'editingEntryId', isNull)
            .having(
              (s) => s.recentEntries.first.entries.first.text,
              'entry text',
              'Updated text',
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'SaveInlineEdit reverts on Firestore failure',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () {
        // Entry not in Firestore — update will fail
        return CategoryDetailState(
          status: CategoryDetailStatus.loaded,
          categoryId: 'positive',
          editingEntryId: 'e-missing',
          recentEntries: [
            DateGroup(
              date: '2026-03-18',
              displayDate: 'Today',
              entries: [
                CategoryEntry(
                  id: 'e-missing',
                  categoryId: 'positive',
                  text: 'Original',
                  createdAt: DateTime(2026, 3, 18),
                ),
              ],
            ),
          ],
          hasRecentEntries: true,
        );
      },
      act: (bloc) => bloc.add(const SaveInlineEdit(
        date: '2026-03-18',
        entryId: 'e-missing',
        newText: 'Should revert',
      )),
      expect: () => [
        // 1. Optimistic update
        isA<CategoryDetailState>()
            .having(
              (s) => s.recentEntries.first.entries.first.text,
              'optimistic text',
              'Should revert',
            ),
        // 2. Revert after Firestore failure
        isA<CategoryDetailState>()
            .having(
              (s) => s.recentEntries.first.entries.first.text,
              'reverted text',
              'Original',
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'EntryAddedFromCall adds entry to existing date group',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () => CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        recentEntries: [
          DateGroup(
            date: '2026-03-18',
            displayDate: 'Today',
            entries: [
              CategoryEntry(
                id: 'e1',
                categoryId: 'positive',
                text: 'Existing',
                createdAt: DateTime(2026, 3, 18),
              ),
            ],
          ),
        ],
        hasRecentEntries: true,
      ),
      act: (bloc) => bloc.add(EntryAddedFromCall(
        date: '2026-03-18',
        entry: CategoryEntry(
          id: 'e2',
          categoryId: 'positive',
          text: 'From AI call',
          createdAt: DateTime(2026, 3, 18, 14, 0),
        ),
      )),
      expect: () => [
        isA<CategoryDetailState>()
            .having(
              (s) => s.recentEntries.first.entries.length,
              'entries count',
              2,
            )
            .having(
              (s) => s.recentEntries.first.entries.last.text,
              'new entry text',
              'From AI call',
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'EntryAddedFromCall creates new date group when date not found',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () => const CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        recentEntries: [],
        hasRecentEntries: false,
      ),
      act: (bloc) => bloc.add(EntryAddedFromCall(
        date: '2026-03-18',
        entry: CategoryEntry(
          id: 'e1',
          categoryId: 'positive',
          text: 'First entry from call',
          createdAt: DateTime(2026, 3, 18),
        ),
      )),
      expect: () => [
        isA<CategoryDetailState>()
            .having(
              (s) => s.recentEntries.length,
              'groups count',
              1,
            )
            .having(
              (s) => s.recentEntries.first.date,
              'date',
              '2026-03-18',
            )
            .having((s) => s.hasRecentEntries, 'hasRecentEntries', true),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'EntryEditedFromCall updates entry text across groups',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () => CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        recentEntries: [
          DateGroup(
            date: '2026-03-18',
            displayDate: 'Today',
            entries: [
              CategoryEntry(
                id: 'e1',
                categoryId: 'positive',
                text: 'Original',
                createdAt: DateTime(2026, 3, 18),
              ),
            ],
          ),
        ],
        hasRecentEntries: true,
      ),
      act: (bloc) => bloc.add(const EntryEditedFromCall(
        entryId: 'e1',
        newText: 'Edited by AI',
      )),
      expect: () => [
        isA<CategoryDetailState>()
            .having(
              (s) => s.recentEntries.first.entries.first.text,
              'entry text',
              'Edited by AI',
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'MarkEntriesReviewed sets isReviewed on entries',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () => CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        recentEntries: [
          DateGroup(
            date: '2026-03-18',
            displayDate: 'Today',
            entries: [
              CategoryEntry(
                id: 'e1',
                categoryId: 'positive',
                text: 'Entry 1',
                createdAt: DateTime(2026, 3, 18),
                isReviewed: false,
              ),
              CategoryEntry(
                id: 'e2',
                categoryId: 'positive',
                text: 'Entry 2',
                createdAt: DateTime(2026, 3, 18),
                isReviewed: false,
              ),
            ],
          ),
        ],
        hasRecentEntries: true,
      ),
      act: (bloc) => bloc.add(const MarkEntriesReviewed(
        entries: [
          EntryReference(date: '2026-03-18', entryId: 'e1'),
          EntryReference(date: '2026-03-18', entryId: 'e2'),
        ],
      )),
      expect: () => [
        isA<CategoryDetailState>()
            .having(
              (s) => s.recentEntries.first.entries
                  .every((e) => e.isReviewed),
              'all reviewed',
              true,
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'SaveReviewSummaryEvent updates state with summary',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      seed: () => const CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
      ),
      act: (bloc) => bloc.add(SaveReviewSummaryEvent(ReviewSummary(
        id: 'rs1',
        categoryId: 'positive',
        weekStart: '2026-03-16',
        summary: 'Great week!',
        createdAt: DateTime(2026, 3, 18),
        updatedAt: DateTime(2026, 3, 18),
      ))),
      expect: () => [
        isA<CategoryDetailState>()
            .having(
              (s) => s.reviewSummary?.summary,
              'summary text',
              'Great week!',
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'relative date labels: 2 days ago',
      setUp: () async {
        await repository.addCategoryEntry(
          '2026-03-16', 'positive', 'Two days ago entry');
      },
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      act: (bloc) => bloc.add(const LoadCategoryDetail('positive')),
      expect: () => [
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loading),
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loaded)
            .having(
              (s) => s.recentEntries.first.displayDate,
              'displayDate',
              '2 days ago',
            ),
      ],
    );

    blocTest<CategoryDetailBloc, CategoryDetailState>(
      'hasRecentEntries is false when no entries in 7-day window',
      build: () => CategoryDetailBloc(
        repository: repository,
        clock: fixedClock,
      ),
      act: (bloc) => bloc.add(const LoadCategoryDetail('positive')),
      expect: () => [
        isA<CategoryDetailState>()
            .having((s) => s.status, 'status', CategoryDetailStatus.loading),
        isA<CategoryDetailState>()
            .having((s) => s.hasRecentEntries, 'hasRecentEntries', false),
      ],
    );
  });
}
