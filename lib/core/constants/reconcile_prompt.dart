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

STEP 3 — GAP-FILL (recall, including miscategorized items). Compare your items
to the already-saved entries. An item counts as ALREADY saved only when an
existing entry has BOTH the same content AND the same category. If the
transcript clearly expresses an item in a category that has NO matching saved
entry — even if the same moment was saved under a DIFFERENT category — that
category is a GAP: add the correctly-categorized item. (Example: the live model
filed a joyful memory or a beautiful sight under "negative" because the call's
overall tone was sad; the "positive" / "beauty" item is still missing and you
MUST add it.) Then, for EACH of the categories, re-check the transcript once
more: if that category is genuinely present in what the user said but absent
from the saved set, add it (grounded in a quote). Never restate an item already
saved under its CORRECT category.

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
