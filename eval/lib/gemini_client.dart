import 'dart:convert';

import 'package:dytty/core/constants/daily_call_prompt.dart';
import 'package:dytty/core/constants/tool_declarations.dart';
import 'package:firebase_ai/firebase_ai.dart';

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

/// Wraps firebase_ai's GenerativeModel for text-mode eval conversations.
///
/// Uses the same system prompt and tool declarations as the production app,
/// but in text mode (not live audio) for cheaper and faster iteration.
class GeminiClient {
  final GenerativeModel _model;
  ChatSession? _chat;
  final List<RecordedToolCall> allToolCalls = [];
  int _currentTurn = 0;

  GeminiClient._(this._model);

  /// Create a GeminiClient using Firebase AI.
  ///
  /// The [promptVersion] label is for tracking only — the actual prompt
  /// is always loaded from the shared constant.
  static GeminiClient create({String promptVersion = 'v1-current'}) {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash-preview-04-17',
      systemInstruction: Content.text(dailyCallSystemPrompt),
      tools: [
        Tool.functionDeclarations([
          saveEntryDeclaration,
          editEntryDeclaration,
        ]),
      ],
    );
    return GeminiClient._(model);
  }

  /// Start a new conversation.
  void startChat() {
    _chat = _model.startChat();
    _currentTurn = 0;
    allToolCalls.clear();
  }

  /// Send a user message and get the AI's text response.
  ///
  /// If the model responds with tool calls, they are recorded and
  /// auto-responded to so the model can continue with its text reply.
  Future<GeminiTurnResponse> sendMessage(String userMessage) async {
    if (_chat == null) throw StateError('Call startChat() first');
    _currentTurn++;

    var response = await _chat!.sendMessage(Content.text(userMessage));
    final turnToolCalls = <RecordedToolCall>[];
    final textParts = <String>[];

    // Process response — may contain text, tool calls, or both.
    // Loop to handle multi-step tool call chains.
    while (true) {
      // Collect text parts
      for (final candidate in response.candidates) {
        for (final part in candidate.content.parts) {
          if (part is TextPart) {
            textParts.add(part.text);
          }
        }
      }

      // Check for function calls
      final functionCalls = response.functionCalls.toList();
      if (functionCalls.isEmpty) break;

      // Record and auto-respond to each tool call
      final functionResponses = <FunctionResponse>[];
      for (final call in functionCalls) {
        final recorded = RecordedToolCall(
          turn: _currentTurn,
          name: call.name,
          args: call.args,
          timestamp: DateTime.now(),
        );
        turnToolCalls.add(recorded);
        allToolCalls.add(recorded);

        // Simulate successful tool execution
        functionResponses.add(
          FunctionResponse(call.name, {
            'status': 'saved',
            'entry_id': 'eval-${call.name}-${_currentTurn}-${turnToolCalls.length}',
          }),
        );
      }

      // Send tool responses back so the model can continue
      response = await _chat!.sendMessage(
        Content.functionResponses(functionResponses),
      );
    }

    return GeminiTurnResponse(
      text: textParts.join('\n').trim(),
      toolCalls: turnToolCalls,
    );
  }

  /// Get the opening message from the AI (no user input yet).
  Future<GeminiTurnResponse> getGreeting() async {
    if (_chat == null) throw StateError('Call startChat() first');

    // Send an empty-ish message to kick off the conversation
    return sendMessage('[User has just connected to the daily call]');
  }

  /// Serialize all recorded tool calls to JSON string.
  String toolCallsJson() => const JsonEncoder.withIndent('  ')
      .convert(allToolCalls.map((tc) => tc.toJson()).toList());
}
