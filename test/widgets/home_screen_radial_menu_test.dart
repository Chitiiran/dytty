import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:dytty/features/daily_journal/home_screen.dart';
import 'package:dytty/features/daily_journal/widgets/category_radial_menu.dart';
import 'package:dytty/features/daily_journal/widgets/completion_ring_cell.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';

import '../helpers/pump_app.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Animate.restartOnHotReload = false;

  final dateFormat = DateFormat('yyyy-MM-dd');

  setUp(() {
    Animate.restartOnHotReload = false;
  });

  setUpAll(() {
    registerFallbackValue(SelectDate(DateTime.now()));
  });

  group('Radial menu positioning — multi-component', () {
    testWidgets('tapping a calendar date opens radial menu overlay', (
      tester,
    ) async {
      final today = DateTime.now();
      final todayStr = dateFormat.format(today);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: today,
          monthCategoryMarkers: {
            todayStr: {'positive': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Test',
              createdAt: today,
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Tap today's date in the calendar
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();

      // Radial menu should appear as an overlay
      expect(find.byType(CategoryRadialMenu), findsOneWidget);
    });

    testWidgets('radial menu uses Positioned widget, not Center', (
      tester,
    ) async {
      final today = DateTime.now();
      final todayStr = dateFormat.format(today);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: today,
          monthCategoryMarkers: {
            todayStr: {'positive': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Test',
              createdAt: today,
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Tap today's date
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();

      // Should use Positioned, not Center, for the menu container
      final radialMenu = find.byType(CategoryRadialMenu);
      expect(radialMenu, findsOneWidget);

      // Walk up the tree to verify Positioned ancestor exists
      final positioned = find.ancestor(
        of: radialMenu,
        matching: find.byType(Positioned),
      );
      expect(positioned, findsOneWidget);
    });

    testWidgets('radial menu positioned near tap, not at screen center', (
      tester,
    ) async {
      final today = DateTime.now();
      final todayStr = dateFormat.format(today);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: today,
          monthCategoryMarkers: {
            todayStr: {'positive': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Test',
              createdAt: today,
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Find today's date cell and tap it
      final dateFinder = find.text('${today.day}').first;

      // Tap the date
      await tester.tap(dateFinder);
      await tester.pumpAndSettle();

      // Get the Positioned widget wrapping the menu
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(CategoryRadialMenu),
          matching: find.byType(Positioned),
        ),
      );

      // The menu (250x250) should be positioned so its center is near the
      // tap location (clamped to screen bounds). Verify it's not at the
      // default center position.
      final screenSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final screenCenterX = screenSize.width / 2 - 125; // center - half menu
      final screenCenterY = screenSize.height / 2 - 125;

      // At least one of left/top should differ from screen center position,
      // unless the date happened to be exactly at screen center (unlikely).
      final isAtCenter =
          (positioned.left! - screenCenterX).abs() < 1 &&
          (positioned.top! - screenCenterY).abs() < 1;
      expect(
        isAtCenter,
        isFalse,
        reason:
            'Menu should not be at screen center — it should be near the tapped date',
      );
    });

    testWidgets('tapping outside radial menu dismisses it', (tester) async {
      final today = DateTime.now();
      final todayStr = dateFormat.format(today);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: today,
          monthCategoryMarkers: {
            todayStr: {'positive': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Test',
              createdAt: today,
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Open menu
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryRadialMenu), findsOneWidget);

      // Tap the overlay backdrop (bottom-left corner, away from menu)
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Menu should be dismissed
      expect(find.byType(CategoryRadialMenu), findsNothing);
    });

    testWidgets('radial menu shows correct category badges from state', (
      tester,
    ) async {
      final today = DateTime.now();
      final todayStr = dateFormat.format(today);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: today,
          monthCategoryMarkers: {
            todayStr: {'positive': 2, 'gratitude': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Good',
              createdAt: today,
            ),
            CategoryEntry(
              id: 'e2',
              categoryId: 'positive',
              text: 'Great',
              createdAt: today,
            ),
            CategoryEntry(
              id: 'e3',
              categoryId: 'gratitude',
              text: 'Thanks',
              createdAt: today,
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Open the radial menu
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();

      // Should show checkmark badges:
      // positive has 2 entries -> double checkmark
      expect(find.text('\u2713\u2713'), findsOneWidget);
      // gratitude has 1 entry -> single checkmark
      expect(find.text('\u2713'), findsOneWidget);
    });

    testWidgets(
      'radial menu opens with a single category (in-house layout, #190)',
      (tester) async {
        // circular_menu needed >= 2 items; the in-house layout places a
        // lone bubble at the window midpoint.
        final today = DateTime.now();

        await tester.pumpApp(
          const HomeScreen(),
          journalState: JournalState(
            status: JournalStatus.loaded,
            selectedDate: today,
          ),
          categoryState: CategoryState(
            categories: [CategoryConfig.defaults.first],
            loaded: true,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text('${today.day}').first);
        await tester.pumpAndSettle();

        expect(find.byType(CategoryRadialMenu), findsOneWidget);
        expect(find.byIcon(CategoryConfig.defaults.first.icon), findsWidgets);
      },
    );

    testWidgets('radial menu does not open with no available categories', (
      tester,
    ) async {
      final today = DateTime.now();
      final allArchived = [
        for (final cat in CategoryConfig.defaults)
          cat.copyWith(isArchived: true),
      ];

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: today,
        ),
        categoryState: CategoryState(categories: allArchived, loaded: true),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryRadialMenu), findsNothing);
    });

    testWidgets('tapping date dispatches SelectDate to JournalBloc', (
      tester,
    ) async {
      final today = DateTime.now();
      final mockJournalBloc = MockJournalBloc();

      when(() => mockJournalBloc.state).thenReturn(
        JournalState(status: JournalStatus.loaded, selectedDate: today),
      );

      await tester.pumpApp(
        const HomeScreen(),
        journalBloc: mockJournalBloc,
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Tap today's date
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();

      // Verify SelectDate was dispatched
      verify(
        () => mockJournalBloc.add(any(that: isA<SelectDate>())),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('menu position stays within screen bounds (clamping)', (
      tester,
    ) async {
      final today = DateTime.now();
      final todayStr = dateFormat.format(today);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: today,
          monthCategoryMarkers: {
            todayStr: {'positive': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Test',
              createdAt: today,
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Tap today's date
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();

      final screenSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;

      // Assert on rendered geometry, not Positioned fields — follower mode
      // lays the box out at 0,0 and paints it at the cell. Every bubble
      // must land on-screen for a mid-calendar cell.
      for (final cat in CategoryConfig.defaults) {
        final rect = tester.getRect(find.byIcon(cat.icon).last);
        expect(rect.left, greaterThanOrEqualTo(0), reason: cat.id);
        expect(rect.top, greaterThanOrEqualTo(0), reason: cat.id);
        expect(rect.right, lessThanOrEqualTo(screenSize.width), reason: cat.id);
        expect(
          rect.bottom,
          lessThanOrEqualTo(screenSize.height),
          reason: cat.id,
        );
      }
    });

    testWidgets('radial menu shows mic button for voice call', (tester) async {
      final today = DateTime.now();
      final todayStr = dateFormat.format(today);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: today,
          monthCategoryMarkers: {
            todayStr: {'positive': 1},
          },
          entries: [
            CategoryEntry(
              id: 'e1',
              categoryId: 'positive',
              text: 'Test',
              createdAt: today,
            ),
          ],
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Open menu
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();

      // Mic button in center of radial menu
      expect(find.bySemanticsLabel('Start voice call'), findsOneWidget);
    });
  });

  group('Radial menu geometry (#188, #190)', () {
    Future<Rect> openMenuOnDay15(WidgetTester tester) async {
      final now = DateTime.now();
      final fixedDay = DateTime(now.year, now.month, 15);
      final dayStr = dateFormat.format(fixedDay);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: fixedDay,
          monthCategoryMarkers: {
            dayStr: {'positive': 1},
          },
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final cellFinder = find
          .ancestor(
            of: find.text('15').first,
            matching: find.byType(CompletionRingCell),
          )
          .first;
      final cellRect = tester.getRect(cellFinder);
      // Tap OFF-center so a tap-position anchor would diverge.
      await tester.tapAt(cellRect.topLeft + const Offset(4, 4));
      await tester.pumpAndSettle();
      return cellRect;
    }

    testWidgets('menu tracks the cell when insets shift the layout under it '
        '(owner-verify finding)', (tester) async {
      final cellBefore = await openMenuOnDay15(tester);

      // Simulate a system inset change (keyboard settling, status bar) that
      // pushes the page content down while the menu route stays up. The
      // anchor was captured at open; an un-tracked menu goes stale.
      tester.view.padding = const FakeViewPadding(top: 200);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      final cellAfter = tester.getRect(
        find
            .ancestor(
              of: find.text('15', skipOffstage: false).first,
              matching: find.byType(CompletionRingCell),
            )
            .first,
      );
      // Guard: the simulation must actually move the calendar.
      expect(
        (cellAfter.center.dy - cellBefore.center.dy).abs(),
        greaterThan(5),
        reason: 'inset change should shift the cell',
      );

      final mic = tester.getCenter(find.bySemanticsLabel('Start voice call'));
      expect(mic.dx, closeTo(cellAfter.center.dx, 1.0));
      expect(mic.dy, closeTo(cellAfter.center.dy, 1.0));
    });

    testWidgets('menu box centers exactly on the tapped cell (#188/#190)', (
      tester,
    ) async {
      final cellRect = await openMenuOnDay15(tester);

      expect(find.byType(CategoryRadialMenu), findsOneWidget);
      final menuRect = tester.getRect(
        find
            .ancestor(
              of: find.byType(CategoryRadialMenu),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      // No clamping anymore — the box center IS the cell center.
      expect(menuRect.center.dx, closeTo(cellRect.center.dx, 1.0));
      expect(menuRect.center.dy, closeTo(cellRect.center.dy, 1.0));
    });

    testWidgets('first-row cell keeps every bubble on-screen (#190)', (
      tester,
    ) async {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);

      await tester.pumpApp(
        const HomeScreen(),
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: firstDay,
        ),
        categoryState: CategoryState(
          categories: CategoryConfig.defaults,
          loaded: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('1', skipOffstage: false).first);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryRadialMenu), findsOneWidget);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      for (final cat in CategoryConfig.defaults) {
        final rect = tester.getRect(find.byIcon(cat.icon).last);
        expect(rect.left, greaterThanOrEqualTo(0), reason: cat.id);
        expect(rect.top, greaterThanOrEqualTo(0), reason: cat.id);
        expect(rect.right, lessThanOrEqualTo(screen.width), reason: cat.id);
        expect(rect.bottom, lessThanOrEqualTo(screen.height), reason: cat.id);
      }
    });

    testWidgets('menu stays open after saving an entry, badge updates (#158)', (
      tester,
    ) async {
      final now = DateTime.now();
      final fixedDay = DateTime(now.year, now.month, 15);
      final dayStr = dateFormat.format(fixedDay);
      final journalBloc = MockJournalBloc();

      final states = StreamController<JournalState>.broadcast();
      whenListen(
        journalBloc,
        states.stream,
        initialState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: fixedDay,
        ),
      );

      await tester.pumpApp(
        const HomeScreen(),
        journalBloc: journalBloc,
        journalState: JournalState(
          status: JournalStatus.loaded,
          selectedDate: fixedDay,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final cellRect = tester.getRect(
        find
            .ancestor(
              of: find.text('15').first,
              matching: find.byType(CompletionRingCell),
            )
            .first,
      );
      await tester.tapAt(cellRect.center);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryRadialMenu), findsOneWidget);

      // Open the entry sheet from a bubble, type, save.
      await tester.tap(
        find.bySemanticsLabel('Add Positive Things entry from menu'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Stay open');
      // Rebuild so the Save button enables (_hasText gate).
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Menu still mounted (#158)...
      expect(find.byType(CategoryRadialMenu), findsOneWidget);

      // ...the entry targeted the MENU's date, not whatever selectedDate
      // drifted to (the date the user is journaling on stays pinned).
      // table_calendar emits UTC midnights from onDaySelected.
      verify(
        () => journalBloc.add(
          AddEntry(
            categoryId: 'positive',
            text: 'Stay open',
            date: DateTime.utc(fixedDay.year, fixedDay.month, fixedDay.day),
          ),
        ),
      ).called(1);

      // ...and a marker update from the bloc reaches the badge live.
      states.add(
        JournalState(
          status: JournalStatus.loaded,
          selectedDate: fixedDay,
          monthCategoryMarkers: {
            dayStr: {'positive': 1},
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('✓'), findsOneWidget);

      await states.close();
    });

    testWidgets('back gesture dismisses the menu, not the screen (#158)', (
      tester,
    ) async {
      await openMenuOnDay15(tester);
      expect(find.byType(CategoryRadialMenu), findsOneWidget);

      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(CategoryRadialMenu), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
