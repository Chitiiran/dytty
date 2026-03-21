import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/features/daily_journal/widgets/completion_ring_cell.dart';

void main() {
  final categories = CategoryConfig.defaults; // 5 categories

  Widget buildCell({
    Map<String, int>? categoryMarkers,
    List<CategoryConfig>? activeCategories,
    bool isSelected = false,
    bool isToday = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CompletionRingCell(
              day: DateTime(2026, 3, 15),
              categoryMarkers: categoryMarkers,
              activeCategories: activeCategories ?? categories,
              isSelected: isSelected,
              isToday: isToday,
            ),
          ),
        ),
      ),
    );
  }

  group('CompletionRingCell', () {
    testWidgets('renders date number', (tester) async {
      await tester.pumpWidget(buildCell());
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('renders with null markers (dim ring)', (tester) async {
      await tester.pumpWidget(buildCell(categoryMarkers: null));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('renders with partial fill', (tester) async {
      await tester.pumpWidget(
        buildCell(categoryMarkers: {'positive': 1, 'gratitude': 2}),
      );
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('renders with 0 active categories', (tester) async {
      await tester.pumpWidget(buildCell(activeCategories: []));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('selected state renders without error', (tester) async {
      await tester.pumpWidget(buildCell(isSelected: true));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('today state renders without error', (tester) async {
      await tester.pumpWidget(buildCell(isToday: true));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('handles dynamic category count (3 categories)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCell(
          activeCategories: categories.take(3).toList(),
          categoryMarkers: {'positive': 1},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('full fill (all categories) renders without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCell(
          categoryMarkers: {
            'positive': 1,
            'negative': 1,
            'gratitude': 1,
            'beauty': 1,
            'identity': 1,
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('re-animates when markers change', (tester) async {
      await tester.pumpWidget(buildCell(categoryMarkers: {'positive': 1}));
      await tester.pumpAndSettle();

      // Update markers
      await tester.pumpWidget(
        buildCell(categoryMarkers: {'positive': 1, 'gratitude': 1}),
      );
      // Pump through the animation
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('15'), findsOneWidget);
    });
  });
}
