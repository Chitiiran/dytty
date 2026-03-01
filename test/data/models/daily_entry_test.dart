import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/data/models/daily_entry.dart';

void main() {
  group('DailyEntry', () {
    test('toFirestore produces expected map', () {
      final created = DateTime(2026, 2, 27, 8, 0);
      final updated = DateTime(2026, 2, 27, 10, 30);
      final entry = DailyEntry(
        date: '2026-02-27',
        createdAt: created,
        updatedAt: updated,
      );

      final map = entry.toFirestore();

      expect(map['createdAt'], Timestamp.fromDate(created));
      expect(map['updatedAt'], Timestamp.fromDate(updated));
    });

    test('fromFirestore round-trip preserves data', () async {
      final firestore = FakeFirebaseFirestore();
      final created = DateTime(2026, 2, 27, 8, 0);
      final updated = DateTime(2026, 2, 27, 10, 30);
      final original = DailyEntry(
        date: '2026-02-27',
        createdAt: created,
        updatedAt: updated,
      );

      await firestore
          .collection('test')
          .doc('2026-02-27')
          .set(original.toFirestore());
      final snapshot = await firestore
          .collection('test')
          .doc('2026-02-27')
          .get();
      final restored = DailyEntry.fromFirestore(snapshot);

      expect(restored.date, '2026-02-27');
      expect(restored.createdAt, created);
      expect(restored.updatedAt, updated);
    });

    test('fromFirestore handles missing timestamps', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('test').doc('no-ts').set({});

      final snapshot = await firestore.collection('test').doc('no-ts').get();
      final entry = DailyEntry.fromFirestore(snapshot);

      expect(entry.date, 'no-ts');
      // Should default to DateTime.now() — just verify they're not null
      expect(entry.createdAt, isA<DateTime>());
      expect(entry.updatedAt, isA<DateTime>());
    });
  });
}
