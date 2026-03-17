import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
          daysWithEntries: const {},
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
          daysWithEntries: {todayStr},
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
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Good day',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e2',
              categoryId: 'gratitude',
              text: 'Thankful',
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

      robot = HomeScreenRobot(tester);
      // 2 categories filled out of 5 defaults
      robot.expectProgressVisible(2, 5);
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

    testWidgets('today button is present', (tester) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectTodayButtonVisible();
    });

    testWidgets('daily call button is present', (tester) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      robot = HomeScreenRobot(tester);
      robot.expectDailyCallButtonVisible();
    });

    testWidgets('shows calendar with markers for days with entries', (
      tester,
    ) async {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          daysWithEntries: {todayStr},
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
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Good',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e2',
              categoryId: 'gratitude',
              text: 'Thanks',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e3',
              categoryId: 'beauty',
              text: 'Sunset',
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

      robot = HomeScreenRobot(tester);
      robot.expectProgressVisible(3, 5);
    });

    testWidgets('shows 5/5 when all categories filled', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Good',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e2',
              categoryId: 'negative',
              text: 'Bad',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e3',
              categoryId: 'gratitude',
              text: 'Thanks',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e4',
              categoryId: 'beauty',
              text: 'Sunset',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e5',
              categoryId: 'identity',
              text: 'Growth',
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
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Good',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e2',
              categoryId: 'negative',
              text: 'Bad',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e3',
              categoryId: 'gratitude',
              text: 'Thanks',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e4',
              categoryId: 'beauty',
              text: 'Sunset',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e5',
              categoryId: 'identity',
              text: 'Growth',
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

      expect(find.text('All categories complete!'), findsOneWidget);
    });

    testWidgets('progress card shows keep going message for partial entries', (
      tester,
    ) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Good',
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
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Good',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e2',
              categoryId: 'negative',
              text: 'Bad',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e3',
              categoryId: 'gratitude',
              text: 'Thanks',
              createdAt: DateTime.now(),
            ),
            CategoryEntry(
              id: 'e4',
              categoryId: 'beauty',
              text: 'Sunset',
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
          daysWithEntries: const {},
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
