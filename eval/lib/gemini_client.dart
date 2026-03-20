import 'dart:convert';
import 'dart:io';

import 'package:googleai_dart/googleai_dart.dart';

import 'prompt.dart';

/// A recorded tool call from the Gemini model.
class RecordedToolCall {
  final int turn;
  final String name;
  final Map<String, dynamic> args;
  final DateTime timestamp;

  const RecordedToolCall({
    required this.turn,
    required this.name,
    required this.args,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'turn': turn,
    'name': name,
    'args': args,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Response from a single Gemini turn.
class GeminiTurnResponse {
  final String text;
  final List<RecordedToolCall> toolCalls;

  const GeminiTurnResponse({required this.text, this.toolCalls = const []});
}

/// Tool declarations for the daily call — mirrors the app's firebase_ai
/// declarations using googleai_dart types.
final _evalTools = [
  Tool(
    functionDeclarations: [
      FunctionDeclaration(
        name: 'save_entry',
        description:
            'Save a journal entry for the user. Call this when the user shares '
            'something they want to remember — a thought, feeling, experience, '
            'or reflection. Categorize it into the most appropriate category.',
        parameters: Schema(
          type: SchemaType.object,
          properties: {
            'category': Schema(
              type: SchemaType.string,
              description: 'The journal category that best fits this entry.',
              enumValues: [
                'positive',
                'negative',
                'gratitude',
                'beauty',
                'identity',
              ],
            ),
            'text': Schema(
              type: SchemaType.string,
              description:
                  'A concise summary of what the user shared, written in '
                  'first person as if the user wrote it.',
            ),
            'transcript': Schema(
              type: SchemaType.string,
              description:
                  'The raw transcript of what the user said that led to '
                  'this entry.',
            ),
          },
          required: ['category', 'text', 'transcript'],
        ),
      ),
      FunctionDeclaration(
        name: 'edit_entry',
        description:
            'Edit an existing journal entry. Call this when the user wants to '
            'modify, correct, or rephrase something they previously shared.',
        parameters: Schema(
          type: SchemaType.object,
          properties: {
            'entry_id': Schema(
              type: SchemaType.string,
              description: 'The ID of the entry to edit.',
            ),
            'text': Schema(
              type: SchemaType.string,
              description:
                  'The new text for the entry, written in first person.',
            ),
          },
          required: ['entry_id', 'text'],
        ),
      ),
    ],
  ),
];

/// Wraps googleai_dart for text-mode eval conversations.
///
/// Uses the same system prompt and equivalent tool declarations as the
/// production app, but in text mode (not live audio) for cheaper iteration.
class GeminiClient {
  final GoogleAIClient _client;
  final String _model;
  final List<Content> _history = [];
  final List<RecordedToolCall> allToolCalls = [];
  int _currentTurn = 0;

  GeminiClient._({
    required GoogleAIClient client,
    required String model,
  })  : _client = client,
        _model = model;

  /// Create a GeminiClient using the GEMINI_API_KEY or GOOGLE_GENAI_API_KEY
  /// environment variable.
  static GeminiClient create({String promptVersion = 'v1-current'}) {
    final apiKey = Platform.environment['GEMINI_API_KEY'] ??
        Platform.environment['GOOGLE_GENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Set GEMINI_API_KEY or GOOGLE_GENAI_API_KEY environment variable',
      );
    }

    final client = GoogleAIClient.withApiKey(apiKey);

    return GeminiClient._(
      client: client,
      model: 'gemini-2.5-flash',
    );
  }

  /// Start a new conversation (resets history).
  void startChat() {
    _history.clear();
    _currentTurn = 0;
    allToolCalls.clear();
  }

  /// Send a user message and get the AI's text response.
  ///
  /// Manages conversation history internally. If the model responds with
  /// tool calls, they are recorded and auto-responded to so the model
  /// can continue with its text reply.
  Future<GeminiTurnResponse> sendMessage(String userMessage) async {
    _currentTurn++;

    // Add user message to history
    _history.add(Content.user([TextPart(userMessage)]));

    var response = await _generate();
    final turnToolCalls = <RecordedToolCall>[];
    final textParts = <String>[];

    // Process response — may contain text, tool calls, or both.
    // Loop to handle multi-step tool call chains.
    while (true) {
      // Collect text and add model response to history
      for (final candidate in (response.candidates ?? [])) {
        final content = candidate.content;
        if (content == null) continue;

        // Extract text from TextPart instances
        for (final part in content.parts) {
          if (part is TextPart && part.thought != true) {
            textParts.add(part.text);
          }
        }

        // Add model content to history (preserves function call parts too)
        _history.add(content);
      }

      // Check for function calls
      final functionCalls = _extractFunctionCalls(response);
      if (functionCalls.isEmpty) break;

      // Record and auto-respond to each tool call
      final responseParts = <Part>[];
      for (final call in functionCalls) {
        final recorded = RecordedToolCall(
          turn: _currentTurn,
          name: call.name,
          args: call.args ?? {},
          timestamp: DateTime.now(),
        );
        turnToolCalls.add(recorded);
        allToolCalls.add(recorded);

        // Simulate successful tool execution
        responseParts.add(Part.functionResponse(
          call.name,
          {
            'status': 'saved',
            'entry_id':
                'eval-${call.name}-$_currentTurn-${turnToolCalls.length}',
          },
        ));
      }

      // Add tool responses to history and continue
      _history.add(Content.user(responseParts));
      response = await _generate();
    }

    return GeminiTurnResponse(
      text: textParts.join('\n').trim(),
      toolCalls: turnToolCalls,
    );
  }

  /// Get the opening message from the AI (no user input yet).
  Future<GeminiTurnResponse> getGreeting() async {
    return sendMessage('[User has just connected to the daily call]');
  }

  /// Serialize all recorded tool calls to JSON string.
  String toolCallsJson() => const JsonEncoder.withIndent('  ')
      .convert(allToolCalls.map((tc) => tc.toJson()).toList());

  void close() => _client.close();

  // --- Private helpers ---

  Future<GenerateContentResponse> _generate() async {
    // Retry with backoff for rate limits (free tier: 5 req/min)
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        return await _client.models.generateContent(
          model: _model,
          request: GenerateContentRequest(
            contents: _history,
            systemInstruction: Content.text(dailyCallSystemPrompt),
            tools: _evalTools,
          ),
        );
      } on RateLimitException catch (e) {
        if (attempt == 9) rethrow;
        final waitSeconds =
            _parseRetryDelay(e.message) ?? (60 * (attempt ~/ 3 + 1));
        print('  [Rate limited — waiting ${waitSeconds}s '
            '(attempt ${attempt + 1}/10)]');
        await Future<void>.delayed(Duration(seconds: waitSeconds));
      }
    }
    throw StateError('Exceeded max retries due to rate limiting');
  }

  /// Parse retry delay from error message like "Please retry in 58.7s".
  int? _parseRetryDelay(String message) {
    final match = RegExp(r'retry in (\d+)').firstMatch(message);
    if (match != null) return int.parse(match.group(1)!) + 2; // add buffer
    return null;
  }

  List<FunctionCall> _extractFunctionCalls(GenerateContentResponse response) {
    final calls = <FunctionCall>[];
    for (final candidate in (response.candidates ?? [])) {
      final content = candidate.content;
      if (content == null) continue;
      for (final part in content.parts) {
        if (part is FunctionCallPart) {
          calls.add(part.functionCall);
        }
      }
    }
    return calls;
  }
}
