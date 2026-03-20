import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/category_detail/widgets/category_detail_header.dart';

void main() {
  /// Wraps the header in a MaterialApp + Scaffold so it renders as an AppBar.
  Widget buildSubject({
    String categoryId = 'positive',
    bool hasRecentEntries = true,
    VoidCallback? onCallTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        appBar: CategoryDetailHeader(
          categoryId: categoryId,
          hasRecentEntries: hasRecentEntries,
          onCallTap: onCallTap,
        ),
      ),
    );
  }

  group('CategoryDetailHeader', () {
    testWidgets('renders category display name', (tester) async {
      await tester.pumpWidget(buildSubject(categoryId: 'gratitude'));

      expect(find.text('Gratitude'), findsOneWidget);
    });

    testWidgets('shows call badge icon', (tester) async {
      await tester.pumpWidget(buildSubject());

      // The positive category icon is wb_sunny_rounded
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    });

    testWidgets('tap callback fires when hasRecentEntries is true', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildSubject(hasRecentEntries: true, onCallTap: () => tapped = true),
      );

      await tester.tap(find.byType(IconButton).last);
      expect(tapped, true);
    });

    testWidgets('tap callback does NOT fire when hasRecentEntries is false', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildSubject(hasRecentEntries: false, onCallTap: () => tapped = true),
      );

      // The IconButton should be disabled; tapping should not fire callback.
      await tester.tap(find.byType(IconButton).last);
      expect(tapped, false);
    });

    testWidgets('has tooltip "Start review call" when enabled', (tester) async {
      await tester.pumpWidget(
        buildSubject(hasRecentEntries: true, onCallTap: () {}),
      );

      expect(find.byTooltip('Start review call'), findsOneWidget);
    });

    testWidgets('has tooltip "No recent entries" when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(hasRecentEntries: false));

      expect(find.byTooltip('No recent entries'), findsOneWidget);
    });
  });
}
