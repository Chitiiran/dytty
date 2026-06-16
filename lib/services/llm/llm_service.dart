class LlmResponse {
  final String text;
  final Map<String, dynamic>? metadata;

  const LlmResponse({required this.text, this.metadata});
}

class CategorizationResult {
  final String suggestedCategory;
  final String summary;
  final double confidence;
  final List<String> suggestedTags;

  const CategorizationResult({
    required this.suggestedCategory,
    required this.summary,
    required this.confidence,
    this.suggestedTags = const [],
  });
}

enum ReconcileAction { add, reword }

/// One change the post-call holistic pass wants to apply to the session's
/// journal entries. `add` = a missed item; `reword` = complete/rephrase an
/// existing entry (requires [entryId]).
class ReconciledItem {
  final ReconcileAction action;
  final String? entryId; // required for reword; null for add
  final String category; // JournalCategory.name; ignored for reword
  final String text;
  final String sourceTranscript; // raw span this came from (add only)

  const ReconciledItem({
    required this.action,
    required this.text,
    this.entryId,
    this.category = 'positive',
    this.sourceTranscript = '',
  });
}

/// An entry already saved during the call, given to the reconcile pass so it
/// can dedup against / edit them.
class SavedEntrySnapshot {
  final String? entryId;
  final String category;
  final String text;

  const SavedEntrySnapshot({
    required this.category,
    required this.text,
    this.entryId,
  });
}

abstract class LlmService {
  Future<LlmResponse> generateResponse(String prompt);

  Future<CategorizationResult> categorizeEntry(
    String text, {
    List<String> categoryIds,
  });

  Future<String> summarizeEntry(String text);

  /// Re-summarizes when the user has edited the transcript.
  /// Compares [originalTranscript] with [editedTranscript] and produces
  /// a summary that reflects the user's intent (edited version takes priority).
  Future<String> reconcileSummary(
    String originalTranscript,
    String editedTranscript,
  );

  Future<String> generateWeeklySummary(List<String> entries);

  /// Holistic post-call pass. Given the full [transcript] and the entries
  /// [alreadySaved] during the call (with ids), returns ONLY the items that
  /// were missed (add) or incompletely captured (reword). Returns empty when
  /// nothing needs changing.
  Future<List<ReconciledItem>> reconcileSession(
    String transcript,
    List<SavedEntrySnapshot> alreadySaved,
  );

  void dispose();
}
