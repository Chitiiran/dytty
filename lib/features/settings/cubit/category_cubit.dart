import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/data/repositories/category_repository.dart';

// --- State ---

class CategoryState extends Equatable {
  final List<CategoryConfig> categories;
  final bool loaded;

  const CategoryState({
    this.categories = const [],
    this.loaded = false,
  });

  /// Active (non-archived) categories, sorted by order.
  List<CategoryConfig> get activeCategories =>
      categories.where((c) => !c.isArchived).toList();

  /// Find a category by id, or null if not found.
  CategoryConfig? findById(String id) {
    final matches = categories.where((c) => c.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  CategoryState copyWith({
    List<CategoryConfig>? categories,
    bool? loaded,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  List<Object?> get props => [categories, loaded];
}

// --- Cubit ---

class CategoryCubit extends Cubit<CategoryState> {
  final CategoryRepository _repository;

  CategoryCubit({required CategoryRepository repository})
      : _repository = repository,
        super(const CategoryState());

  Future<void> loadCategories() async {
    // Emit defaults immediately so the UI is never empty
    emit(state.copyWith(categories: CategoryConfig.defaults, loaded: true));
    try {
      await _repository.seedDefaults();
      final categories = await _repository.getCategories();
      if (categories.isNotEmpty) {
        emit(state.copyWith(categories: categories));
      }
    } catch (_) {
      // Firestore unavailable — defaults already loaded
    }
  }

  Future<void> addCategory(CategoryConfig config) async {
    await _repository.saveCategory(config);
    final categories = await _repository.getCategories();
    emit(state.copyWith(categories: categories));
  }

  Future<void> updateCategory(CategoryConfig config) async {
    await _repository.saveCategory(config);
    final categories = await _repository.getCategories();
    emit(state.copyWith(categories: categories));
  }

  Future<void> archiveCategory(String id) async {
    await _repository.archiveCategory(id);
    final categories = await _repository.getCategories();
    emit(state.copyWith(categories: categories));
  }

  Future<void> restoreCategory(String id) async {
    await _repository.restoreCategory(id);
    final categories = await _repository.getCategories();
    emit(state.copyWith(categories: categories));
  }

  Future<void> reorder(List<CategoryConfig> ordered) async {
    await _repository.reorderCategories(ordered);
    final categories = await _repository.getCategories();
    emit(state.copyWith(categories: categories));
  }
}
