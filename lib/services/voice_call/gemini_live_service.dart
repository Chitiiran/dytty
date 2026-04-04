import 'dart:async';

import 'package:dytty/core/constants/daily_call_prompt.dart';
import 'package:dytty/core/constants/tool_declarations.dart' as call_tools;
import 'package:dytty/services/voice_call/latency_tracker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Speaker in a voice call transcript.
enum Speaker { user, ai }

/// A structured transcript entry with speaker and text.
class Transcript {
  final Speaker speaker;
  final String text;
  final bool isFinal;

  const Transcript({
    required this.speaker,
    required this.text,
    this.isFinal = true,
  });
}

/// Wraps the Firebase AI Live API for bidirectional voice streaming.
///
/// Manages session lifecycle, audio I/O, tool calling, and latency tracking.
class GeminiLiveService {
  static const _model = 'gemini-2.5-flash-native-audio-preview-12-2025';

  /// Tag used for structured log lines, filterable via `adb logcat`.
  static const _logTag = '[DYTTY]';

  /// Connection timeout for the initial Gemini Live session.
  static const connectionTimeout = Duration(seconds: 15);

  LiveSession? _session;

  final _audioController = StreamController<Uint8List>.broadcast();
  final _transcriptController = StreamController<Transcript>.broadcast();
  final _toolCallController = StreamController<FunctionCall>.broadcast();
  final _stateController = StreamController<GeminiLiveState>.broadcast();

  /// Audio chunks received from the model (PCM 24kHz 16-bit LE mono).
  Stream<Uint8List> get audioStream => _audioController.stream;

  /// Transcription updates (input and output).
  Stream<Transcript> get transcriptStream => _transcriptController.stream;

  /// Tool calls requested by the model.
  Stream<FunctionCall> get toolCallStream => _toolCallController.stream;

  /// Session state changes.
  Stream<GeminiLiveState> get stateStream => _stateController.stream;

  bool get isConnected => _session != null;

  /// Emit a structured log line with the [DYTTY] tag for logcat filtering.
  static void _log(String message) => debugPrint('$_logTag $message');

  /// Emit a state change with logging for test observability.
  void _emitState(GeminiLiveState state) {
    _log('Call state: ${state.name}');
    _stateController.add(state);
  }

  /// High-resolution monotonic timer for latency measurement.
  final Stopwatch _latencyStopwatch = Stopwatch();
  final LatencyTracker _latencyTracker = LatencyTracker();
  bool _modelTurnComplete = true;
  bool _measuring = false;

  final _latencyController = StreamController<int>.broadcast();

  /// Per-turn latency measurements in milliseconds.
  Stream<int> get latencyStream => _latencyController.stream;

  /// Last measured response latency in milliseconds.
  int? lastLatencyMs;

  /// Median latency across all turns in the session.
  int? get latencyP50 => _latencyTracker.p50;

  /// 95th percentile latency across all turns in the session.
  int? get latencyP95 => _latencyTracker.p95;

  /// Connect to the Gemini Live API and start a session.
  ///
  /// Accepts optional [systemPrompt] and [tools] to customize the session.
  /// When null, defaults to the daily call prompt and save_entry tool.
  Future<void> connect({
    String? systemPrompt,
    List<FunctionDeclaration>? tools,
  }) async {
    _emitState(GeminiLiveState.connecting);
    _latencyTracker.reset();
    _modelTurnComplete = true;
    _measuring = false;
    lastLatencyMs = null;

    final effectivePrompt = systemPrompt ?? dailyCallSystemPrompt;
    final effectiveTools = tools ?? [call_tools.saveEntryDeclaration];

    try {
      final liveModel = FirebaseAI.googleAI().liveGenerativeModel(
        model: _model,
        liveGenerationConfig: LiveGenerationConfig(
          responseModalities: [ResponseModalities.audio],
          inputAudioTranscription: AudioTranscriptionConfig(),
          outputAudioTranscription: AudioTranscriptionConfig(),
          speechConfig: SpeechConfig(voiceName: 'Aoede'),
        ),
        systemInstruction: Content.text(effectivePrompt),
        tools: [Tool.functionDeclarations(effectiveTools)],
      );

      _session = await liveModel.connect().timeout(
        connectionTimeout,
        onTimeout: () => throw TimeoutException(
          'Gemini Live connection timed out',
          connectionTimeout,
        ),
      );
      _listenToResponses();
      _emitState(GeminiLiveState.active);
    } catch (e, stackTrace) {
      debugPrint('Gemini Live connect error: $e');
      debugPrint('Stack trace: $stackTrace');
      _emitState(GeminiLiveState.error);
      rethrow;
    }
  }

