@Tags(['golden'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/features/daily_journal/widgets/completion_ring_cell.dart';

void main() {
  final categories = CategoryConfig.defaults;

  Widget buildRing({
    Map<String, int>? markers,
    List<CategoryConfig>? cats,
    bool isSelected = false,
    bool isToday = false,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CompletionRingCell(
              day: DateTime(2026, 3, 15),
              categoryMarkers: markers,
              activeCategories: cats ?? categories,
              isSelected: isSelected,
              isToday: isToday,
            ),
          ),
        ),
      ),
    );
  }

  group('CompletionRing goldens', () {
    testWidgets('empty ring (0/5)', (tester) async {
      await tester.pumpWidget(buildRing());
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CompletionRingCell),
        matchesGoldenFile('fixtures/completion_ring_empty.png'),
      );
    });

    testWidgets('partial ring (3/5)', (tester) async {
      await tester.pumpWidget(
        buildRing(markers: {'positive': 1, 'gratitude': 1, 'identity': 1}),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CompletionRingCell),
        matchesGoldenFile('fixtures/completion_ring_partial.png'),
      );
    });

    testWidgets('full ring (5/5)', (tester) async {
      await tester.pumpWidget(
        buildRing(
          markers: {
            'positive': 1,
            'negative': 1,
            'gratitude': 1,
            'beauty': 1,
            'identity': 1,
          },
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CompletionRingCell),
        matchesGoldenFile('fixtures/completion_ring_full.png'),
      );
    });

    testWidgets('selected state', (tester) async {
      await tester.pumpWidget(
        buildRing(markers: {'positive': 1, 'gratitude': 1}, isSelected: true),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CompletionRingCell),
        matchesGoldenFile('fixtures/completion_ring_selected.png'),
      );
    });

    testWidgets('today state', (tester) async {
      await tester.pumpWidget(
        buildRing(markers: {'positive': 1}, isToday: true),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CompletionRingCell),
        matchesGoldenFile('fixtures/completion_ring_today.png'),
      );
    });

    testWidgets('3 categories ring', (tester) async {
      await tester.pumpWidget(
        buildRing(
          cats: categories.take(3).toList(),
          markers: {'positive': 1, 'negative': 1},
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CompletionRingCell),
        matchesGoldenFile('fixtures/completion_ring_3cats.png'),
      );
    });
  });
}
