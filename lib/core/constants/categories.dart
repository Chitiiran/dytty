import 'package:flutter/material.dart';
import 'package:dytty/core/theme/app_colors.dart';

enum JournalCategory {
  positive,
  negative,
  gratitude,
  beauty,
  identity;

  String get displayName {
    switch (this) {
      case JournalCategory.positive:
        return 'Positive Things';
      case JournalCategory.negative:
        return 'Negative Things';
      case JournalCategory.gratitude:
        return 'Gratitude';
      case JournalCategory.beauty:
        return 'Beauty';
      case JournalCategory.identity:
        return 'Identity';
    }
  }

  String get prompt {
    switch (this) {
      case JournalCategory.positive:
        return 'What good things happened today?';
      case JournalCategory.negative:
        return 'What was challenging today?';
      case JournalCategory.gratitude:
        return 'What are you grateful for today?';
      case JournalCategory.beauty:
        return 'What was beautiful today?';
      case JournalCategory.identity:
        return 'Who are you based on your actions today?';
    }
  }

  IconData get icon {
    switch (this) {
      case JournalCategory.positive:
        return Icons.wb_sunny_rounded;
      case JournalCategory.negative:
        return Icons.cloud_rounded;
      case JournalCategory.gratitude:
        return Icons.favorite_rounded;
      case JournalCategory.beauty:
        return Icons.local_florist_rounded;
      case JournalCategory.identity:
        return Icons.fingerprint_rounded;
    }
  }

  Color get color {
    switch (this) {
      case JournalCategory.positive:
        return AppColors.positive;
      case JournalCategory.negative:
        return AppColors.negative;
      case JournalCategory.gratitude:
        return AppColors.gratitude;
      case JournalCategory.beauty:
        return AppColors.beauty;
      case JournalCategory.identity:
        return AppColors.identity;
    }
  }
}
