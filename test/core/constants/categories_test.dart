import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/categories.dart';

void main() {
  group('JournalCategory', () {
    test('has 5 categories', () {
      expect(JournalCategory.values.length, 5);
    });

    test('each category has displayName, prompt, icon, and color', () {
      for (final category in JournalCategory.values) {
        expect(category.displayName, isNotEmpty);
        expect(category.prompt, isNotEmpty);
        expect(category.icon, isNotEmpty);
        expect(category.color, isA<Color>());
      }
    });

    test('each category has a unique color', () {
      final colors = JournalCategory.values.map((c) => c.color).toSet();
      expect(colors.length, JournalCategory.values.length);
    });

    test('categories are in expected order', () {
      expect(JournalCategory.values[0], JournalCategory.positive);
      expect(JournalCategory.values[1], JournalCategory.negative);
      expect(JournalCategory.values[2], JournalCategory.gratitude);
      expect(JournalCategory.values[3], JournalCategory.beauty);
      expect(JournalCategory.values[4], JournalCategory.identity);
    });
  });
}
