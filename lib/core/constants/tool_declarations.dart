import 'package:firebase_ai/firebase_ai.dart';

/// Tool declarations for the daily call AI conversation.
///
/// Shared between GeminiLiveService and ReviewCallController.

/// Declaration for saving a new journal entry during the daily call.
final saveEntryDeclaration = FunctionDeclaration(
  'save_entry',
  'Save a journal entry for the user. Call this when the user shares '
      'something they want to remember — a thought, feeling, experience, or '
      'reflection. Categorize it into the most appropriate category.',
  parameters: {
    'category': Schema.enumString(
      enumValues: ['positive', 'negative', 'gratitude', 'beauty', 'identity'],
      description: 'The journal category that best fits this entry.',
    ),
    'text': Schema.string(
      description:
          'A concise summary of what the user shared, written in '
          'first person as if the user wrote it.',
    ),
    'transcript': Schema.string(
      description:
          'The raw transcript of what the user said that led to this entry.',
    ),
  },
);

/// Declaration for editing an existing journal entry during the daily call.
final editEntryDeclaration = FunctionDeclaration(
  'edit_entry',
  'Edit an existing journal entry. Call this when the user wants to '
      'modify, correct, or rephrase something they previously shared.',
  parameters: {
    'entry_id': Schema.string(description: 'The ID of the entry to edit.'),
    'text': Schema.string(
      description: 'The new text for the entry, written in first person.',
    ),
  },
);
