import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
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

class GeminiLlmService implements LlmService {
  late final GenerativeModel _model;

  GeminiLlmService({required String apiKey}) {
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
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
  void dispose() {
    // GenerativeModel doesn't require cleanup
  }
}
