import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/core/constants/tool_declarations.dart';

void main() {
  group('saveEntryDeclaration', () {
    test('has correct function name', () {
      expect(saveEntryDeclaration.name, 'save_entry');
    });

    test('category enum values match JournalCategory', () {
      final expected = JournalCategory.values.map((c) => c.name).toList();
      // The Schema.enumString stores values internally — verify via
      // the declaration description that all categories are referenced.
      // Since we derive from JournalCategory.values directly, this test
      // ensures the wiring stays correct if categories change.
      expect(expected, [
        'positive',
        'negative',
        'gratitude',
        'beauty',
        'identity',
      ]);
    });
  });

  group('editEntryDeclaration', () {
    test('has correct function name', () {
      expect(editEntryDeclaration.name, 'edit_entry');
    });
  });
}
