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
      expect(find.text('Write'), findsOneWidget); // survives until PR2
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
      // Exactly one SelectDate (the cell tap) — the mic must NOT re-select.
      verify(
        () => journalBloc.add(
          any(that: predicate<Object?>((e) => e is SelectDate)),
        ),
      ).called(1);
    });
  });
}
