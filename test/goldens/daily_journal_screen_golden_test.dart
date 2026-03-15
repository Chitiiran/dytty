import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/daily_journal/daily_journal_screen.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';
import 'golden_test_helper.dart';

// Golden tests for DailyJournalScreen.
//
// Inter font is bundled in assets/fonts/ and runtime fetching is disabled
// in test/flutter_test_config.dart. See login_screen_golden_test.dart.

void main() {
  group('DailyJournalScreen golden tests', () {
    testWidgets('empty day', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(
          const DailyJournalScreen(),
          journalState: JournalState(
            status: JournalStatus.loaded,
            selectedDate: DateTime(2026, 3, 15),
          ),
          categoryState: CategoryState(
            categories: CategoryConfig.defaults,
            loaded: true,
          ),
          size: const Size(400, 900),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('fixtures/journal_screen_empty.png'),
      );
    });

    testWidgets('with entries', (tester) async {
      final entries = [
        CategoryEntry(
          id: '1',
          categoryId: 'positive',
          text: 'Had a great morning walk',
          createdAt: DateTime(2026, 3, 15, 9, 0),
        ),
        CategoryEntry(
          id: '2',
          categoryId: 'gratitude',
          text: 'Grateful for my family',
          createdAt: DateTime(2026, 3, 15, 10, 0),
        ),
      ];

      await tester.pumpWidget(
        goldenWrapper(
          const DailyJournalScreen(),
          journalState: JournalState(
            status: JournalStatus.loaded,
            selectedDate: DateTime(2026, 3, 15),
            entries: entries,
          ),
          categoryState: CategoryState(
            categories: CategoryConfig.defaults,
            loaded: true,
          ),
          size: const Size(400, 900),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('fixtures/journal_screen_with_entries.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(
          const DailyJournalScreen(),
          journalState: JournalState(
            status: JournalStatus.loaded,
            selectedDate: DateTime(2026, 3, 15),
          ),
          categoryState: CategoryState(
            categories: CategoryConfig.defaults,
            loaded: true,
          ),
          themeMode: ThemeMode.dark,
          size: const Size(400, 900),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('fixtures/journal_screen_dark.png'),
      );
    });
  });
}
