import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/daily_entry.dart';

class JournalRepository {
  final FirebaseFirestore _firestore;
  final String _uid;

  JournalRepository({required String uid, FirebaseFirestore? firestore})
    : _uid = uid,
      _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _dailyEntriesCollection =>
      _firestore.collection('users').doc(_uid).collection('dailyEntries');

  DocumentReference _dailyEntryDoc(String date) =>
      _dailyEntriesCollection.doc(date);

  CollectionReference _categoryEntries(String date) =>
      _dailyEntryDoc(date).collection('categoryEntries');

  /// Creates the daily entry doc if it doesn't exist, returns it.
  Future<DailyEntry> getOrCreateDailyEntry(String date) async {
    final doc = _dailyEntryDoc(date);
    final snapshot = await doc.get();

    if (snapshot.exists) {
      return DailyEntry.fromFirestore(snapshot);
    }

    final now = DateTime.now();
    final entry = DailyEntry(date: date, createdAt: now, updatedAt: now);
    await doc.set(entry.toFirestore());
    return entry;
  }

  /// Gets all category entries for a given date.
  Future<List<CategoryEntry>> getCategoryEntries(String date) async {
    final snapshot = await _categoryEntries(
      date,
    ).orderBy('createdAt', descending: false).get();

    return snapshot.docs
        .map((doc) => CategoryEntry.fromFirestore(doc))
        .toList();
  }

  /// Adds a new category entry.
  Future<CategoryEntry> addCategoryEntry(
    String date,
    JournalCategory category,
    String text,
  ) async {
    await getOrCreateDailyEntry(date);

    final now = DateTime.now();
    final entry = CategoryEntry(
      id: '',
      category: category,
      text: text,
      createdAt: now,
    );

    final docRef = await _categoryEntries(date).add(entry.toFirestore());

    // Update the daily entry's updatedAt
    await _dailyEntryDoc(date).update({'updatedAt': Timestamp.fromDate(now)});

    return CategoryEntry(
      id: docRef.id,
      category: category,
      text: text,
      createdAt: now,
    );
  }

  /// Updates an existing category entry's text.
  Future<void> updateCategoryEntry(
    String date,
    String entryId,
    String text,
  ) async {
    final now = DateTime.now();
    await _categoryEntries(date).doc(entryId).update({'text': text});
    await _dailyEntryDoc(date).update({'updatedAt': Timestamp.fromDate(now)});
  }

  /// Deletes a category entry.
  Future<void> deleteCategoryEntry(String date, String entryId) async {
    await _categoryEntries(date).doc(entryId).delete();

    final remaining = await _categoryEntries(date).limit(1).get();
    if (remaining.docs.isEmpty) {
      await _dailyEntryDoc(date).delete();
    } else {
      await _dailyEntryDoc(
        date,
      ).update({'updatedAt': Timestamp.fromDate(DateTime.now())});
    }
  }

  /// Gets dates that have entries for a given year/month.
  Future<Set<String>> getDaysWithEntries(int year, int month) async {
    final startDate =
        '${year.toString()}-${month.toString().padLeft(2, '0')}-01';
    final endMonth = month == 12 ? 1 : month + 1;
    final endYear = month == 12 ? year + 1 : year;
    final endDate =
        '${endYear.toString()}-${endMonth.toString().padLeft(2, '0')}-01';

    final snapshot = await _dailyEntriesCollection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDate)
        .where(FieldPath.documentId, isLessThan: endDate)
        .get();

    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  /// Ensures user profile exists in Firestore.
  Future<void> ensureUserProfile(String displayName, String email) async {
    final profileDoc = _firestore.collection('users').doc(_uid);
    final snapshot = await profileDoc.get();

    if (!snapshot.exists) {
      await profileDoc.set({
        'displayName': displayName,
        'email': email,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }
}
