import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/repositories/category_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late CategoryRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = CategoryRepository(uid: 'test-user', firestore: fakeFirestore);
  });

  group('CategoryRepository', () {
    test('seedDefaults writes 5 categories when collection is empty', () async {
      final seeded = await repository.seedDefaults();
      expect(seeded, true);

      final categories = await repository.getCategories();
      expect(categories.length, 5);
      expect(categories[0].id, 'positive');
      expect(categories[1].id, 'negative');
      expect(categories[2].id, 'gratitude');
      expect(categories[3].id, 'beauty');
      expect(categories[4].id, 'identity');
    });

    test('seedDefaults returns false when categories already exist', () async {
      await repository.seedDefaults();
      final seeded = await repository.seedDefaults();
      expect(seeded, false);
    });

    test('getCategories returns sorted by order', () async {
      await repository.seedDefaults();
      final categories = await repository.getCategories();

      for (var i = 0; i < categories.length - 1; i++) {
        expect(categories[i].order, lessThan(categories[i + 1].order));
      }
    });

    test('saveCategory upserts correctly', () async {
      const config = CategoryConfig(
        id: 'custom_1',
        displayName: 'Custom Category',
        prompt: 'What custom thing?',
        iconCodePoint: 0xe047,
        colorValue: 0xFFFF0000,
        order: 5,
      );

      await repository.saveCategory(config);
      final categories = await repository.getCategories();
      final found = categories.firstWhere((c) => c.id == 'custom_1');
      expect(found.displayName, 'Custom Category');

      // Update it
      await repository.saveCategory(config.copyWith(displayName: 'Updated'));
      final updated = await repository.getCategories();
      final updatedCat = updated.firstWhere((c) => c.id == 'custom_1');
      expect(updatedCat.displayName, 'Updated');
    });

    test('archiveCategory sets isArchived to true', () async {
      await repository.seedDefaults();
      await repository.archiveCategory('positive');

      final categories = await repository.getCategories();
      final positive = categories.firstWhere((c) => c.id == 'positive');
      expect(positive.isArchived, true);
    });

    test('restoreCategory sets isArchived to false', () async {
      await repository.seedDefaults();
      await repository.archiveCategory('positive');
      await repository.restoreCategory('positive');

      final categories = await repository.getCategories();
      final positive = categories.firstWhere((c) => c.id == 'positive');
      expect(positive.isArchived, false);
    });

    test('reorderCategories updates order fields', () async {
      await repository.seedDefaults();
      var categories = await repository.getCategories();

      // Reverse the order
      final reversed = categories.reversed.toList();
      await repository.reorderCategories(reversed);

      categories = await repository.getCategories();
      // After reorder, 'identity' should be first (order 0)
      expect(categories[0].id, 'identity');
      expect(categories[0].order, 0);
      expect(categories[4].id, 'positive');
      expect(categories[4].order, 4);
    });

    test('getCategories returns empty list when no categories exist', () async {
      final categories = await repository.getCategories();
      expect(categories, isEmpty);
    });

    test('saved category preserves all fields', () async {
      const config = CategoryConfig(
        id: 'full_test',
        displayName: 'Full Test',
        prompt: 'Test prompt',
        iconCodePoint: 0xe047,
        iconFontFamily: 'MaterialIcons',
        colorValue: 0xFF00FF00,
        order: 10,
        isDefault: true,
        isArchived: true,
      );

      await repository.saveCategory(config);
      final categories = await repository.getCategories();
      final found = categories.firstWhere((c) => c.id == 'full_test');

      expect(found.displayName, 'Full Test');
      expect(found.prompt, 'Test prompt');
      expect(found.iconCodePoint, 0xe047);
      expect(found.iconFontFamily, 'MaterialIcons');
      expect(found.colorValue, 0xFF00FF00);
      expect(found.order, 10);
      expect(found.isDefault, true);
      expect(found.isArchived, true);
    });
  });
}
