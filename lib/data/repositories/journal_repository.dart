import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/daily_entry.dart';
import 'package:dytty/data/models/review_summary.dart';

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
    String categoryId,
    String text, {
    String source = 'manual',
    String? transcript,
    List<String> tags = const [],
  }) async {
    await getOrCreateDailyEntry(date);

    final now = DateTime.now();
    final entry = CategoryEntry(
      id: '',
      categoryId: categoryId,
      text: text,
      source: source,
      createdAt: now,
      transcript: transcript,
      tags: tags,
    );

    final docRef = await _categoryEntries(date).add(entry.toFirestore());

    // Update the daily entry's updatedAt
    await _dailyEntryDoc(date).update({'updatedAt': Timestamp.fromDate(now)});

    return CategoryEntry(
      id: docRef.id,
      categoryId: categoryId,
      text: text,
      source: source,
      createdAt: now,
      transcript: transcript,
      tags: tags,
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

  CollectionReference get _reviewSummariesCollection =>
      _firestore.collection('users').doc(_uid).collection('reviewSummaries');

  /// Gets category entries for a specific category across multiple dates.
  /// Returns a map keyed by date string, with a list of entries per date.
  Future<Map<String, List<CategoryEntry>>> getCategoryEntriesForDateRange(
    String categoryId,
    List<String> dates,
  ) async {
    final result = <String, List<CategoryEntry>>{};

    for (final date in dates) {
      final snapshot = await _categoryEntries(date)
          .where('category', isEqualTo: categoryId)
          .orderBy('createdAt', descending: false)
          .get();

      result[date] = snapshot.docs
          .map((doc) => CategoryEntry.fromFirestore(doc))
          .toList();
    }

    return result;
  }

  /// Marks a category entry as reviewed.
  Future<void> markEntryReviewed(String date, String entryId) async {
    await _categoryEntries(date).doc(entryId).update({'isReviewed': true});
  }

  /// Saves or updates a review summary.
  /// Upserts by categoryId + weekStart — updates if exists, creates if not.
  Future<void> saveReviewSummary(ReviewSummary summary) async {
    final existing = await _reviewSummariesCollection
        .where('categoryId', isEqualTo: summary.categoryId)
        .where('weekStart', isEqualTo: summary.weekStart)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(summary.toFirestore());
    } else {
      await _reviewSummariesCollection.add(summary.toFirestore());
    }
  }

  /// Gets the review summary for a category and week.
  Future<ReviewSummary?> getReviewSummary(
    String categoryId,
    String weekStart,
  ) async {
    final snapshot = await _reviewSummariesCollection
        .where('categoryId', isEqualTo: categoryId)
        .where('weekStart', isEqualTo: weekStart)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ReviewSummary.fromFirestore(snapshot.docs.first);
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

  /// Computes streak data by walking dailyEntries backward from today.
  /// Returns {currentStreak, longestStreak, lastJournalDate}.
  Future<StreakData> getStreakData() async {
    final snapshot = await _dailyEntriesCollection
        .orderBy(FieldPath.documentId, descending: true)
        .get();

    final dates = snapshot.docs.map((doc) => doc.id).toSet();
    if (dates.isEmpty) {
      return const StreakData(
        currentStreak: 0,
        longestStreak: 0,
        lastJournalDate: null,
      );
    }

    final sortedDates = dates.toList()..sort((a, b) => b.compareTo(a));
    final lastJournalDate = sortedDates.first;

    // Walk backward from today counting consecutive days
    var current = DateTime.now();
    var currentDateStr =
        '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';

    int currentStreak = 0;
    // Allow streak to start from today or yesterday
    if (!dates.contains(currentDateStr)) {
      final yesterday = current.subtract(const Duration(days: 1));
      currentDateStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      if (!dates.contains(currentDateStr)) {
        // No entry today or yesterday — streak is 0
        return StreakData(
          currentStreak: 0,
          longestStreak: _computeLongestStreak(sortedDates),
          lastJournalDate: lastJournalDate,
        );
      }
      current = yesterday;
    }

    // Count consecutive days backward
    while (true) {
      final dateStr =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      if (dates.contains(dateStr)) {
        currentStreak++;
        current = current.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    final longestStreak = _computeLongestStreak(sortedDates);

    return StreakData(
      currentStreak: currentStreak,
      longestStreak: longestStreak > currentStreak
          ? longestStreak
          : currentStreak,
      lastJournalDate: lastJournalDate,
    );
  }

  int _computeLongestStreak(List<String> sortedDatesDesc) {
    if (sortedDatesDesc.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < sortedDatesDesc.length; i++) {
      final prev = DateTime.parse(sortedDatesDesc[i - 1]);
      final curr = DateTime.parse(sortedDatesDesc[i]);
      final diff = prev.difference(curr).inDays;

      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }

    return longest;
  }

  /// Gets user settings from profile doc.
  Future<Map<String, dynamic>> getUserSettings() async {
    final profileDoc = _firestore.collection('users').doc(_uid);
    final snapshot = await profileDoc.get();

    if (!snapshot.exists) {
      return {'hideEntries': false};
    }
    final data = snapshot.data() ?? {};
    return {'hideEntries': data['hideEntries'] ?? false};
  }

  /// Updates user settings in profile doc.
  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    final profileDoc = _firestore.collection('users').doc(_uid);
    await profileDoc.set(settings, SetOptions(merge: true));
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

/// Data class for streak information.
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final String? lastJournalDate;

  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastJournalDate,
  });
}
