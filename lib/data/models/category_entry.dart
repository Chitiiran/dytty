import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dytty/core/constants/categories.dart';

class CategoryEntry {
  final String id;
  final JournalCategory category;
  final String text;
  final String source;
  final DateTime createdAt;

  CategoryEntry({
    required this.id,
    required this.category,
    required this.text,
    this.source = 'manual',
    required this.createdAt,
  });

  factory CategoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryEntry(
      id: doc.id,
      category: JournalCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => JournalCategory.positive,
      ),
      text: (data['text'] as String?) ?? '',
      source: data['source'] as String? ?? 'manual',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category.name,
      'text': text,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
