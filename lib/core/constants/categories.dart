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

  String get icon {
    switch (this) {
      case JournalCategory.positive:
        return '☀';
      case JournalCategory.negative:
        return '☁';
      case JournalCategory.gratitude:
        return '🙏';
      case JournalCategory.beauty:
        return '✿';
      case JournalCategory.identity:
        return '◉';
    }
  }
}
