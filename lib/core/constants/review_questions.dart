/// Review questions for each journal category.
/// Used by the AI review call to guide reflection.
const Map<String, List<String>> reviewQuestions = {
  'positive': [
    'Is the feeling lasting?',
    'Did you take action on this feeling?',
  ],
  'negative': [
    'Is the feeling lasting — same intensity?',
    'Did you take action toward resolving or cherishing it?',
  ],
  'gratitude': [
    'Grateful for good things, and that bad things weren\'t the worst?',
    'Is your ability to be grateful improving?',
  ],
  'beauty': [
    'Appreciating good things daily?',
    'Appreciating beyond visual — taste, sound, other senses?',
  ],
  'identity': [
    'Overall identity for the week based on entries?',
    'Which to adopt more, which to forgo?',
  ],
};
