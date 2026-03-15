import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/daily_journal/daily_journal_screen.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';

import '../helpers/pump_app.dart';
import '../robots/journal_screen_robot.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Animate.restartOnHotReload = false;

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
      await tester.scrollUntilVisible(
        find.text('Beauty'),
        200,
      );
      await tester.pump(const Duration(milliseconds: 500));
      robot.expectCategoryCardVisible('Beauty');

      await tester.scrollUntilVisible(
        find.text('Identity'),
        200,
      );
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
