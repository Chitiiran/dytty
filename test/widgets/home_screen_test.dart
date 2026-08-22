import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/daily_journal/home_screen.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';

import '../helpers/pump_app.dart';
import '../robots/home_screen_robot.dart';

void main() {
  // Disable Google Fonts HTTP fetching in tests.
  GoogleFonts.config.allowRuntimeFetching = false;
  // Disable flutter_animate durations so animations complete instantly.
  Animate.restartOnHotReload = false;

  late HomeScreenRobot robot;

  setUp(() {
    Animate.restartOnHotReload = false;
  });

  group('HomeScreen', () {
    testWidgets('displays greeting with user name', (tester) async {
      await tester.pumpApp(const HomeScreen());
      // Advance past animations
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectGreetingVisible('Test');
    });

    testWidgets('shows nudge card when no entries today', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          monthCategoryMarkers: const {},
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectNudgeCardVisible();
    });

    testWidgets('hides nudge card when entries exist today', (tester) async {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          monthCategoryMarkers: {
            todayStr: {'positive': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Good day',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectNudgeCardGone();
    });

    testWidgets('progress card shows correct counts', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          todayCategoryCounts: const {'positive': 1, 'gratitude': 1},
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      // 2 categories filled out of 5 defaults
      robot.expectProgressVisible(2, 5);
    });

    testWidgets('progress card shows today counts when a past date is '
        'selected (#154)', (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: pastDate,
          // Selected (past) date has a single entry loaded...
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Old entry',
              createdAt: pastDate,
            ),
          ],
          // ...but today has 3 filled categories.
          todayCategoryCounts: const {
            'positive': 1,
            'gratitude': 2,
            'beauty': 1,
          },
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      // Dashboard reflects today (3/5), not the selected date (1/5).
      robot.expectProgressVisible(3, 5);
      expect(find.text("Today's Progress"), findsOneWidget);
    });

    testWidgets('shows error banner with retry when load failed (#170)', (
      tester,
    ) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          error: 'FAILED_PRECONDITION: index missing',
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining("Couldn't load"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping retry dispatches SelectDate for the selected date', (
      tester,
    ) async {
      final selected = DateTime(2026, 6, 1);
      final journalBloc = MockJournalBloc();

      await tester.pumpApp(
        const HomeScreen(),
        journalBloc: journalBloc,
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: selected,
          error: 'network down',
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => journalBloc.add(SelectDate(selected))).called(1);
    });

    testWidgets('no error banner when error is null', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(status: JournalStatus.loaded),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('mic FAB is present', (tester) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectMicFabVisible();
    });

    testWidgets('settings button is present', (tester) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectSettingsButtonVisible();
    });

    testWidgets('shows calendar with markers for days with entries', (
      tester,
    ) async {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          monthCategoryMarkers: {
            todayStr: {'positive': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Test entry',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Calendar should be visible
      expect(find.bySemanticsLabel('Calendar'), findsOneWidget);
    });

    testWidgets('shows progress for multiple categories', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          todayCategoryCounts: const {
            'positive': 1,
            'gratitude': 1,
            'beauty': 1,
          },
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectProgressVisible(3, 5);
    });

    testWidgets('shows 5/5 when all categories filled', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          todayCategoryCounts: const {
            'positive': 1,
            'negative': 1,
            'gratitude': 1,
            'beauty': 1,
            'identity': 1,
          },
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectProgressVisible(5, 5);
    });

    testWidgets('shows user avatar in app bar', (tester) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      // Settings button with user avatar
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets('shows initials avatar when no photo URL', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        authState: const Authenticated(
          uid: 'test-uid',
          displayName: 'Jane Doe',
          email: 'jane@test.com',
          photoUrl: null,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Should show 'J' as initials (first character of displayName)
      expect(find.text('J'), findsOneWidget);
    });

    testWidgets('shows ? avatar when no display name', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        authState: const Authenticated(
          uid: 'test-uid',
          displayName: null,
          email: 'anon@test.com',
          photoUrl: null,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Should show '?' as fallback initials
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('progress shows 0/5 when no entries', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          entries: const [],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectProgressVisible(0, 5);
    });

    testWidgets('progress card shows start message when no entries', (
      tester,
    ) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          entries: const [],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Start your daily reflection'), findsOneWidget);
    });

    testWidgets('progress card shows completion message when all filled', (
      tester,
    ) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          todayCategoryCounts: const {
            'positive': 1,
            'negative': 1,
            'gratitude': 1,
            'beauty': 1,
            'identity': 1,
          },
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('All categories complete!'), findsOneWidget);
    });

    testWidgets('progress card shows keep going message for partial entries', (
      tester,
    ) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          todayCategoryCounts: const {'positive': 1},
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Keep going!'), findsOneWidget);
      expect(find.textContaining('4 categories left'), findsOneWidget);
    });

    testWidgets('progress card shows singular category left for 4/5', (
      tester,
    ) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          todayCategoryCounts: const {
            'positive': 1,
            'negative': 1,
            'gratitude': 1,
            'beauty': 1,
          },
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('1 category left'), findsOneWidget);
    });

    testWidgets('streak badge shows when streak > 0', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          currentStreak: 3,
          entries: const [],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('3 days'), findsOneWidget);
    });

    testWidgets('streak badge shows singular for 1 day', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          currentStreak: 1,
          entries: const [],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1 day'), findsOneWidget);
    });

    testWidgets('streak badge hidden when streak is 0', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          currentStreak: 0,
          entries: const [],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // No streak badge — the fire icon is absent
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    });

    testWidgets('greeting uses first name only', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        authState: const Authenticated(
          uid: 'test-uid',
          displayName: 'Alice Wonderland',
          email: 'alice@test.com',
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Should show 'Alice' not 'Alice Wonderland'
      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.textContaining('Wonderland'), findsNothing);
    });

    testWidgets('greeting shows "there" when no display name', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        authState: const Authenticated(
          uid: 'test-uid',
          displayName: null,
          email: 'anon@test.com',
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('there'), findsOneWidget);
    });

    testWidgets('nudge card shows correct message text', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          monthCategoryMarkers: const {},
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("You haven't journaled today"), findsOneWidget);
      expect(find.text('It only takes a minute.'), findsOneWidget);
    });

    testWidgets('app bar shows Dytty title', (tester) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Dytty'), findsOneWidget);
    });

    testWidgets("Today's Progress title is visible", (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("Today's Progress"), findsOneWidget);
    });
  });
}
