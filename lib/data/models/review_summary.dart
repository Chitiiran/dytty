import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ReviewSummary extends Equatable {
  final String id;
  final String categoryId;
  final String weekStart;
  final String summary;
  final String? audioUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReviewSummary({
    required this.id,
    required this.categoryId,
    required this.weekStart,
    required this.summary,
    this.audioUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    categoryId,
    weekStart,
    summary,
    audioUrl,
    createdAt,
    updatedAt,
  ];

  factory ReviewSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewSummary(
      id: doc.id,
      categoryId: data['categoryId'] as String? ?? '',
      weekStart: data['weekStart'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      audioUrl: data['audioUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'weekStart': weekStart,
      'summary': summary,
      if (audioUrl != null) 'audioUrl': audioUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
