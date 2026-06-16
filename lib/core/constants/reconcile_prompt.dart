import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/services/llm/llm_service.dart';

/// Builds the prompt for the holistic post-call reconcile pass (#231).
///
/// The model sees the full call [transcript] and the entries [alreadySaved]
/// during the call. It works in three steps — quote → enumerate → gap-fill —
/// and returns ONLY a JSON array of the journal-worthy items that are MISSING
/// from the saved set. It never re-judges or restates a saved entry (recall-
/// only). The schema-first array attacks multi-item under-capture; pair with
/// [GenerationConfig.responseSchema] in the caller.
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
You review a finished journaling voice call. You see the ENTIRE transcript and
every entry already saved during the call. Find every journal-worthy item the
user shared that is NOT already saved. Work in three steps.

Available categories: $categories

Entries already saved during this call:
$savedList

Full call transcript:
"$transcript"

STEP 1 — QUOTE. Read the transcript and note every verbatim span where the user
expresses something worth journaling (a real thought, feeling, experience, or
reflection). ONE sentence may contain MORE THAN ONE span — e.g. a complaint AND
a thank-you. Ignore filler, greetings, and the assistant's own words.

STEP 2 — ENUMERATE. For each span, list every DISTINCT item it contains. A
single sentence carrying opposing feelings becomes TWO items. Assign each item
exactly ONE category from the list above. Honor negation/self-correction:
reflect the user's FINAL intent; never save anything they retracted.

STEP 3 — GAP-FILL (recall-only). Compare your items to the already-saved
entries. Keep ONLY items that are present in the transcript and NOT already
saved. Never restate, re-judge, or modify a saved entry. Then, for EACH
category, re-check the transcript once more for anything in that category you
missed, and add it (grounded in a quote).

Return ONLY a JSON array. Each element:
{"category": "<one of: $categories>", "text": "<the item, first person, as if
the user wrote it>", "quote": "<verbatim span from the transcript>"}
If nothing is missing, return [].

Example (one sentence, two opposing items):
Transcript line: "Work was brutal and I almost quit, but honestly I'm just
grateful my sister called and talked me down."
[
  {"category": "negative", "text": "Work was brutal and I almost quit today.", "quote": "Work was brutal and I almost quit"},
  {"category": "gratitude", "text": "I'm grateful my sister called and talked me down.", "quote": "grateful my sister called and talked me down"}
]
''';
}
