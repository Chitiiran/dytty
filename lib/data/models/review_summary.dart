import 'dart:developer' as dev;

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

  factory ReviewSummary.fromFirestore(
    DocumentSnapshot doc, {
    void Function(String)? onWarning,
  }) {
    final data = doc.data() as Map<String, dynamic>;

    void warn(String field) {
      final msg = 'ReviewSummary ${doc.id}: missing $field, defaulting to now';
      if (onWarning != null) {
        onWarning(msg);
      } else {
        dev.log(msg, name: 'ReviewSummary');
      }
    }

    final createdTs = data['createdAt'] as Timestamp?;
    final updatedTs = data['updatedAt'] as Timestamp?;
    if (createdTs == null) warn('createdAt');
    if (updatedTs == null) warn('updatedAt');

    return ReviewSummary(
      id: doc.id,
      categoryId: data['categoryId'] as String? ?? '',
      weekStart: data['weekStart'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      audioUrl: data['audioUrl'] as String?,
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      updatedAt: updatedTs?.toDate() ?? DateTime.now(),
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
