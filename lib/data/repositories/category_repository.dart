import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dytty/data/models/category_config.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore;
  final String _uid;

  CategoryRepository({required String uid, FirebaseFirestore? firestore})
      : _uid = uid,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _categoriesCollection =>
      _firestore.collection('users').doc(_uid).collection('categories');

  Future<List<CategoryConfig>> getCategories() async {
    final snapshot = await _categoriesCollection.orderBy('order').get();
    return snapshot.docs.map((doc) {
      return CategoryConfig.fromFirestore(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
    }).toList();
  }

  Future<void> saveCategory(CategoryConfig config) async {
    await _categoriesCollection.doc(config.id).set(config.toFirestore());
  }

  Future<void> archiveCategory(String categoryId) async {
    await _categoriesCollection.doc(categoryId).update({'isArchived': true});
  }

  Future<void> restoreCategory(String categoryId) async {
    await _categoriesCollection.doc(categoryId).update({'isArchived': false});
  }

  Future<void> reorderCategories(List<CategoryConfig> ordered) async {
    final batch = _firestore.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_categoriesCollection.doc(ordered[i].id), {'order': i});
    }
    await batch.commit();
  }

  /// Seeds the default categories if the collection is empty.
  /// Returns true if defaults were seeded.
  Future<bool> seedDefaults() async {
    final snapshot = await _categoriesCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return false;

    final batch = _firestore.batch();
    for (final config in CategoryConfig.defaults) {
      batch.set(_categoriesCollection.doc(config.id), config.toFirestore());
    }
    await batch.commit();
    return true;
  }
}
