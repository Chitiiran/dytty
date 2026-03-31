import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/daily_journal/home_screen.dart';
import 'package:dytty/features/daily_journal/widgets/category_radial_menu.dart';
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

      // Find today's date cell and get its position
      final dateFinder = find.text('${today.day}').first;
      final dateCenter = tester.getCenter(dateFinder);

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
      'radial menu does not open when fewer than 2 categories available',
      (tester) async {
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

        // Tap today's date
        await tester.tap(find.text('${today.day}').first);
        await tester.pumpAndSettle();

        // Menu should NOT appear (circular_menu requires at least 2 items)
        expect(find.byType(CategoryRadialMenu), findsNothing);
      },
    );

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

      // Get the Positioned widget
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(CategoryRadialMenu),
          matching: find.byType(Positioned),
        ),
      );

      final screenSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;

      // Menu (250x250) with 16px padding should be within bounds
      expect(positioned.left!, greaterThanOrEqualTo(16.0));
      expect(positioned.top!, greaterThanOrEqualTo(16.0));
      expect(positioned.left! + 250, lessThanOrEqualTo(screenSize.width - 16));
      expect(positioned.top! + 250, lessThanOrEqualTo(screenSize.height - 16));
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
}
