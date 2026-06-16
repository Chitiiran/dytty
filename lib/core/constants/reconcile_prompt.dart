import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/services/llm/llm_service.dart';

/// Builds the prompt for the holistic post-call reconcile pass.
///
/// The model is given the full call [transcript] and the entries
/// [alreadySaved] during the call (with their ids). It returns ONLY the
/// items that were missed (via `save_entry`) or incompletely captured (via
/// `edit_entry`) — never re-saving what is already captured.
String buildReconcilePrompt(
  String transcript,
  List<SavedEntrySnapshot> alreadySaved,
) {
  final categories = JournalCategory.values.map((c) => c.name).join(', ');

  final savedList = alreadySaved.isEmpty
      ? '(none)'
      : alreadySaved
            .map((e) => '- id=${e.entryId ?? ''} [${e.category}] ${e.text}')
            .join('\n');

  return '''
You are doing a final holistic review of a journaling voice call. You see the
ENTIRE conversation transcript and every entry that was already saved during the
call. Your job is to catch anything that was missed or only partially captured.

Available categories: $categories

Entries already saved during this call:
$savedList

Full call transcript:
"$transcript"

Rules:
- Only act on journal-worthy items: real thoughts, feelings, experiences, or
  reflections the user shared. Ignore filler, small talk, greetings, and the
  assistant's own words.
- DO NOT duplicate. Do not duplicate anything already captured in the saved
  entries above — if an item is already saved, leave it alone.
- Use save_entry ONLY for journal-worthy items that are genuinely missing from
  the saved entries.
- Use edit_entry (with the matching entry id) to complete or correct an entry
  that was saved incompletely or inaccurately during the call.
- Split multi-item sentences: if one utterance contains several distinct
  journal-worthy items, emit a separate save_entry for each.
- Honor negation and self-correction: if the user retracted, negated, or
  corrected something, reflect their final intent — do not save retracted items.
- Ignore anything the user took back or said they did not mean.
- If nothing was missed and nothing needs editing, make no tool calls at all.

Call save_entry and edit_entry as needed. Write entry text in first person, as
if the user wrote it themselves.
''';
}
