import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/features/daily_journal/widgets/category_radial_menu.dart';

void main() {
  final testCategories = CategoryConfig.defaults.take(3).toList();

  Widget buildTestWidget({
    List<CategoryConfig>? categories,
    Map<String, int> filledCounts = const {},
    void Function(CategoryConfig)? onCategoryTap,
    VoidCallback? onVoiceTap,
    double radius = 80,
    ({double start, double sweep}) window = (start: 3 * pi / 2, sweep: 2 * pi),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: CategoryRadialMenu(
              categories: categories ?? testCategories,
              filledCounts: filledCounts,
              onCategoryTap: onCategoryTap ?? (_) {},
              onVoiceTap: onVoiceTap ?? () {},
              radius: radius,
              window: window,
            ),
          ),
        ),
      ),
    );
  }

  group('CategoryRadialMenu', () {
    testWidgets('renders mic icon in center', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('renders one item per category after animation', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      for (final cat in testCategories) {
        expect(find.byIcon(cat.icon), findsOneWidget);
      }
    });

    testWidgets('tapping mic calls onVoiceTap', (tester) async {
      var voiceTapped = false;
      await tester.pumpWidget(
        buildTestWidget(onVoiceTap: () => voiceTapped = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();

      expect(voiceTapped, isTrue);
    });

    testWidgets('tapping category icon calls onCategoryTap', (tester) async {
      CategoryConfig? tappedCategory;
      await tester.pumpWidget(
        buildTestWidget(onCategoryTap: (cat) => tappedCategory = cat),
      );
      await tester.pumpAndSettle();

      // Items are expanded after animation. Tap the first category.
      await tester.tap(
        find.byIcon(testCategories.first.icon),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(tappedCategory?.id, testCategories.first.id);
    });

    testWidgets('shows single checkmark badge for 1 entry', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(filledCounts: {testCategories.first.id: 1}),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u2713'), findsOneWidget);
    });

    testWidgets('shows double checkmark badge for 2+ entries', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(filledCounts: {testCategories.first.id: 3}),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u2713\u2713'), findsOneWidget);
    });

    testWidgets('archived category uses grey color', (tester) async {
      final archivedCat = testCategories.first.copyWith(isArchived: true);
      final cats = [archivedCat, ...testCategories.skip(1)];

      await tester.pumpWidget(buildTestWidget(categories: cats));
      await tester.pumpAndSettle();

      // The archived category's icon should use grey color
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      final archivedIcon = icons.where(
        (icon) => icon.icon == archivedCat.icon && icon.size == 22,
      );
      expect(archivedIcon.isNotEmpty, isTrue);
      expect(archivedIcon.first.color, Colors.grey.shade400);
    });

    testWidgets('has semantic label on mic button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Start voice call'), findsOneWidget);
    });
  });

  group('radius and arc parameters (#190)', () {
    Offset micCenter(WidgetTester tester) =>
        tester.getCenter(find.byIcon(Icons.mic_rounded));

    List<Offset> itemCenters(WidgetTester tester) => [
      for (final cat in testCategories) tester.getCenter(find.byIcon(cat.icon)),
    ];

    testWidgets('items sit at the injected radius', (tester) async {
      await tester.pumpWidget(buildTestWidget(radius: 60));
      await tester.pumpAndSettle();

      final mic = micCenter(tester);
      for (final c in itemCenters(tester)) {
        expect((c - mic).distance, closeTo(60, 14));
      }
    });

    testWidgets('partial arc keeps items inside the window quadrant', (
      tester,
    ) async {
      // 3*pi/2 .. 2*pi sweeps from 12 o'clock to 3 o'clock (up-right) —
      // a window circular_menu could not express (it wraps at 2*pi).
      await tester.pumpWidget(
        buildTestWidget(radius: 60, window: (start: 3 * pi / 2, sweep: pi / 2)),
      );
      await tester.pumpAndSettle();

      final mic = micCenter(tester);
      for (final c in itemCenters(tester)) {
        expect(c.dx, greaterThanOrEqualTo(mic.dx - 14), reason: 'rightward');
        expect(c.dy, lessThanOrEqualTo(mic.dy + 14), reason: 'upward');
      }
    });

    testWidgets('mic is visually cell-sized with a 48dp tap target', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tapTarget = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.mic_rounded),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(tapTarget.width, greaterThanOrEqualTo(48));
      expect(tapTarget.height, greaterThanOrEqualTo(48));

      final micIcon = tester.widget<Icon>(find.byIcon(Icons.mic_rounded));
      expect(micIcon.size, 20, reason: 'visual mic stays cell-sized');
    });
  });
}
