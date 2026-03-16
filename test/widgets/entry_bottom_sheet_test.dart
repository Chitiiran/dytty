import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/features/daily_journal/widgets/entry_bottom_sheet.dart';

void main() {
  final testCategory = CategoryConfig.defaults.first;

  Widget buildApp({String? initialText}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showEntryBottomSheet(
              context,
              category: testCategory,
              initialText: initialText,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  group('EntryBottomSheet', () {
    testWidgets('shows category name and prompt', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(testCategory.displayName), findsOneWidget);
      expect(find.text(testCategory.prompt), findsAtLeast(1));
    });

    testWidgets('save button is disabled when text is empty', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, 'Save');
      expect(saveButton, findsOneWidget);

      final button = tester.widget<FilledButton>(saveButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('save button enables when text is entered', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test entry');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows Edit title and Update button with initialText', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(initialText: 'Existing text'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit ${testCategory.displayName}'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Update'), findsOneWidget);
    });

    testWidgets('pre-fills text field with initialText', (tester) async {
      await tester.pumpWidget(buildApp(initialText: 'Existing text'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Existing text'), findsOneWidget);

      // Update button should be enabled since text is pre-filled
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update'),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
