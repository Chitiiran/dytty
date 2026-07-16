import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/daily_journal/home_screen.dart';

import '../helpers/pump_app.dart';

/// #251: the mic FAB (and the nudge banner) start the daily call — the
/// one-shot voice note and the separate Call button retire. A FAB/nudge
/// call is explicitly a TODAY capture: it resets any stale selected date
/// before navigating so the bloc's journalDate wiring (#252) picks up
/// today. The radial mic keeps the tapped cell's date (its SelectDate
/// fired when the cell was tapped).
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Animate.restartOnHotReload = false;

  setUpAll(() {
    registerFallbackValue(SelectDate(DateTime(2000)));
  });

  late List<RouteSettings> pushed;

  RouteFactory captureRoute() {
    pushed = [];
    return (settings) {
      pushed.add(settings);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SizedBox.shrink(),
      );
    };
  }

  bool isSelectToday(JournalEvent e) =>
      e is SelectDate && DateUtils.isSameDay(e.date, DateTime.now());

  group('mic FAB (#251)', () {
    testWidgets('starts the daily call scoped to today', (tester) async {
      final journalBloc = MockJournalBloc();
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      await tester.pumpApp(
        const HomeScreen(),
        journalBloc: journalBloc,
        journalState: JournalState(selectedDate: pastDate),
        onGenerateRoute: captureRoute(),
      );
      await tester.pump(const Duration(seconds: 1));
      clearInteractions(journalBloc); // drop the startup SelectDate

      await tester.tap(find.byTooltip('Start daily call'));
      await tester.pump();

      expect(pushed.map((s) => s.name), contains('/voice-call'));
      // Race fix (#266 review): the intent date rides the route explicitly —
      // SelectDate processing is async and can lose to bloc construction.
      final callPush = pushed.lastWhere((s) => s.name == '/voice-call');
      expect(callPush.arguments, isA<DateTime>());
      expect(
        DateUtils.isSameDay(callPush.arguments as DateTime, DateTime.now()),
        isTrue,
      );
      verify(
        () => journalBloc.add(
          any(
            that: predicate<Object?>(
              (e) => e is JournalEvent && isSelectToday(e),
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('one-shot voice note affordance is gone', (tester) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byTooltip('Record voice note'), findsNothing);
    });

    testWidgets('Call button is gone; the FAB is the only call entry', (
      tester,
    ) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Call'), findsNothing);
      expect(find.text('Write'), findsNothing); // retired in PR2 (#256)
      expect(find.bySemanticsLabel('Today button'), findsNothing);
      expect(find.byTooltip('Start daily call'), findsOneWidget);
    });
  });

  group('nudge banner (#251)', () {
    testWidgets('starts the daily call scoped to today', (tester) async {
      final journalBloc = MockJournalBloc();
      await tester.pumpApp(
        const HomeScreen(),
        journalBloc: journalBloc,
        journalState: JournalState(
          status: JournalStatus.loaded,
          monthCategoryMarkers: const {},
        ),
        onGenerateRoute: captureRoute(),
      );
      await tester.pump(const Duration(seconds: 1));
      clearInteractions(journalBloc); // drop the startup SelectDate

      await tester.tap(find.textContaining("haven't journaled"));
      await tester.pump();

      expect(pushed.map((s) => s.name), contains('/voice-call'));
      verify(
        () => journalBloc.add(
          any(
            that: predicate<Object?>(
              (e) => e is JournalEvent && isSelectToday(e),
            ),
          ),
        ),
      ).called(1);
    });
  });

  group('radial mic (#251/#252)', () {
    testWidgets('starts the call WITHOUT resetting the tapped date', (
      tester,
    ) async {
      final journalBloc = MockJournalBloc();
      await tester.pumpApp(
        const HomeScreen(),
        journalBloc: journalBloc,
        journalState: JournalState(status: JournalStatus.loaded),
        onGenerateRoute: captureRoute(),
      );
      await tester.pump(const Duration(seconds: 1));
      clearInteractions(journalBloc); // drop the startup SelectDate

      // Tap a mid-month day cell to open the radial menu (dispatches
      // SelectDate for that cell — the ONLY SelectDate this flow allows).
      await tester.tap(find.text('15').first);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.bySemanticsLabel('Start voice call'));
      await tester.pump();

      expect(pushed.map((s) => s.name), contains('/voice-call'));
      // No explicit date argument: the radial path trusts selectedDate,
      // which its cell tap set long before.
      expect(
        pushed.lastWhere((s) => s.name == '/voice-call').arguments,
        isNull,
      );
      // Exactly one SelectDate (the cell tap) — the mic must NOT re-select.
      verify(
        () => journalBloc.add(
          any(that: predicate<Object?>((e) => e is SelectDate)),
        ),
      ).called(1);
    });
  });

  group('date-aware progress card (#256)', () {
    final now = DateTime.now();
    final day3 = DateTime(now.year, now.month, 3);
    final day3Str =
        '${day3.year.toString().padLeft(4, '0')}-'
        '${day3.month.toString().padLeft(2, '0')}-03';

    JournalState stateWithDay3Markers() => JournalState(
      status: JournalStatus.loaded,
      monthCategoryMarkers: {
        day3Str: const {'positive': 1, 'gratitude': 1},
      },
      todayCategoryCounts: const {'beauty': 1},
    );

    Future<void> openRadialOnDay3(WidgetTester tester) async {
      await tester.tap(find.text('3').first);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> dismissRadial(WidgetTester tester) async {
      final dynamic appState = tester.state(find.byType(WidgetsApp));
      await appState.didPopRoute();
      await tester.pumpAndSettle();
    }

    testWidgets('follows the radial-selected date and persists after close', (
      tester,
    ) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: stateWithDay3Markers(),
      );
      await tester.pump(const Duration(seconds: 1));

      await openRadialOnDay3(tester);
      expect(find.textContaining('Progress'), findsWidgets);
      expect(find.text('2/5'), findsOneWidget); // day-3 markers, not today's

      await dismissRadial(tester);
      await tester.ensureVisible(find.text('2/5'));
      expect(find.text('2/5'), findsOneWidget); // stays on day 3
      expect(find.byTooltip('Go to today'), findsOneWidget);
      expect(find.text("Today's Progress"), findsNothing);
    });

    testWidgets('go-to-today resets the card', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: stateWithDay3Markers(),
      );
      await tester.pump(const Duration(seconds: 1));
      await openRadialOnDay3(tester);
      await dismissRadial(tester);

      await tester.ensureVisible(find.byTooltip('Go to today'));
      await tester.tap(find.byTooltip('Go to today'));
      await tester.pump();

      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text('1/5'), findsOneWidget); // today's counts again
      expect(find.byTooltip('Go to today'), findsNothing);
    });

    testWidgets('card body tap opens the shown date day view', (tester) async {
      final journalBloc = MockJournalBloc();
      await tester.pumpApp(
        const HomeScreen(),
        journalBloc: journalBloc,
        journalState: stateWithDay3Markers(),
        onGenerateRoute: captureRoute(),
      );
      await tester.pump(const Duration(seconds: 1));
      await openRadialOnDay3(tester);
      await dismissRadial(tester);
      clearInteractions(journalBloc);

      await tester.ensureVisible(find.text('2/5'));
      await tester.tap(find.text('2/5')); // anywhere on the card body
      await tester.pump();

      expect(pushed.map((s) => s.name), contains('/daily-journal'));
      verify(
        () => journalBloc.add(
          any(
            that: predicate<Object?>(
              (e) => e is SelectDate && DateUtils.isSameDay(e.date, day3),
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('category dots still open category detail', (tester) async {
      await tester.pumpApp(
        const HomeScreen(),
        journalState: stateWithDay3Markers(),
        onGenerateRoute: captureRoute(),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.ensureVisible(find.byTooltip('Positive Things detail'));
      await tester.tap(find.byTooltip('Positive Things detail'));
      await tester.pump();

      final push = pushed.lastWhere((s) => s.name == '/category-detail');
      expect(push.arguments, 'positive');
    });
  });

  group('avatar button (#256 a11y)', () {
    testWidgets('is findable as Settings in the a11y tree', (tester) async {
      await tester.pumpApp(const HomeScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    });
  });
}
