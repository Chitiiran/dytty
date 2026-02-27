import 'package:cloud_firestore/cloud_firestore.dart';

class DailyEntry {
  final String date;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyEntry({
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyEntry(
      date: doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
