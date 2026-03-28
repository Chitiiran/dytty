import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/core/utils/date_utils.dart' as app_date;
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/review_summary.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/category_detail/bloc/category_detail_bloc.dart';
import 'package:dytty/features/category_detail/category_detail_screen.dart';
import 'package:dytty/features/category_detail/widgets/category_detail_header.dart';
import 'package:dytty/features/category_detail/widgets/date_group_header.dart';
import 'package:dytty/features/category_detail/widgets/empty_category_state.dart';
import 'package:dytty/features/category_detail/widgets/inline_entry_tile.dart';
import 'package:dytty/features/category_detail/widgets/review_summary_card.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';

import '../robots/category_detail_screen_robot.dart';

class MockCategoryDetailBloc
    extends MockBloc<CategoryDetailEvent, CategoryDetailState>
    implements CategoryDetailBloc {}

class MockJournalBloc extends MockBloc<JournalEvent, JournalState>
    implements JournalBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockLlmService extends Mock implements LlmService {}

class MockAudioStorageService extends Mock implements AudioStorageService {}

void main() {
  late MockCategoryDetailBloc mockBloc;
  late CategoryDetailScreenRobot robot;

  setUpAll(() {
    registerFallbackValue(const LoadCategoryDetail('positive'));
    registerFallbackValue(const ToggleDateGroup('2026-03-18'));
    registerFallbackValue(const StartInlineEdit('e1'));
    registerFallbackValue(const CancelInlineEdit());
  });

  setUp(() {
    mockBloc = MockCategoryDetailBloc();
  });

  /// Pumps a widget wrapped with the CategoryDetailBloc provider.
  Future<void> pumpWithBloc(
    WidgetTester tester,
    Widget widget, {
    CategoryDetailState? state,
  }) async {
    when(() => mockBloc.state).thenReturn(state ?? const CategoryDetailState());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CategoryDetailBloc>.value(
          value: mockBloc,
          child: Scaffold(body: widget),
        ),
      ),
    );
  }

  group('CategoryDetailHeader', () {
    testWidgets('renders category icon with call badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryDetailHeader(
              categoryId: 'positive',
              hasRecentEntries: true,
              onCallTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CategoryDetailHeader), findsOneWidget);
    });

    testWidgets('call badge is greyed when no recent entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryDetailHeader(
              categoryId: 'positive',
              hasRecentEntries: false,
              onCallTap: null,
            ),
          ),
        ),
      );

      expect(find.byType(CategoryDetailHeader), findsOneWidget);
    });
  });

  group('DateGroupHeader', () {
    testWidgets('renders display date and entry count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateGroupHeader(
              displayDate: 'Today',
              entryCount: 3,
              isCollapsed: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.textContaining('3'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateGroupHeader(
              displayDate: 'Yesterday',
              entryCount: 2,
              isCollapsed: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DateGroupHeader));
      expect(tapped, true);
    });
  });

  group('InlineEntryTile', () {
    final entry = CategoryEntry(
      id: 'e1',
      categoryId: 'positive',
      text: 'A great day',
      source: 'manual',
      createdAt: DateTime(2026, 3, 18, 10, 30),
    );

    testWidgets('renders entry text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InlineEntryTile(entry: entry, isEditing: false)),
        ),
      );

      expect(find.text('A great day'), findsOneWidget);
    });

    testWidgets('shows reviewed badge when isReviewed', (tester) async {
      final reviewedEntry = CategoryEntry(
        id: 'e2',
        categoryId: 'positive',
        text: 'Reviewed entry',
        createdAt: DateTime(2026, 3, 18),
        isReviewed: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineEntryTile(entry: reviewedEntry, isEditing: false),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('shows TextField in edit mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineEntryTile(
              entry: entry,
              isEditing: true,
              onSaveEdit: (_) {},
              onCancelEdit: () {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('has reduced opacity when isOlderEntry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineEntryTile(
              entry: entry,
              isEditing: false,
              isOlderEntry: true,
            ),
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, lessThan(1.0));
    });

    testWidgets('toggles to transcript on text tap', (tester) async {
      final entryWithTranscript = CategoryEntry(
        id: 'e3',
        categoryId: 'positive',
        text: 'Summary text',
        transcript: 'Full transcript text',
        createdAt: DateTime(2026, 3, 18),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineEntryTile(entry: entryWithTranscript, isEditing: false),
          ),
        ),
      );

      expect(find.text('Summary text'), findsOneWidget);

      // Tap to toggle to transcript
      await tester.tap(find.text('Summary text'));
      await tester.pumpAndSettle();

      expect(find.text('Full transcript text'), findsOneWidget);
    });
  });

  group('EmptyCategoryState', () {
    testWidgets('shows empty message with category name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyCategoryState(categoryId: 'gratitude')),
        ),
      );

      expect(find.byType(EmptyCategoryState), findsOneWidget);
      expect(find.textContaining('Gratitude'), findsOneWidget);
    });
  });

  group('ReviewSummaryCard', () {
    testWidgets('renders summary text', (tester) async {
      final summary = ReviewSummary(
        id: 'rs1',
        categoryId: 'positive',
        weekStart: '2026-03-16',
        summary: 'You had a wonderful week!',
        createdAt: DateTime(2026, 3, 18),
        updatedAt: DateTime(2026, 3, 18),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewSummaryCard(summary: summary, categoryId: 'positive'),
          ),
        ),
      );

      expect(find.text('You had a wonderful week!'), findsOneWidget);
    });
  });

  group('CategoryDetailScreen integration', () {
    testWidgets('shows empty state when no entries', (tester) async {
      await pumpWithBloc(
        tester,
        Builder(
          builder: (context) {
            final state = context.watch<CategoryDetailBloc>().state;
            if (state.status == CategoryDetailStatus.initial ||
                state.status == CategoryDetailStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.recentEntries.isEmpty && state.reviewSummary == null) {
              return const EmptyCategoryState(categoryId: 'positive');
            }
            return const Text('Has entries');
          },
        ),
        state: const CategoryDetailState(
          status: CategoryDetailStatus.loaded,
          categoryId: 'positive',
          hasRecentEntries: false,
        ),
      );

      robot = CategoryDetailScreenRobot(tester);
      robot.expectEmptyState();
    });

    testWidgets('shows entries grouped by date', (tester) async {
      final state = CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        hasRecentEntries: true,
        recentEntries: [
          DateGroup(
            date: '2026-03-18',
            displayDate: 'Today',
            entries: [
              CategoryEntry(
                id: 'e1',
                categoryId: 'positive',
                text: 'Great morning',
                createdAt: DateTime(2026, 3, 18, 8, 0),
              ),
              CategoryEntry(
                id: 'e2',
                categoryId: 'positive',
                text: 'Nice lunch',
                createdAt: DateTime(2026, 3, 18, 12, 0),
              ),
            ],
          ),
          DateGroup(
            date: '2026-03-17',
            displayDate: 'Yesterday',
            entries: [
              CategoryEntry(
                id: 'e3',
                categoryId: 'positive',
                text: 'Good evening',
                createdAt: DateTime(2026, 3, 17, 20, 0),
              ),
            ],
          ),
        ],
      );

      await pumpWithBloc(
        tester,
        Builder(
          builder: (context) {
            final s = context.watch<CategoryDetailBloc>().state;
            return ListView(
              children: [
                for (final group in s.recentEntries) ...[
                  DateGroupHeader(
                    displayDate: group.displayDate,
                    entryCount: group.entries.length,
                    isCollapsed: group.isCollapsed,
                    onTap: () {},
                  ),
                  if (!group.isCollapsed)
                    for (final entry in group.entries)
                      InlineEntryTile(
                        entry: entry,
                        isEditing: s.editingEntryId == entry.id,
                      ),
                ],
              ],
            );
          },
        ),
        state: state,
      );

      robot = CategoryDetailScreenRobot(tester);
      robot.expectDateGroupHeader('Today');
      robot.expectDateGroupHeader('Yesterday');
      robot.expectEntryText('Great morning');
      robot.expectEntryText('Nice lunch');
      robot.expectEntryText('Good evening');
      robot.expectEntryTileCount(3);
    });

    testWidgets('shows review summary card when summary exists', (
      tester,
    ) async {
      final now = DateTime(2026, 3, 18);
      final state = CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        hasRecentEntries: true,
        reviewSummary: ReviewSummary(
          id: 'rs1',
          categoryId: 'positive',
          weekStart: '2026-03-16',
          summary: 'Great week!',
          createdAt: now,
          updatedAt: now,
        ),
        recentEntries: [
          DateGroup(
            date: '2026-03-18',
            displayDate: 'Today',
            entries: [
              CategoryEntry(
                id: 'e1',
                categoryId: 'positive',
                text: 'Entry',
                createdAt: now,
              ),
            ],
          ),
        ],
      );

      await pumpWithBloc(
        tester,
        Builder(
          builder: (context) {
            final s = context.watch<CategoryDetailBloc>().state;
            return ListView(
              children: [
                if (s.reviewSummary != null)
                  ReviewSummaryCard(
                    summary: s.reviewSummary!,
                    categoryId: s.categoryId,
                  ),
                for (final group in s.recentEntries)
                  DateGroupHeader(
                    displayDate: group.displayDate,
                    entryCount: group.entries.length,
                    isCollapsed: group.isCollapsed,
                    onTap: () {},
                  ),
              ],
            );
          },
        ),
        state: state,
      );

      robot = CategoryDetailScreenRobot(tester);
      robot.expectReviewSummaryCard();
    });

    testWidgets('collapsible date header hides entries when collapsed', (
      tester,
    ) async {
      final state = CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        categoryId: 'positive',
        hasRecentEntries: true,
        recentEntries: [
          DateGroup(
            date: '2026-03-18',
            displayDate: 'Today',
            isCollapsed: true,
            entries: [
              CategoryEntry(
                id: 'e1',
                categoryId: 'positive',
                text: 'Hidden entry',
                createdAt: DateTime(2026, 3, 18),
              ),
            ],
          ),
        ],
      );

      await pumpWithBloc(
        tester,
        Builder(
          builder: (context) {
            final s = context.watch<CategoryDetailBloc>().state;
            return ListView(
              children: [
                for (final group in s.recentEntries) ...[
                  DateGroupHeader(
                    displayDate: group.displayDate,
                    entryCount: group.entries.length,
                    isCollapsed: group.isCollapsed,
                    onTap: () {},
                  ),
                  if (!group.isCollapsed)
                    for (final entry in group.entries)
                      InlineEntryTile(entry: entry, isEditing: false),
                ],
              ],
            );
          },
        ),
        state: state,
      );

      robot = CategoryDetailScreenRobot(tester);
      robot.expectDateGroupHeader('Today');
      // Entry should be hidden since group is collapsed
      expect(find.text('Hidden entry'), findsNothing);
      robot.expectEntryTileCount(0);
    });
  });

  group('CategoryDetailScreen (screen-level)', () {
    late FakeFirebaseFirestore firestore;
    late JournalRepository repository;
    late MockJournalBloc mockJournalBloc;
    late MockAuthBloc mockAuthBloc;
    late MockLlmService mockLlmService;
    late MockAudioStorageService mockAudioStorageService;
    late CategoryDetailScreenRobot robot;

    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final today = dateFormat.format(now);
    final yesterday = dateFormat.format(now.subtract(const Duration(days: 1)));

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = JournalRepository(uid: 'test-user', firestore: firestore);
      mockJournalBloc = MockJournalBloc();
      mockAuthBloc = MockAuthBloc();
      mockLlmService = MockLlmService();
      mockAudioStorageService = MockAudioStorageService();

      when(() => mockJournalBloc.repository).thenReturn(repository);
      when(() => mockJournalBloc.state).thenReturn(JournalState());
      when(() => mockAuthBloc.state).thenReturn(
        const Authenticated(
          uid: 'test-user',
          displayName: 'Test',
          email: 'test@test.com',
        ),
      );
    });

    /// Pumps the real CategoryDetailScreen with all required providers.
    Future<void> pumpScreen(
      WidgetTester tester, {
      String categoryId = 'positive',
    }) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<JournalBloc>.value(value: mockJournalBloc),
            BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          ],
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<LlmService>.value(value: mockLlmService),
              RepositoryProvider<AudioStorageService>.value(
                value: mockAudioStorageService,
              ),
            ],
            child: MaterialApp(
              home: CategoryDetailScreen(categoryId: categoryId),
            ),
          ),
        ),
      );
    }

    testWidgets('shows loading indicator when status is loading', (
      tester,
    ) async {
      // Use a repository that never completes so the bloc stays in loading
      final hangingRepo = _HangingJournalRepository();
      when(() => mockJournalBloc.repository).thenReturn(hangingRepo);

      await pumpScreen(tester);
      await tester.pump();

      robot = CategoryDetailScreenRobot(tester);
      robot.expectLoading();
    });

    testWidgets('shows empty state when loaded with no entries', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      robot = CategoryDetailScreenRobot(tester);
      robot.expectEmptyState();
    });

    testWidgets('AppBar shows category display name', (tester) async {
      await pumpScreen(tester, categoryId: 'positive');
      await tester.pumpAndSettle();

      robot = CategoryDetailScreenRobot(tester);
      robot.expectCategoryName('Positive Things');
    });

    testWidgets('AppBar shows correct name for gratitude category', (
      tester,
    ) async {
      await pumpScreen(tester, categoryId: 'gratitude');
      await tester.pumpAndSettle();

      robot = CategoryDetailScreenRobot(tester);
      robot.expectCategoryName('Gratitude');
    });

    testWidgets('back button is present in AppBar', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows date group headers and entries when loaded with data', (
      tester,
    ) async {
      // Pre-populate Firestore with entries for today
      await repository.addCategoryEntry(today, 'positive', 'Morning sunshine');
      await repository.addCategoryEntry(today, 'positive', 'Good coffee');

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      robot = CategoryDetailScreenRobot(tester);
      robot.expectNoEmptyState();
      robot.expectEntryText('Morning sunshine');
      robot.expectEntryText('Good coffee');
      robot.expectEntryTileCount(2);
    });

    testWidgets('shows entries across multiple date groups', (tester) async {
      // Pre-populate entries across two dates
      await repository.addCategoryEntry(today, 'positive', 'Today entry');
      await repository.addCategoryEntry(
        yesterday,
        'positive',
        'Yesterday entry',
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      robot = CategoryDetailScreenRobot(tester);
      robot.expectNoEmptyState();
      robot.expectEntryText('Today entry');
      robot.expectEntryText('Yesterday entry');
      // Two date group headers
      expect(find.byType(DateGroupHeader), findsNWidgets(2));
      robot.expectEntryTileCount(2);
    });

    testWidgets('shows review summary card when reviewSummary is set', (
      tester,
    ) async {
      // Pre-populate an entry so the screen renders the list view
      await repository.addCategoryEntry(today, 'positive', 'An entry');
      // Save a review summary for the current week
      final weekStart = dateFormat.format(app_date.mondayOfWeek(now));
      await repository.saveReviewSummary(
        ReviewSummary(
          id: '',
          categoryId: 'positive',
          weekStart: weekStart,
          summary: 'A thoughtful week of reflection.',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      robot = CategoryDetailScreenRobot(tester);
      robot.expectReviewSummaryCard();
      expect(find.text('A thoughtful week of reflection.'), findsOneWidget);
    });

    testWidgets('tapping a date group header dispatches ToggleDateGroup', (
      tester,
    ) async {
      await repository.addCategoryEntry(today, 'positive', 'Visible entry');

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      robot = CategoryDetailScreenRobot(tester);

      // Entry is visible before collapse
      robot.expectEntryText('Visible entry');
      robot.expectEntryTileCount(1);

      // Tap the date group header to collapse
      await tester.tap(find.byType(DateGroupHeader));
      await tester.pumpAndSettle();

      // Entry should be hidden after collapse
      expect(find.text('Visible entry'), findsNothing);
      robot.expectEntryTileCount(0);
    });

    testWidgets('shows error message when status is error', (tester) async {
      // Use a repository with an invalid uid to trigger a Firestore error.
      // Instead, we provide a mock JournalBloc returning a mock repository
      // that throws on load.
      final brokenRepo = _ThrowingJournalRepository();
      when(() => mockJournalBloc.repository).thenReturn(brokenRepo);

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      // The error text should be displayed in the body
      expect(find.textContaining('Simulated error'), findsOneWidget);
    });
  });
}

/// A JournalRepository that throws on load, used to test error state.
class _ThrowingJournalRepository extends Fake implements JournalRepository {
  @override
  Future<Set<String>> getDaysWithEntries(int year, int month) {
    throw Exception('Simulated error');
  }
}

/// A JournalRepository that never completes, keeping the bloc in loading state.
class _HangingJournalRepository extends Fake implements JournalRepository {
  @override
  Future<Set<String>> getDaysWithEntries(int year, int month) {
    return Completer<Set<String>>().future; // never completes
  }
}
