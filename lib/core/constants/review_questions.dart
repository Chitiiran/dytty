import 'package:dytty/core/constants/categories.dart';

/// Review questions for each journal category.
/// Used by the AI review call to guide reflection.
const Map<JournalCategory, List<String>> reviewQuestions = {
  JournalCategory.positive: [
    'Is the feeling lasting?',
    'Did you take action on this feeling?',
  ],
  JournalCategory.negative: [
    'Is the feeling lasting — same intensity?',
    'Did you take action toward resolving or cherishing it?',
  ],
  JournalCategory.gratitude: [
    'Grateful for good things, and that bad things weren\'t the worst?',
    'Is your ability to be grateful improving?',
  ],
  JournalCategory.beauty: [
    'Appreciating good things daily?',
    'Appreciating beyond visual — taste, sound, other senses?',
  ],
  JournalCategory.identity: [
    'Overall identity for the week based on entries?',
    'Which to adopt more, which to forgo?',
  ],
};
