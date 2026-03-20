import 'dart:convert';
import 'dart:io';

import 'rubric.dart';

/// Wraps the Claude CLI (`claude -p`) for eval conversations.
///
/// Uses `claude --print` with `--system-prompt` for stateless per-turn calls.
/// For the user persona, each turn is an independent `claude -p` invocation
/// with the conversation context embedded in the system prompt.
/// For the judge, a single call with the full transcript.
class ClaudeSession {
  final String _systemPrompt;
  final List<_Turn> _conversationHistory = [];

  ClaudeSession._({required String systemPrompt})
      : _systemPrompt = systemPrompt;

  /// Create a session for playing a user persona.
  factory ClaudeSession.user({
    required String personaId,
    required String systemPrompt,
  }) {
    return ClaudeSession._(systemPrompt: systemPrompt);
  }

  /// Create a session for the judge.
  factory ClaudeSession.judge() {
    return ClaudeSession._(
      systemPrompt: 'You are a conversation quality evaluator. '
          'Follow instructions exactly and respond with valid JSON only.',
    );
  }

  /// No-op for the pipe-based approach.
  Future<void> start() async {}

  /// Send a message and get Claude's response.
  ///
  /// Builds the full conversation context into the prompt so each
  /// `claude -p` call has the history it needs.
  Future<String> sendMessage(String message) async {
    _conversationHistory.add(_Turn(speaker: 'AI companion', text: message));

    // Build a prompt that includes conversation history
    final contextPrompt = _buildContextPrompt();

    final result = await _runClaude(contextPrompt);

    final response = result.stdout.toString().trim();
    _conversationHistory.add(_Turn(speaker: 'You', text: response));

    return response;
  }

  /// Send a full transcript to the judge and get structured scores.
  Future<EvalScores> judge({
    required String transcript,
    required String toolCalls,
    required String personaDescription,
    required String judgePrompt,
  }) async {
    final filledPrompt = judgePrompt
        .replaceAll('{transcript}', transcript)
        .replaceAll('{tool_calls}', toolCalls)
        .replaceAll('{persona_description}', personaDescription);

    final result = await _runClaude(filledPrompt);
    final response = result.stdout.toString().trim();

    // Extract JSON from response (Claude may wrap it in markdown code blocks)
    final jsonStr = _extractJson(response);

    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final scoresMap = json['scores'] as Map<String, dynamic>;

    return EvalScores(
      scores: {
        for (final dim in Dimension.values)
          if (scoresMap.containsKey(dim.name))
            dim: (scoresMap[dim.name] as num).toInt(),
      },
      judgeNotes: json['judge_notes'] as String? ?? '',
      flaggedTurns:
          (json['flagged_turns'] as List<dynamic>?)?.cast<int>() ?? [],
    );
  }

  /// No-op for the pipe-based approach.
  Future<void> stop() async {}

  // --- Private helpers ---

  /// Build a prompt that includes conversation history for multi-turn context.
  String _buildContextPrompt() {
    if (_conversationHistory.isEmpty) return 'Start the conversation.';

    final buffer = StringBuffer();
    buffer.writeln('Here is the conversation so far:');
    buffer.writeln('---');
    for (final turn in _conversationHistory) {
      buffer.writeln('${turn.speaker}: ${turn.text}');
      buffer.writeln();
    }
    buffer.writeln('---');
    buffer.writeln(
      'Now respond as your character. Give ONLY your in-character reply, '
      'nothing else.',
    );

    return buffer.toString();
  }

  /// Run `claude -p` with the system prompt and user message.
  Future<ProcessResult> _runClaude(String userMessage) async {
    // Write system prompt and message to temp files to avoid shell escaping
    final promptFile = await _writeTempFile('eval-sys', _systemPrompt);
    final msgFile = await _writeTempFile('eval-msg', userMessage);

    final result = await Process.run(
      'claude',
      [
        '-p',
        '--system-prompt',
        await File(promptFile).readAsString(),
        '--output-format',
        'text',
        '--no-session-persistence',
        await File(msgFile).readAsString(),
      ],
      environment: Platform.environment,
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      throw Exception('Claude CLI failed (exit ${result.exitCode}): $stderr');
    }

    // Clean up temp files
    try {
      await File(promptFile).delete();
      await File(msgFile).delete();
    } catch (_) {}

    return result;
  }

  /// Write content to a temp file, return the path.
  Future<String> _writeTempFile(String prefix, String content) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$prefix-${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString(content);
    return file.path;
  }

  /// Extract JSON object from a response that may include markdown fences.
  String _extractJson(String response) {
    // Try to find JSON in code blocks first
    final codeBlockMatch =
        RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```').firstMatch(response);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)!.trim();
    }

    // Fall back to finding the outermost { ... }
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start != -1 && end > start) {
      return response.substring(start, end + 1);
    }

    throw FormatException(
      'No JSON found in judge response:\n$response',
    );
  }
}

class _Turn {
  final String speaker;
  final String text;

  const _Turn({required this.speaker, required this.text});
}