  /// Send a PCM audio chunk to the model.
  ///
  /// Audio format: 16-bit PCM, 16kHz, mono, little-endian.
  void sendAudio(Uint8List pcmData) {
    if (_session == null) return;
    if (_modelTurnComplete && !_measuring) {
      _latencyStopwatch.reset();
      _latencyStopwatch.start();
      _modelTurnComplete = false;
      _measuring = true;
    }
    _session!.sendAudioRealtime(InlineDataPart('audio/pcm', pcmData));
  }

  /// Send a text message to the model.
  Future<void> sendText(String text) async {
    if (_session == null) return;
    await _session!.send(input: Content.text(text), turnComplete: true);
  }

  /// Respond to a tool call from the model.
  Future<void> sendToolResponse(
    String functionName,
    String? id,
    Map<String, Object?> response,
  ) async {
    if (_session == null) return;
    await _session!.sendToolResponse([
      FunctionResponse(functionName, response),
    ]);
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    _emitState(GeminiLiveState.disconnecting);
    final session = _session;
    _session = null; // Break receive loop before closing
    await session?.close();
    _emitState(GeminiLiveState.idle);
  }

  void dispose() {
    _audioController.close();
    _transcriptController.close();
    _toolCallController.close();
    _stateController.close();
    _latencyController.close();
  }

  /// Start the receive loop for multi-turn conversations.
  ///
  /// `receive()` is an async* generator that yields responses until
  /// `turnComplete: true`, then the stream ends. We loop to re-call
  /// `receive()` for subsequent turns, keeping the session alive.
  void _listenToResponses() {
    _receiveLoop();
  }

  Future<void> _receiveLoop() async {
    try {
      while (_session != null) {
        await for (final response in _session!.receive()) {
          final message = response.message;

          if (message is LiveServerContent) {
            _handleContent(message);
          } else if (message is LiveServerToolCall) {
            _handleToolCall(message);
          } else if (message is GoingAwayNotice) {
            debugPrint(
              'Gemini session ending soon: ${message.timeLeft} remaining',
            );
          }
        }
        // receive() returned (turnComplete) — model's turn is done
        _modelTurnComplete = true;
        _log('Turn complete');
      }
    } catch (e) {
      debugPrint('Gemini Live stream error: $e');
      _emitState(GeminiLiveState.error);
      return;
    }
    // If we exit the while loop, session was set to null (graceful disconnect)
    // Don't emit idle here — disconnect() already handles that
  }

  void _handleContent(LiveServerContent content) {
    // Extract audio from model turn
    if (content.modelTurn != null) {
      for (final part in content.modelTurn!.parts) {
        if (part is InlineDataPart && part.mimeType.startsWith('audio/')) {
          if (_measuring) {
            _latencyStopwatch.stop();
            lastLatencyMs = _latencyStopwatch.elapsedMilliseconds;
            _latencyTracker.add(lastLatencyMs!);
            _latencyController.add(lastLatencyMs!);
            _measuring = false;
            debugPrint('Response latency: ${lastLatencyMs}ms');
          }
          _audioController.add(part.bytes);
        }
      }
    }

    // Handle transcriptions
    if (content.inputTranscription?.text != null) {
      final text = content.inputTranscription!.text!;
      final isFinal = content.inputTranscription!.finished == true;
      _log('User said: $text (final: $isFinal)');
      _transcriptController.add(
        Transcript(speaker: Speaker.user, text: text, isFinal: isFinal),
      );
    }
    if (content.outputTranscription?.text != null) {
      final text = content.outputTranscription!.text!;
      final isFinal = content.outputTranscription!.finished == true;
      _log('AI said: $text (final: $isFinal)');
      _transcriptController.add(
        Transcript(speaker: Speaker.ai, text: text, isFinal: isFinal),
      );
    }
  }

  void _handleToolCall(LiveServerToolCall toolCall) {
    if (toolCall.functionCalls == null) return;
    for (final call in toolCall.functionCalls!) {
      _toolCallController.add(call);
    }
  }
}

/// Connection states for the Gemini Live session.
enum GeminiLiveState { idle, connecting, active, disconnecting, error }
