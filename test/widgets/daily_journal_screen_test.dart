import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/daily_journal/daily_journal_screen.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';
import 'package:dytty/features/settings/cubit/settings_cubit.dart';

import '../helpers/pump_app.dart';
import '../robots/journal_screen_robot.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Animate.restartOnHotReload = false;

  setUpAll(() {
    registerFallbackValue(const LoadEntries());
  });

  late JournalScreenRobot robot;

  group('DailyJournalScreen', () {
    testWidgets('displays all default category cards', (tester) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(status: JournalStatus.loaded),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = JournalScreenRobot(tester);

      // First visible categories
      robot.expectCategoryCardVisible('Positive Things');
      robot.expectCategoryCardVisible('Negative Things');
      robot.expectCategoryCardVisible('Gratitude');

      // Scroll down to reveal remaining categories
      await tester.scrollUntilVisible(find.text('Beauty'), 200);
      await tester.pump(const Duration(milliseconds: 500));
      robot.expectCategoryCardVisible('Beauty');

      await tester.scrollUntilVisible(find.text('Identity'), 200);
      await tester.pump(const Duration(milliseconds: 500));
      robot.expectCategoryCardVisible('Identity');
    });

    testWidgets('shows empty banner when no entries', (tester) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(status: JournalStatus.loaded),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = JournalScreenRobot(tester);
      robot.expectEmptyBanner();
    });

    testWidgets('hides empty banner when entries exist', (tester) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'A great thing happened',
              createdAt: DateTime.now(),
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = JournalScreenRobot(tester);
      robot.expectEmptyBannerGone();
    });

    testWidgets('navigation buttons are present', (tester) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(status: JournalStatus.loaded),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byTooltip('Previous day'), findsOneWidget);
      expect(find.byTooltip('Next day'), findsOneWidget);
    });

    testWidgets('previous day button dispatches SelectDate', (tester) async {
      final mockJournalBloc = MockJournalBloc();
      when(
        () => mockJournalBloc.state,
      ).thenReturn(JournalState(status: JournalStatus.loaded));

      await tester.pumpApp(
        const DailyJournalScreen(),
        journalBloc: mockJournalBloc,
        journalState: JournalState(status: JournalStatus.loaded),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();

      verify(() => mockJournalBloc.add(any(that: isA<SelectDate>()))).called(1);
    });

    testWidgets('next day button dispatches SelectDate', (tester) async {
      final mockJournalBloc = MockJournalBloc();
      when(
        () => mockJournalBloc.state,
      ).thenReturn(JournalState(status: JournalStatus.loaded));

      await tester.pumpApp(
        const DailyJournalScreen(),
        journalBloc: mockJournalBloc,
        journalState: JournalState(status: JournalStatus.loaded),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('Next day'));
      await tester.pump();

      verify(() => mockJournalBloc.add(any(that: isA<SelectDate>()))).called(1);
    });

    testWidgets('shows "Today" title when selected date is today', (
      tester,
    ) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(status: JournalStatus.loaded),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('shows loading shimmer when status is loading', (tester) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(status: JournalStatus.loading),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // When loading, category cards should not be visible
      expect(find.text('Positive Things'), findsNothing);
    });

    testWidgets('shows hidden entry placeholder when hideEntries is true', (
      tester,
    ) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Secret thought',
              createdAt: DateTime.now(),
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
        settingsState: const SettingsState(loaded: true, hideEntries: true),
      );
      await tester.pump(const Duration(seconds: 1));

      // Entry text should be hidden
      expect(find.text('Tap to reveal'), findsOneWidget);
      expect(find.text('Secret thought'), findsNothing);
    });

    testWidgets('tapping add entry button opens bottom sheet', (tester) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(status: JournalStatus.loaded),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('Add Positive Things entry'));
      await tester.pumpAndSettle();

      // Bottom sheet should show the category prompt
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('delete entry button dispatches DeleteEntry', (tester) async {
      final mockJournalBloc = MockJournalBloc();
      when(() => mockJournalBloc.state).thenReturn(
        JournalState(
          status: JournalStatus.loaded,
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Delete me',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpApp(
        const DailyJournalScreen(),
        journalBloc: mockJournalBloc,
        journalState: JournalState(
          status: JournalStatus.loaded,
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Delete me',
              createdAt: DateTime.now(),
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Tap delete button on the entry
      await tester.tap(find.byTooltip('Delete entry'));
      await tester.pump();

      verify(
        () => mockJournalBloc.add(any(that: isA<DeleteEntry>())),
      ).called(1);
    });

    testWidgets('tapping empty category prompt opens bottom sheet', (
      tester,
    ) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(status: JournalStatus.loaded),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Tap the prompt text on the first empty category
      await tester.tap(find.text('What good things happened today?'));
      await tester.pumpAndSettle();

      // Bottom sheet should open
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows entry text in category card', (tester) async {
      await tester.pumpApp(
        const DailyJournalScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'gratitude',
              text: 'Grateful for sunshine',
              createdAt: DateTime.now(),
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = JournalScreenRobot(tester);
      robot.expectEntryVisible('Grateful for sunshine');
    });
  });
}
