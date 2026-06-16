import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/core/constants/reconcile_prompt.dart';
import 'package:dytty/core/constants/tool_declarations.dart';
import 'package:dytty/services/llm/llm_service.dart';

/// Strips markdown code fences from LLM JSON responses.
/// Handles ```json\n...\n```, ```\n...\n```, and plain JSON.
String extractJson(String text) {
  final trimmed = text.trim();
  final fencePattern = RegExp(r'^```(?:json)?\s*\n([\s\S]*?)\n\s*```\s*$');
  final match = fencePattern.firstMatch(trimmed);
  if (match != null) {
    return match.group(1)!.trim();
  }
  return trimmed;
}

/// Converts raw `save_entry` / `edit_entry` function calls (each a
/// `{'name': ..., 'args': {...}}` map) into [ReconciledItem]s.
///
/// `save_entry` -> [ReconcileAction.add] (dropped if text is empty).
/// `edit_entry` -> [ReconcileAction.reword] (dropped if entry_id or text empty).
/// Unknown call names are ignored. Category defaults to 'positive'.
List<ReconciledItem> parseReconcileCalls(List<Map<String, dynamic>> calls) {
  final items = <ReconciledItem>[];
  for (final call in calls) {
    final name = call['name'] as String?;
    final args = (call['args'] as Map?)?.cast<String, dynamic>() ?? const {};

    if (name == 'save_entry') {
      final text = (args['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;
      items.add(
        ReconciledItem(
          action: ReconcileAction.add,
          category: (args['category'] as String?) ?? 'positive',
          text: text,
          sourceTranscript: (args['transcript'] as String?) ?? '',
        ),
      );
    } else if (name == 'edit_entry') {
      final entryId = (args['entry_id'] as String?)?.trim() ?? '';
      final text = (args['text'] as String?)?.trim() ?? '';
      if (entryId.isEmpty || text.isEmpty) continue;
      items.add(
        ReconciledItem(
          action: ReconcileAction.reword,
          entryId: entryId,
          text: text,
        ),
      );
    }
  }
  return items;
}

/// Parses the schema-first reconcile response (#231): a JSON array of
/// `{category, text, quote}` objects into [ReconciledItem] adds.
///
/// Invalid categories fall back to 'positive'; empty-text items are dropped;
/// malformed JSON or a non-list top level yields an empty list (the caller
/// treats that as a no-op). Tolerates markdown-fenced JSON via [extractJson].
List<ReconciledItem> parseReconcileArray(String jsonText) {
  final validCategories = JournalCategory.values.map((c) => c.name).toSet();
  try {
    final decoded = jsonDecode(extractJson(jsonText));
    if (decoded is! List) return const [];
    final items = <ReconciledItem>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final text = (raw['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;
      final cat = (raw['category'] as String?) ?? 'positive';
      items.add(
        ReconciledItem(
          action: ReconcileAction.add,
          category: validCategories.contains(cat) ? cat : 'positive',
          text: text,
          sourceTranscript: (raw['quote'] as String?) ?? '',
        ),
      );
    }
    return items;
  } catch (_) {
    return const [];
  }
}

class GeminiLlmService implements LlmService {
  late final GenerativeModel _model;

  static const _modelName = 'gemini-2.5-flash';

  GeminiLlmService() {
    _model = FirebaseAI.googleAI().generativeModel(model: _modelName);
  }

  @override
  Future<LlmResponse> generateResponse(String prompt) async {
    final response = await _model.generateContent([Content.text(prompt)]);
    return LlmResponse(text: response.text ?? '');
  }

  @override
  Future<CategorizationResult> categorizeEntry(
    String text, {
    List<String> categoryIds = const [
      'positive',
      'negative',
      'gratitude',
      'beauty',
      'identity',
    ],
  }) async {
    final categories = categoryIds.join(', ');
    final prompt =
        '''
Categorize this journal entry into one of these categories: $categories.

Entry: "$text"

Respond with valid JSON only, no markdown:
{"category": "<category_name>", "summary": "<1-sentence summary>", "confidence": <0.0-1.0>, "tags": ["<tag1>", "<tag2>"]}
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final jsonStr = extractJson(response.text ?? '{}');
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    final categoryName = json['category'] as String? ?? 'positive';

    return CategorizationResult(
      suggestedCategory: categoryIds.contains(categoryName)
          ? categoryName
          : categoryIds.first,
      summary: json['summary'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      suggestedTags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  @override
  Future<String> summarizeEntry(String text) async {
    final prompt =
        'Summarize this journal entry in one concise sentence:\n\n"$text"';
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  @override
  Future<String> reconcileSummary(
    String originalTranscript,
    String editedTranscript,
  ) async {
    final prompt =
        '''
You are summarizing a journal voice note. The user spoke the original transcript, then edited it before saving.

Original transcript (what the user said):
"$originalTranscript"

Edited transcript (what the user wants saved):
"$editedTranscript"

Write a concise 1-sentence summary that reflects the user's intent in the edited version. If content was removed, do not include it. If content was added, incorporate it.
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? editedTranscript;
  }

  @override
  Future<String> generateWeeklySummary(List<String> entries) async {
    final entriesText = entries
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    final prompt =
        '''
Summarize these journal entries from the past week into a brief, insightful weekly review (3-5 sentences). Highlight themes, growth, and patterns.

Entries:
$entriesText
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  @override
  Future<List<ReconciledItem>> reconcileSession(
    String transcript,
    List<SavedEntrySnapshot> alreadySaved,
  ) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      tools: [
        Tool.functionDeclarations([saveEntryDeclaration, editEntryDeclaration]),
      ],
    );

    final response = await model.generateContent([
      Content.text(buildReconcilePrompt(transcript, alreadySaved)),
    ]);

    final calls = response.functionCalls
        .map(
          (fc) => {'name': fc.name, 'args': Map<String, dynamic>.from(fc.args)},
        )
        .toList();

    return parseReconcileCalls(calls);
  }

  @override
  void dispose() {
    // GenerativeModel doesn't require cleanup
  }
}
