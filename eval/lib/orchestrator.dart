import 'dart:convert';
import 'dart:io';

import 'claude_session.dart';
import 'gemini_client.dart';
import 'personas/persona.dart';
import 'report.dart';
import 'rubric.dart';

/// A single turn in the conversation transcript.
class TranscriptTurn {
  final int turn;
  final String speaker; // 'ai' or 'user'
  final String text;

  const TranscriptTurn({
    required this.turn,
    required this.speaker,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
    'turn': turn,
    'speaker': speaker,
    'text': text,
  };
}

/// Result of a single eval run.
class EvalResult {
  final String persona;
  final String promptVersion;
  final String model;
  final DateTime timestamp;
  final List<TranscriptTurn> transcript;
  final List<RecordedToolCall> toolCalls;
  final EvalScores scores;
  final int turnCount;

  const EvalResult({
    required this.persona,
    required this.promptVersion,
    required this.model,
    required this.timestamp,
    required this.transcript,
    required this.toolCalls,
    required this.scores,
    required this.turnCount,
  });

  Map<String, dynamic> toJson() => {
    'meta': {
      'timestamp': timestamp.toIso8601String(),
      'prompt_version': promptVersion,
      'persona': persona,
      'model': model,
      'turn_count': turnCount,
    },
    'transcript': transcript.map((t) => t.toJson()).toList(),
    'tool_calls': toolCalls.map((tc) => tc.toJson()).toList(),
    'scores': scores.toJson(),
  };
}

/// Orchestrates a turn-by-turn conversation between Gemini and a Claude persona,
/// then scores the result with a Claude judge.
class Orchestrator {
  final int maxTurns;
  final String promptVersion;

  const Orchestrator({this.maxTurns = 20, this.promptVersion = 'v1-current'});

  /// Run a full eval for a single persona.
  Future<EvalResult> run(Persona persona) async {
    final timestamp = DateTime.now();
    print('Starting eval: ${persona.name} (max $maxTurns turns)');
    print('${'=' * 60}');

    // Initialize clients
    final gemini = GeminiClient.create(promptVersion: promptVersion);
    gemini.startChat();

    final userSession = ClaudeSession.user(
      personaId: persona.id,
      systemPrompt: persona.systemPrompt,
    );

    final transcript = <TranscriptTurn>[];
    var turnNumber = 0;

    try {
      await userSession.start();

      // Get AI's opening message
      print('\n[AI greeting...]');
      final greeting = await gemini.getGreeting();
      turnNumber++;
      transcript.add(TranscriptTurn(
        turn: turnNumber,
        speaker: 'ai',
        text: greeting.text,
      ));
      print('  AI: ${_truncate(greeting.text, 100)}');

      // Turn loop
      while (turnNumber < maxTurns) {
        // Get user (Claude persona) response
        print('\n[User responding...]');
        final userReply = await userSession.sendMessage(greeting.text);
        turnNumber++;
        transcript.add(TranscriptTurn(
          turn: turnNumber,
          speaker: 'user',
          text: userReply,
        ));
        print('  User: ${_truncate(userReply, 100)}');

        // Check if conversation is ending
        if (_isGoodbye(userReply)) {
          print('\n[User said goodbye — ending conversation]');
          break;
        }

        // Get AI response
        print('\n[AI responding...]');
        final aiResponse = await gemini.sendMessage(userReply);
        turnNumber++;
        transcript.add(TranscriptTurn(
          turn: turnNumber,
          speaker: 'ai',
          text: aiResponse.text,
        ));
        print('  AI: ${_truncate(aiResponse.text, 100)}');

        if (aiResponse.toolCalls.isNotEmpty) {
          for (final tc in aiResponse.toolCalls) {
            print('  [Tool: ${tc.name}(${jsonEncode(tc.args)})]');
          }
        }

        // Check if AI is wrapping up
        if (_isGoodbye(aiResponse.text)) {
          print('\n[AI said goodbye — ending conversation]');
          break;
        }
      }

      if (turnNumber >= maxTurns) {
        print('\n[Max turns ($maxTurns) reached — ending conversation]');
      }

      print('\n${'=' * 60}');
      print('Conversation complete: $turnNumber turns, '
          '${gemini.allToolCalls.length} tool calls');

      // Judge the conversation
      print('\n[Judging conversation quality...]');
      final judgeSession = ClaudeSession.judge();
      EvalScores scores;

      try {
        await judgeSession.start();
        scores = await judgeSession.judge(
          transcript: _formatTranscript(transcript),
          toolCalls: gemini.toolCallsJson(),
          personaDescription: persona.description,
          judgePrompt: judgeSystemPrompt,
        );
      } finally {
        await judgeSession.stop();
      }

      final result = EvalResult(
        persona: persona.id,
        promptVersion: promptVersion,
        model: 'gemini-2.5-flash-preview-04-17',
        timestamp: timestamp,
        transcript: transcript,
        toolCalls: gemini.allToolCalls,
        scores: scores,
        turnCount: turnNumber,
      );

      // Save and display results
      await saveResult(result);
      printSingleResult(result);

      return result;
    } finally {
      await userSession.stop();
    }
  }

  /// Run eval for multiple personas and print summary.
  Future<List<EvalResult>> runAll(List<Persona> personas) async {
    final results = <EvalResult>[];
    for (final persona in personas) {
      final result = await run(persona);
      results.add(result);
      print(''); // Blank line between runs
    }
    printSummaryTable(results);
    return results;
  }

  /// Save result JSON to eval/results/.
  Future<void> saveResult(EvalResult result) async {
    final dir = Directory('eval/results');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final ts = result.timestamp
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('eval/results/$ts-${result.persona}.json');
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(result.toJson()));
    print('Results saved to: ${file.path}');
  }

  bool _isGoodbye(String text) {
    final lower = text.toLowerCase();
    return lower.contains('goodbye') ||
        lower.contains('bye') ||
        lower.contains("i'm done") ||
        lower.contains('that\'s about it') ||
        lower.contains('take care') ||
        lower.contains('good night');
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  String _formatTranscript(List<TranscriptTurn> transcript) {
    return transcript
        .map((t) => '[Turn ${t.turn}] ${t.speaker.toUpperCase()}: ${t.text}')
        .join('\n\n');
  }
}
