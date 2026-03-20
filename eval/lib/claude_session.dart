import 'dart:convert';
import 'dart:io';

import 'rubric.dart';

/// Wraps claude-session-driver to manage Claude tmux sessions via WSL.
///
/// Uses `wsl tmux` + `claude` CLI to create sessions that play user personas
/// and judge conversation quality.
class ClaudeSession {
  final String sessionName;
  final String systemPrompt;
  bool _started = false;

  ClaudeSession._({required this.sessionName, required this.systemPrompt});

  /// Create a session for playing a user persona.
  factory ClaudeSession.user({
    required String personaId,
    required String systemPrompt,
  }) {
    return ClaudeSession._(
      sessionName: 'eval-user-$personaId',
      systemPrompt: systemPrompt,
    );
  }

  /// Create a session for the judge.
  factory ClaudeSession.judge() {
    return ClaudeSession._(
      sessionName: 'eval-judge',
      systemPrompt: 'You are a conversation quality evaluator. '
          'Follow instructions exactly and respond with valid JSON only.',
    );
  }

  /// Start the Claude session in a tmux window.
  Future<void> start() async {
    // Kill any existing session with this name
    await _runWsl(['tmux', 'kill-session', '-t', sessionName]);

    // Create new tmux session
    final createResult = await _runWsl([
      'tmux',
      'new-session',
      '-d',
      '-s',
      sessionName,
      '-x',
      '200',
      '-y',
      '50',
    ]);
    if (createResult.exitCode != 0) {
      throw Exception(
        'Failed to create tmux session: ${createResult.stderr}',
      );
    }

    // Launch claude in the session with the system prompt
    // Write system prompt to a temp file to avoid shell escaping issues
    final promptFile = await _writeTempFile(
      'eval-prompt-$sessionName',
      systemPrompt,
    );

    await _sendKeys(
      'claude --system-prompt "\$(cat $promptFile)" --no-input-confirmation',
    );

    // Wait for Claude to start
    await Future<void>.delayed(const Duration(seconds: 5));
    _started = true;
  }

  /// Send a message to the Claude session and get the response.
  ///
  /// Writes the message to the tmux session, waits for Claude to respond,
  /// then reads the response from the tmux buffer.
  Future<String> sendMessage(String message) async {
    if (!_started) throw StateError('Session not started');

    // Write message to a temp file to avoid escaping issues
    final msgFile = await _writeTempFile(
      'eval-msg-$sessionName',
      message,
    );

    // Clear the current buffer to make response extraction easier
    await _runWsl([
      'tmux',
      'send-keys',
      '-t',
      sessionName,
      'clear',
      'Enter',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Send the message content via tmux
    await _sendKeys('\$(cat $msgFile)');
    await _sendKeys('', enter: true);

    // Wait for Claude to process and respond
    // Poll the buffer until we see the response stabilize
    var lastContent = '';
    var stableCount = 0;
    const maxWait = Duration(minutes: 2);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final content = await _captureBuffer();

      if (content == lastContent && content.isNotEmpty) {
        stableCount++;
        if (stableCount >= 3) break; // Response has stabilized
      } else {
        stableCount = 0;
        lastContent = content;
      }
    }

    return _extractResponse(lastContent);
  }

  /// Send a full transcript to the judge session and get structured scores.
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

    final response = await sendMessage(filledPrompt);

    // Extract JSON from response
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
    if (jsonMatch == null) {
      throw FormatException(
        'Judge did not return valid JSON. Response:\n$response',
      );
    }

    final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    final scoresMap = json['scores'] as Map<String, dynamic>;

    return EvalScores(
      scores: {
        for (final dim in Dimension.values)
          if (scoresMap.containsKey(dim.name))
            dim: (scoresMap[dim.name] as num).toInt(),
      },
      judgeNotes: json['judge_notes'] as String? ?? '',
      flaggedTurns: (json['flagged_turns'] as List<dynamic>?)
              ?.cast<int>() ??
          [],
    );
  }

  /// Stop and clean up the session.
  Future<void> stop() async {
    await _runWsl(['tmux', 'kill-session', '-t', sessionName]);
    _started = false;
  }

  // --- Private helpers ---

  Future<void> _sendKeys(String keys, {bool enter = false}) async {
    final args = ['tmux', 'send-keys', '-t', sessionName, keys];
    if (enter || keys.isNotEmpty) args.add('Enter');
    await _runWsl(args);
  }

  Future<String> _captureBuffer() async {
    final result = await _runWsl([
      'tmux',
      'capture-pane',
      '-t',
      sessionName,
      '-p',
      '-S',
      '-100',
    ]);
    return result.stdout.toString().trim();
  }

  String _extractResponse(String buffer) {
    // The response is everything after the last user input marker
    // Simple heuristic: take the last substantial block of text
    final lines = buffer.split('\n');
    final nonEmpty =
        lines.where((l) => l.trim().isNotEmpty).toList();
    if (nonEmpty.isEmpty) return buffer;

    // Return the full buffer — the orchestrator can clean it up further
    return buffer;
  }

  Future<String> _writeTempFile(String name, String content) async {
    // Write to WSL /tmp via a Windows temp file
    final winTmp = Directory.systemTemp;
    final file = File('${winTmp.path}/$name.txt');
    await file.writeAsString(content);

    // Convert Windows path to WSL path
    final wslPath = _windowsToWslPath(file.path);
    return wslPath;
  }

  String _windowsToWslPath(String winPath) {
    // C:\Users\foo\bar -> /mnt/c/Users/foo/bar
    final normalized = winPath.replaceAll('\\', '/');
    final match = RegExp(r'^([A-Za-z]):(.*)').firstMatch(normalized);
    if (match != null) {
      final drive = match.group(1)!.toLowerCase();
      final rest = match.group(2)!;
      return '/mnt/$drive$rest';
    }
    return normalized;
  }

  Future<ProcessResult> _runWsl(List<String> args) async {
    return Process.run('wsl', args);
  }
}
