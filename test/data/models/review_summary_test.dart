import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/review_summary.dart';

void main() {
  group('ReviewSummary', () {
    test('toFirestore produces expected map', () {
      final now = DateTime(2026, 3, 18, 10, 0);
      final summary = ReviewSummary(
        id: 'test-id',
        categoryId: 'positive',
        weekStart: '2026-03-16',
        summary: 'Great week for positivity!',
        createdAt: now,
        updatedAt: now,
      );

      final map = summary.toFirestore();

      expect(map['categoryId'], 'positive');
      expect(map['weekStart'], '2026-03-16');
      expect(map['summary'], 'Great week for positivity!');
      expect(map['createdAt'], Timestamp.fromDate(now));
      expect(map['updatedAt'], Timestamp.fromDate(now));
      expect(map.containsKey('audioUrl'), false);
    });

    test('toFirestore includes audioUrl when present', () {
      final now = DateTime(2026, 3, 18);
      final summary = ReviewSummary(
        id: 'id',
        categoryId: 'gratitude',
        weekStart: '2026-03-16',
        summary: 'Summary text',
        audioUrl: 'gs://bucket/review.wav',
        createdAt: now,
        updatedAt: now,
      );

      final map = summary.toFirestore();
      expect(map['audioUrl'], 'gs://bucket/review.wav');
    });

    test('fromFirestore round-trip preserves data', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime(2026, 3, 18, 10, 0);
      final original = ReviewSummary(
        id: '',
        categoryId: 'beauty',
        weekStart: '2026-03-16',
        summary: 'Beauty all around',
        audioUrl: 'gs://bucket/audio.wav',
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await firestore
          .collection('test')
          .add(original.toFirestore());
      final snapshot = await docRef.get();
      final restored = ReviewSummary.fromFirestore(snapshot);

      expect(restored.id, docRef.id);
      expect(restored.categoryId, 'beauty');
      expect(restored.weekStart, '2026-03-16');
      expect(restored.summary, 'Beauty all around');
      expect(restored.audioUrl, 'gs://bucket/audio.wav');
      expect(restored.createdAt, now);
      expect(restored.updatedAt, now);
    });

    test('fromFirestore handles missing optional fields', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime(2026, 3, 18);
      await firestore.collection('test').doc('minimal').set({
        'categoryId': 'identity',
        'weekStart': '2026-03-16',
        'summary': 'Identity review',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final snapshot = await firestore.collection('test').doc('minimal').get();
      final summary = ReviewSummary.fromFirestore(snapshot);

      expect(summary.audioUrl, isNull);
    });

    test('fromFirestore logs warning when timestamps are missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('test').doc('no-ts').set({
        'categoryId': 'positive',
        'weekStart': '2026-03-16',
        'summary': 'Missing timestamps',
      });

      final logs = <String>[];
      final snapshot = await firestore.collection('test').doc('no-ts').get();
      final summary = ReviewSummary.fromFirestore(
        snapshot,
        onWarning: logs.add,
      );

      expect(summary.categoryId, 'positive');
      expect(summary.createdAt, isNotNull);
      expect(summary.updatedAt, isNotNull);
      expect(logs, contains(contains('createdAt')));
      expect(logs, contains(contains('updatedAt')));
    });

    test('fromFirestore does not warn when timestamps are present', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime(2026, 3, 18);
      await firestore.collection('test').doc('with-ts').set({
        'categoryId': 'positive',
        'weekStart': '2026-03-16',
        'summary': 'Has timestamps',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final logs = <String>[];
      final snapshot = await firestore.collection('test').doc('with-ts').get();
      ReviewSummary.fromFirestore(snapshot, onWarning: logs.add);

      expect(logs, isEmpty);
    });

    test('equatable compares all fields', () {
      final now = DateTime(2026, 3, 18);
      final a = ReviewSummary(
        id: '1',
        categoryId: 'positive',
        weekStart: '2026-03-16',
        summary: 'text',
        createdAt: now,
        updatedAt: now,
      );
      final b = ReviewSummary(
        id: '1',
        categoryId: 'positive',
        weekStart: '2026-03-16',
        summary: 'text',
        createdAt: now,
        updatedAt: now,
      );
      final c = ReviewSummary(
        id: '1',
        categoryId: 'negative',
        weekStart: '2026-03-16',
        summary: 'text',
        createdAt: now,
        updatedAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
