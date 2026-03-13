import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_config.dart';

void main() {
  group('CategoryConfig', () {
    test('toFirestore produces expected map', () {
      const config = CategoryConfig(
        id: 'test_cat',
        displayName: 'Test Category',
        prompt: 'What happened?',
        iconCodePoint: 0xe047,
        iconFontFamily: 'MaterialIcons',
        colorValue: 0xFFFF0000,
        order: 2,
        isDefault: false,
        isArchived: false,
      );

      final map = config.toFirestore();
      expect(map['displayName'], 'Test Category');
      expect(map['prompt'], 'What happened?');
      expect(map['iconCodePoint'], 0xe047);
      expect(map['iconFontFamily'], 'MaterialIcons');
      expect(map['colorValue'], 0xFFFF0000);
      expect(map['order'], 2);
      expect(map['isDefault'], false);
      expect(map['isArchived'], false);
      // id is NOT in the map (it's the document ID)
      expect(map.containsKey('id'), false);
    });

    test('fromFirestore round-trip preserves all fields', () {
      const original = CategoryConfig(
        id: 'my_cat',
        displayName: 'My Category',
        prompt: 'Tell me more',
        iconCodePoint: 0xe047,
        iconFontFamily: 'MaterialIcons',
        colorValue: 0xFF00FF00,
        order: 3,
        isDefault: true,
        isArchived: true,
      );

      final restored =
          CategoryConfig.fromFirestore(original.id, original.toFirestore());
      expect(restored, original);
    });

    test('fromFirestore handles missing data with defaults', () {
      final config = CategoryConfig.fromFirestore('unknown', {});

      expect(config.id, 'unknown');
      expect(config.displayName, 'unknown'); // falls back to id
      expect(config.prompt, '');
      expect(config.iconFontFamily, 'MaterialIcons');
      expect(config.order, 0);
      expect(config.isDefault, false);
      expect(config.isArchived, false);
    });

    test('defaults returns 5 categories', () {
      final defaults = CategoryConfig.defaults;
      expect(defaults.length, 5);
    });

    test('defaults have unique ids', () {
      final defaults = CategoryConfig.defaults;
      final ids = defaults.map((c) => c.id).toSet();
      expect(ids.length, 5);
    });

    test('defaults have unique colors', () {
      final defaults = CategoryConfig.defaults;
      final colors = defaults.map((c) => c.colorValue).toSet();
      expect(colors.length, 5);
    });

    test('defaults have unique icons', () {
      final defaults = CategoryConfig.defaults;
      final icons = defaults.map((c) => c.iconCodePoint).toSet();
      expect(icons.length, 5);
    });

    test('defaults have sequential order 0-4', () {
      final defaults = CategoryConfig.defaults;
      for (var i = 0; i < defaults.length; i++) {
        expect(defaults[i].order, i);
      }
    });

    test('defaults are all marked isDefault', () {
      for (final config in CategoryConfig.defaults) {
        expect(config.isDefault, true);
      }
    });

    test('icon getter returns correct IconData', () {
      const config = CategoryConfig(
        id: 'test',
        displayName: 'Test',
        prompt: '',
        iconCodePoint: 0xe047,
        iconFontFamily: 'MaterialIcons',
        colorValue: 0xFFFF0000,
        order: 0,
      );

      expect(config.icon, isA<IconData>());
      expect(config.icon.codePoint, 0xe047);
      expect(config.icon.fontFamily, 'MaterialIcons');
    });

    test('color getter returns correct Color', () {
      const config = CategoryConfig(
        id: 'test',
        displayName: 'Test',
        prompt: '',
        iconCodePoint: 0xe047,
        colorValue: 0xFFFF0000,
        order: 0,
      );

      expect(config.color, const Color(0xFFFF0000));
    });

    test('copyWith preserves unchanged fields', () {
      const original = CategoryConfig(
        id: 'test',
        displayName: 'Original',
        prompt: 'Original prompt',
        iconCodePoint: 0xe047,
        colorValue: 0xFFFF0000,
        order: 0,
        isDefault: true,
      );

      final updated = original.copyWith(displayName: 'Updated');
      expect(updated.id, 'test'); // id never changes
      expect(updated.displayName, 'Updated');
      expect(updated.prompt, 'Original prompt');
      expect(updated.iconCodePoint, 0xe047);
      expect(updated.colorValue, 0xFFFF0000);
      expect(updated.order, 0);
      expect(updated.isDefault, true);
    });

    test('equatable works correctly', () {
      const a = CategoryConfig(
        id: 'test',
        displayName: 'Test',
        prompt: '',
        iconCodePoint: 0xe047,
        colorValue: 0xFFFF0000,
        order: 0,
      );
      const b = CategoryConfig(
        id: 'test',
        displayName: 'Test',
        prompt: '',
        iconCodePoint: 0xe047,
        colorValue: 0xFFFF0000,
        order: 0,
      );
      const c = CategoryConfig(
        id: 'other',
        displayName: 'Test',
        prompt: '',
        iconCodePoint: 0xe047,
        colorValue: 0xFFFF0000,
        order: 0,
      );

      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
