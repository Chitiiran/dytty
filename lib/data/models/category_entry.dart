import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CategoryEntry extends Equatable {
  final String id;
  final String categoryId;
  final String text;
  final String source;
  final DateTime createdAt;
  final String? audioUrl;
  final String? transcript;
  final List<String> tags;
  final bool isReviewed;

  const CategoryEntry({
    required this.id,
    required this.categoryId,
    required this.text,
    this.source = 'manual',
    required this.createdAt,
    this.audioUrl,
    this.transcript,
    this.tags = const [],
    this.isReviewed = false,
  });

  @override
  List<Object?> get props => [
    id,
    categoryId,
    text,
    source,
    createdAt,
    audioUrl,
    transcript,
    tags,
    isReviewed,
  ];

  factory CategoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryEntry(
      id: doc.id,
      categoryId: data['category'] as String? ?? 'positive',
      text: (data['text'] as String?) ?? '',
      source: data['source'] as String? ?? 'manual',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      audioUrl: data['audioUrl'] as String?,
      transcript: data['transcript'] as String?,
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isReviewed: data['isReviewed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': categoryId,
      'text': text,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (transcript != null) 'transcript': transcript,
      if (tags.isNotEmpty) 'tags': tags,
      if (isReviewed) 'isReviewed': true,
    };
  }
}
