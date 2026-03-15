import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_config.dart';

void main() {
  group('CategoryConfig.defaults', () {
    test('has 5 default categories', () {
      expect(CategoryConfig.defaults.length, 5);
    });

    test('each category has displayName, prompt, icon, and color', () {
      for (final category in CategoryConfig.defaults) {
        expect(category.displayName, isNotEmpty);
        expect(category.prompt, isNotEmpty);
        expect(category.icon, isA<IconData>());
        expect(category.color, isA<Color>());
      }
    });

    test('each category has a unique color', () {
      final colors = CategoryConfig.defaults.map((c) => c.colorValue).toSet();
      expect(colors.length, CategoryConfig.defaults.length);
    });

    test('categories are in expected order', () {
      expect(CategoryConfig.defaults[0].id, 'positive');
      expect(CategoryConfig.defaults[1].id, 'negative');
      expect(CategoryConfig.defaults[2].id, 'gratitude');
      expect(CategoryConfig.defaults[3].id, 'beauty');
      expect(CategoryConfig.defaults[4].id, 'identity');
    });

    test('each category has a unique icon', () {
      final icons =
          CategoryConfig.defaults.map((c) => c.iconCodePoint).toSet();
      expect(icons.length, CategoryConfig.defaults.length);
    });

    test('all defaults are marked isDefault', () {
      for (final category in CategoryConfig.defaults) {
        expect(category.isDefault, true);
      }
    });
  });
}
