import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';

void main() {
  group('CategoryEntry', () {
    test('toFirestore produces expected map', () {
      final now = DateTime(2026, 2, 27, 10, 30);
      final entry = CategoryEntry(
        id: 'test-id',
        category: JournalCategory.gratitude,
        text: 'Grateful for sunshine',
        source: 'manual',
        createdAt: now,
      );

      final map = entry.toFirestore();

      expect(map['category'], 'gratitude');
      expect(map['text'], 'Grateful for sunshine');
      expect(map['source'], 'manual');
      expect(map['createdAt'], Timestamp.fromDate(now));
    });

    test('fromFirestore round-trip preserves data', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime(2026, 2, 27, 10, 30);
      final original = CategoryEntry(
        id: '',
        category: JournalCategory.beauty,
        text: 'A beautiful sunset',
        source: 'manual',
        createdAt: now,
      );

      final docRef = await firestore
          .collection('test')
          .add(original.toFirestore());
      final snapshot = await docRef.get();
      final restored = CategoryEntry.fromFirestore(snapshot);

      expect(restored.id, docRef.id);
      expect(restored.category, JournalCategory.beauty);
      expect(restored.text, 'A beautiful sunset');
      expect(restored.source, 'manual');
      expect(restored.createdAt, now);
    });

    test('fromFirestore handles missing text field', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('test').doc('missing').set({
        'category': 'positive',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      final snapshot = await firestore.collection('test').doc('missing').get();
      final entry = CategoryEntry.fromFirestore(snapshot);

      expect(entry.text, '');
      expect(entry.source, 'manual');
    });

    test('fromFirestore handles unknown category', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('test').doc('unknown').set({
        'category': 'nonexistent',
        'text': 'test',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      final snapshot = await firestore.collection('test').doc('unknown').get();
      final entry = CategoryEntry.fromFirestore(snapshot);

      // Falls back to positive
      expect(entry.category, JournalCategory.positive);
    });

    test('toFirestore omits audioUrl/transcript/tags when null or empty', () {
      final entry = CategoryEntry(
        id: 'id',
        category: JournalCategory.positive,
        text: 'hello',
        createdAt: DateTime(2026, 3, 1),
      );

      final map = entry.toFirestore();

      expect(map.containsKey('audioUrl'), false);
      expect(map.containsKey('transcript'), false);
      expect(map.containsKey('tags'), false);
    });

    test('toFirestore includes audioUrl/transcript/tags when present', () {
      final entry = CategoryEntry(
        id: 'id',
        category: JournalCategory.gratitude,
        text: 'voice note',
        createdAt: DateTime(2026, 3, 1),
        audioUrl: 'gs://bucket/audio.wav',
        transcript: 'I am grateful for...',
        tags: ['gratitude', 'morning'],
      );

      final map = entry.toFirestore();

      expect(map['audioUrl'], 'gs://bucket/audio.wav');
      expect(map['transcript'], 'I am grateful for...');
      expect(map['tags'], ['gratitude', 'morning']);
    });

    test('fromFirestore round-trip preserves new fields', () async {
      final firestore = FakeFirebaseFirestore();
      final entry = CategoryEntry(
        id: '',
        category: JournalCategory.beauty,
        text: 'voice entry',
        createdAt: DateTime(2026, 3, 1),
        audioUrl: 'gs://bucket/file.mp3',
        transcript: 'A beautiful day',
        tags: ['beauty', 'nature'],
      );

      final docRef = await firestore
          .collection('test')
          .add(entry.toFirestore());
      final snapshot = await docRef.get();
      final restored = CategoryEntry.fromFirestore(snapshot);

      expect(restored.audioUrl, 'gs://bucket/file.mp3');
      expect(restored.transcript, 'A beautiful day');
      expect(restored.tags, ['beauty', 'nature']);
    });

    test('fromFirestore handles legacy data without new fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('test').doc('legacy').set({
        'category': 'positive',
        'text': 'old entry',
        'source': 'manual',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      final snapshot = await firestore.collection('test').doc('legacy').get();
      final entry = CategoryEntry.fromFirestore(snapshot);

      expect(entry.audioUrl, isNull);
      expect(entry.transcript, isNull);
      expect(entry.tags, isEmpty);
    });
  });
}
