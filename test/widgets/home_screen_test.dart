import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/models/category_entry.dart';
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
  });
}
