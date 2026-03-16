import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/repositories/category_repository.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  group('CategoryState', () {
    test('initial state has empty categories and loaded false', () {
      const state = CategoryState();
      expect(state.categories, isEmpty);
      expect(state.loaded, false);
    });

    test('activeCategories filters out archived categories', () {
      final state = CategoryState(
        categories: [
          CategoryConfig.defaults[0],
          CategoryConfig.defaults[1].copyWith(isArchived: true),
          CategoryConfig.defaults[2],
        ],
        loaded: true,
      );

      expect(state.activeCategories.length, 2);
      expect(state.activeCategories.every((c) => !c.isArchived), true);
    });

    test('activeCategories returns all when none archived', () {
      final state = CategoryState(
        categories: CategoryConfig.defaults,
        loaded: true,
      );
      expect(state.activeCategories.length, 5);
    });

    test('activeCategories returns empty when all archived', () {
      final state = CategoryState(
        categories: CategoryConfig.defaults
            .map((c) => c.copyWith(isArchived: true))
            .toList(),
        loaded: true,
      );
      expect(state.activeCategories, isEmpty);
    });

    test('findById returns matching category', () {
      final state = CategoryState(
        categories: CategoryConfig.defaults,
        loaded: true,
      );
      final found = state.findById('gratitude');
      expect(found, isNotNull);
      expect(found!.id, 'gratitude');
      expect(found.displayName, 'Gratitude');
    });

    test('findById returns null for unknown id', () {
      final state = CategoryState(
        categories: CategoryConfig.defaults,
        loaded: true,
      );
      expect(state.findById('nonexistent'), isNull);
    });

    test('findById returns null on empty categories', () {
      const state = CategoryState();
      expect(state.findById('positive'), isNull);
    });

    test('copyWith preserves values when no args given', () {
      final state = CategoryState(
        categories: CategoryConfig.defaults,
        loaded: true,
      );
      final copy = state.copyWith();
      expect(copy, equals(state));
    });

    test('equality works via Equatable', () {
      final a = CategoryState(
        categories: CategoryConfig.defaults,
        loaded: true,
      );
      final b = CategoryState(
        categories: CategoryConfig.defaults,
        loaded: true,
      );
      expect(a, equals(b));
    });
  });

  group('CategoryCubit (with real repository)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late CategoryRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = CategoryRepository(
        uid: 'test-user',
        firestore: fakeFirestore,
      );
    });

    test('initial state is empty and not loaded', () {
      final cubit = CategoryCubit(repository: repository);
      expect(cubit.state.categories, isEmpty);
      expect(cubit.state.loaded, false);
    });

    blocTest<CategoryCubit, CategoryState>(
      'loadCategories emits defaults when collection is empty',
      build: () => CategoryCubit(repository: repository),
      act: (cubit) => cubit.loadCategories(),
      expect: () => [
        // Defaults emitted immediately; second emit from Firestore is
        // identical (Equatable dedup), so only one state change observed.
        isA<CategoryState>()
            .having((s) => s.loaded, 'loaded', true)
            .having((s) => s.categories.length, 'count', 5)
            .having((s) => s.categories[0].id, 'first id', 'positive'),
      ],
      verify: (cubit) {
        // Confirm all 5 defaults present with correct order
        final ids = cubit.state.categories.map((c) => c.id).toList();
        expect(ids, [
          'positive',
          'negative',
          'gratitude',
          'beauty',
          'identity',
        ]);
      },
    );

    blocTest<CategoryCubit, CategoryState>(
      'loadCategories emits seeded data when categories already exist',
      setUp: () async {
        // Pre-seed a custom category set
        await repository.saveCategory(
          const CategoryConfig(
            id: 'custom_1',
            displayName: 'Custom',
            prompt: 'Custom prompt',
            iconCodePoint: 0xe047,
            colorValue: 0xFFFF0000,
            order: 0,
          ),
        );
      },
      build: () => CategoryCubit(repository: repository),
      act: (cubit) => cubit.loadCategories(),
      expect: () => [
        // First emit: defaults
        isA<CategoryState>()
            .having((s) => s.loaded, 'loaded', true)
            .having((s) => s.categories.length, 'count', 5),
        // Second emit: actual data from Firestore (seedDefaults skipped
        // because collection not empty, getCategories returns the 1 custom)
        isA<CategoryState>()
            .having((s) => s.categories.length, 'count', 1)
            .having((s) => s.categories[0].id, 'id', 'custom_1'),
      ],
    );

    blocTest<CategoryCubit, CategoryState>(
      'addCategory saves and refreshes state',
      setUp: () async {
        await repository.seedDefaults();
      },
      build: () => CategoryCubit(repository: repository),
      seed: () =>
          CategoryState(categories: CategoryConfig.defaults, loaded: true),
      act: (cubit) => cubit.addCategory(
        const CategoryConfig(
          id: 'custom_1',
          displayName: 'Custom',
          prompt: 'Custom prompt',
          iconCodePoint: 0xe047,
          colorValue: 0xFFFF0000,
          order: 5,
        ),
      ),
      expect: () => [
        isA<CategoryState>()
            .having((s) => s.categories.length, 'count', 6)
            .having(
              (s) => s.categories.any((c) => c.id == 'custom_1'),
              'has custom',
              true,
            ),
      ],
    );

    blocTest<CategoryCubit, CategoryState>(
      'updateCategory persists changes and refreshes state',
      setUp: () async {
        await repository.seedDefaults();
      },
      build: () => CategoryCubit(repository: repository),
      seed: () =>
          CategoryState(categories: CategoryConfig.defaults, loaded: true),
      act: (cubit) => cubit.updateCategory(
        CategoryConfig.defaults[0].copyWith(displayName: 'Sunshine'),
      ),
      expect: () => [
        isA<CategoryState>().having(
          (s) => s.categories.firstWhere((c) => c.id == 'positive').displayName,
          'updated name',
          'Sunshine',
        ),
      ],
    );

    blocTest<CategoryCubit, CategoryState>(
      'archiveCategory marks category as archived',
      setUp: () async {
        await repository.seedDefaults();
      },
      build: () => CategoryCubit(repository: repository),
      seed: () =>
          CategoryState(categories: CategoryConfig.defaults, loaded: true),
      act: (cubit) => cubit.archiveCategory('positive'),
      expect: () => [
        isA<CategoryState>()
            .having(
              (s) =>
                  s.categories.firstWhere((c) => c.id == 'positive').isArchived,
              'isArchived',
              true,
            )
            .having((s) => s.activeCategories.length, 'active count', 4),
      ],
    );

    blocTest<CategoryCubit, CategoryState>(
      'restoreCategory un-archives a category',
      setUp: () async {
        await repository.seedDefaults();
        await repository.archiveCategory('positive');
      },
      build: () => CategoryCubit(repository: repository),
      seed: () => CategoryState(
        categories: CategoryConfig.defaults
            .map((c) => c.id == 'positive' ? c.copyWith(isArchived: true) : c)
            .toList(),
        loaded: true,
      ),
      act: (cubit) => cubit.restoreCategory('positive'),
      expect: () => [
        isA<CategoryState>()
            .having(
              (s) =>
                  s.categories.firstWhere((c) => c.id == 'positive').isArchived,
              'isArchived',
              false,
            )
            .having((s) => s.activeCategories.length, 'active count', 5),
      ],
    );

    blocTest<CategoryCubit, CategoryState>(
      'reorder updates the order of categories',
      setUp: () async {
        await repository.seedDefaults();
      },
      build: () => CategoryCubit(repository: repository),
      seed: () =>
          CategoryState(categories: CategoryConfig.defaults, loaded: true),
      act: (cubit) {
        final reversed = CategoryConfig.defaults.reversed.toList();
        return cubit.reorder(reversed);
      },
      expect: () => [
        isA<CategoryState>()
            .having(
              (s) => s.categories[0].id,
              'first after reorder',
              'identity',
            )
            .having(
              (s) => s.categories[4].id,
              'last after reorder',
              'positive',
            ),
      ],
    );
  });

  group('CategoryCubit (error handling with mock)', () {
    late MockCategoryRepository mockRepository;

    setUp(() {
      mockRepository = MockCategoryRepository();
    });

    blocTest<CategoryCubit, CategoryState>(
      'loadCategories emits defaults when repository throws',
      setUp: () {
        when(
          () => mockRepository.seedDefaults(),
        ).thenThrow(Exception('Firestore unavailable'));
      },
      build: () => CategoryCubit(repository: mockRepository),
      act: (cubit) => cubit.loadCategories(),
      expect: () => [
        // Should still emit defaults despite the error
        isA<CategoryState>()
            .having((s) => s.loaded, 'loaded', true)
            .having((s) => s.categories.length, 'count', 5)
            .having((s) => s.categories[0].id, 'first', 'positive'),
      ],
    );

    blocTest<CategoryCubit, CategoryState>(
      'loadCategories emits defaults when getCategories throws after seed',
      setUp: () {
        when(() => mockRepository.seedDefaults()).thenAnswer((_) async => true);
        when(
          () => mockRepository.getCategories(),
        ).thenThrow(Exception('Network error'));
      },
      build: () => CategoryCubit(repository: mockRepository),
      act: (cubit) => cubit.loadCategories(),
      expect: () => [
        // Defaults emitted, getCategories failure caught silently
        isA<CategoryState>()
            .having((s) => s.loaded, 'loaded', true)
            .having((s) => s.categories.length, 'count', 5),
      ],
    );

    blocTest<CategoryCubit, CategoryState>(
      'loadCategories emits defaults when getCategories returns empty',
      setUp: () {
        when(() => mockRepository.seedDefaults()).thenAnswer((_) async => true);
        when(() => mockRepository.getCategories()).thenAnswer((_) async => []);
      },
      build: () => CategoryCubit(repository: mockRepository),
      act: (cubit) => cubit.loadCategories(),
      expect: () => [
        // Defaults emitted; empty getCategories does not overwrite
        isA<CategoryState>()
            .having((s) => s.loaded, 'loaded', true)
            .having((s) => s.categories.length, 'count', 5),
      ],
    );
  });
}
