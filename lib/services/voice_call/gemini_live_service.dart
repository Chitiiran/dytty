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

  /// True when this AI turn was cut short by the user speaking over it (#12).
  /// The displayed text may be more than the user actually heard.
  final bool interrupted;

  const Transcript({
    required this.speaker,
    required this.text,
    this.isFinal = true,
    this.interrupted = false,
  });

  Transcript copyWith({bool? isFinal, bool? interrupted}) => Transcript(
    speaker: speaker,
    text: text,
    isFinal: isFinal ?? this.isFinal,
    interrupted: interrupted ?? this.interrupted,
  );
}

/// Builds the live generation config (#231). Extracted as a top-level factory
/// for test visibility.
///
/// Tunes for a calmer, shorter "best friend" delivery using the generation
/// params the Gemini Live BACKEND accepts: lower [temperature] and a
/// [maxOutputTokens] cap to force short turns.
///
/// NOTE: `presencePenalty` / `frequencyPenalty` exist on the firebase_ai
/// `LiveGenerationConfig` class but the Live API backend REJECTS them — it
/// closes the socket with code 1007 ("presence_penalty not supported in
/// generation config"). Device-verified 2026-06-16. Do not re-add them here;
/// they are not reachable on the live path (same class of SDK-vs-backend gap
/// as `candidateCount`). Proactive audio / VAD silence tuning also need the
/// raw-WebSocket path (#228).
LiveGenerationConfig buildLiveGenerationConfig() => LiveGenerationConfig(
  responseModalities: [ResponseModalities.audio],
  inputAudioTranscription: AudioTranscriptionConfig(),
  outputAudioTranscription: AudioTranscriptionConfig(),
  speechConfig: SpeechConfig(voiceName: 'Aoede'),
  temperature: 0.7,
  maxOutputTokens: 300,
);

/// Wraps the Firebase AI Live API for bidirectional voice streaming.
///
/// Manages session lifecycle, audio I/O, tool calling, and latency tracking.
class GeminiLiveService {
  /// Live audio model. Upgraded 2026-06-16 from
  /// `gemini-2.5-flash-native-audio-preview-12-2025`, which has a confirmed
  /// Google bug: it generates audio and calls a tool simultaneously, so the
  /// backend closes the socket with WebSocket 1008 ("Operation is not
  /// implemented") at the first tool-using turn — killing the daily call
  /// before any save/reconcile (device-diagnosed under #231). Google's own
  /// fix is the 3.1 Flash Live model, which sequences tool-call after audio.
  /// Note: 3.1 does NOT support proactive-audio / affective-dialog / VAD
  /// config (those are 2.5-native-audio only); we don't use them here (#228).
  /// If daily call breaks with 1008 "model not found", check:
  /// https://firebase.google.com/docs/ai-logic/models
  static const _model = 'gemini-3.1-flash-live-preview';

  /// Tag used for structured log lines, filterable via `adb logcat`.
  static const _logTag = '[DYTTY]';

  /// Connection timeout for the initial Gemini Live session.
  static const connectionTimeout = Duration(seconds: 15);

  LiveSession? _session;

  final _audioController = StreamController<Uint8List>.broadcast();
  final _transcriptController = StreamController<Transcript>.broadcast();
  final _toolCallController = StreamController<FunctionCall>.broadcast();
  final _stateController = StreamController<GeminiLiveState>.broadcast();
  final _interruptController = StreamController<void>.broadcast();

  /// Audio chunks received from the model (PCM 24kHz 16-bit LE mono).
  Stream<Uint8List> get audioStream => _audioController.stream;

  /// Fires when Gemini reports it cancelled its own generation because the
  /// user spoke over the AI (server-side barge-in, #12). The UI must stop and
  /// flush any buffered AI audio on this signal — the model generates audio
  /// faster than it plays, so there is always more queued than the user heard.
  Stream<void> get interruptStream => _interruptController.stream;

  /// How long to suppress mic-send after a barge-in (#12 Tier 1).
  ///
  /// On interrupt we've yielded the floor to the user, but the AI's speaker
  /// audio keeps decaying for a few hundred ms (hardware + OS pipeline) and the
  /// open mic captures it — Gemini then transcribes that echo as phantom user
  /// input. Suppressing sends for this window absorbs the tail. Kept short so
  /// the user's actual speech (which Gemini captured *before* the interrupt)
  /// isn't lost. Deterministic suppression needs the raw API (#228).
  static const postInterruptSuppression = Duration(milliseconds: 400);

  Timer? _suppressTimer;
  bool _micSuppressed = false;

  /// Whether mic-send is currently suppressed by the post-interrupt window.
  bool get isMicSuppressed => _micSuppressed;

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

  /// Monotonic clock for latency measurement (injectable for tests).
  ///
  /// Returns elapsed milliseconds from an arbitrary fixed origin.
  final int Function() _nowMs;

  final LatencyTracker _latencyTracker = LatencyTracker();
  bool _modelTurnComplete = true;
  bool _measuring = false;

  /// Timestamp of the user's most recent mic chunk this turn (#223).
  ///
  /// Latency is measured end-of-user-speech -> first-AI-audio, so we anchor to
  /// the LATEST user chunk (updated on every send), not the first. Measuring
  /// from the first chunk inflates latency by the whole utterance + Gemini's
  /// VAD silence wait.
  int? _userLastChunkMs;

  /// [nowMs] is an injectable monotonic clock (ms) for deterministic latency
  /// tests; defaults to a process-wide stopwatch.
  GeminiLiveService({int Function()? nowMs})
    : _nowMs = nowMs ?? (() => _defaultClock.elapsedMilliseconds);

  static final Stopwatch _defaultClock = Stopwatch()..start();

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
    _userLastChunkMs = null;
    lastLatencyMs = null;
    _suppressTimer?.cancel();
    _micSuppressed = false;

    final effectivePrompt = systemPrompt ?? dailyCallSystemPrompt;
    final effectiveTools = tools ?? [call_tools.saveEntryDeclaration];

    try {
      final liveModel = FirebaseAI.googleAI().liveGenerativeModel(
        model: _model,
        liveGenerationConfig: buildLiveGenerationConfig(),
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
    // Drop mic audio during the post-interrupt echo-tail window (#12 Tier 1).
    if (_micSuppressed) return;
    if (_modelTurnComplete) {
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
    _suppressTimer?.cancel();
    // #246: disposing mid-call (bloc closed / screen popped) leaked the live
    // Gemini connection — null first so the receive loop breaks, then close.
    final session = _session;
    _session = null;
    session?.close();
    _audioController.close();
    _transcriptController.close();
    _toolCallController.close();
    _stateController.close();
    _latencyController.close();
    _interruptController.close();
  }

  /// Test seam: inject a session double so dispose/disconnect paths are
  /// testable without a live Firebase connection (mirrors markClosedForTest).
  @visibleForTesting
  void debugSetSession(LiveSession session) => _session = session;

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
      // #227: the socket is dead (e.g. WebSocket 1008). Null the session so
      // sendAudio no-ops instead of throwing into the closed socket every tick.
      _session = null;
      _emitState(GeminiLiveState.error);
      return;
    }
    // If we exit the while loop, session was set to null (graceful disconnect)
    // Don't emit idle here — disconnect() already handles that
  }

  void _handleContent(LiveServerContent content) {
    // Server-side barge-in (#12): Gemini cancelled its generation because the
    // user spoke over the AI. Surface it so the UI flushes buffered audio.
    if (content.interrupted == true) {
      _emitInterrupt();
    }

    // Extract audio from model turn
    if (content.modelTurn != null) {
      for (final part in content.modelTurn!.parts) {
        if (part is InlineDataPart && part.mimeType.startsWith('audio/')) {
          if (_measuring && _userLastChunkMs != null) {
            final latency = _nowMs() - _userLastChunkMs!;
            lastLatencyMs = latency;
            _latencyTracker.add(latency);
            _latencyController.add(latency);
            _measuring = false;
            debugPrint('Response latency: ${latency}ms');
          }
          emitAudioChunk(part.bytes);
        }
      }
    }

    // Handle transcriptions
    if (content.inputTranscription?.text != null) {
      final text = content.inputTranscription!.text!;
      final isFinal = content.inputTranscription!.finished == true;
      _log('User said: $text (final: $isFinal)');
      // Anchor latency to the user's latest RECOGNIZED speech, not raw mic
      // chunks — with the mic always open (#12), the last chunk sent is just
      // "now", but input transcription only fires on actual speech, so it
      // marks true end-of-speech (#223).
      if (_measuring) _userLastChunkMs = _nowMs();
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

  /// Emit a received audio chunk to [audioStream], logging its size.
  ///
  /// The `[DYTTY] Audio chunk received: N bytes` line lets device logcat
  /// confirm the model is actually sending audio (diagnostic from #222).
  @visibleForTesting
  void emitAudioChunk(Uint8List bytes) {
    _log('Audio chunk received: ${bytes.length} bytes');
    _audioController.add(bytes);
  }

  void _emitInterrupt() {
    _log('Interrupted by user (server-side barge-in)');
    // Yield the floor: suppress mic-send so the AI's decaying speaker tail
    // isn't streamed back and transcribed as phantom user input (#12 Tier 1).
    _micSuppressed = true;
    _suppressTimer?.cancel();
    _suppressTimer = Timer(postInterruptSuppression, () {
      _micSuppressed = false;
    });
    // The interrupted turn ends here (no clean `turnComplete` will arrive), so
    // re-arm measurement for the next turn — otherwise interrupted (contested)
    // turns would be silently dropped from latency stats (#223).
    _modelTurnComplete = true;
    _measuring = false;
    _interruptController.add(null);
  }

  /// Test seam mirroring [emitAudioChunk] — drives [interruptStream] without a
  /// live session (the server interrupt arrives inside [_handleContent]).
  @visibleForTesting
  void handleInterruptForTest() => _emitInterrupt();

  /// Test seam: simulate the receive loop nulling the session on a socket
  /// close (#227), so [sendAudio] becomes a no-op.
  @visibleForTesting
  void markClosedForTest() => _session = null;

  /// Test seam: record recognized user speech for latency (#223), without a
  /// live session. Mirrors the input-transcription path in [_handleContent].
  @visibleForTesting
  void noteUserAudioForTest() {
    // sendAudio arms measuring on the first mic chunk; recognized speech then
    // anchors the end-of-speech timestamp.
    if (_modelTurnComplete) {
      _modelTurnComplete = false;
      _measuring = true;
    }
    if (_measuring) _userLastChunkMs = _nowMs();
  }

  /// Test seam: record the AI's first audio chunk for latency (#223). Mirrors
  /// the measurement path in [_handleContent].
  @visibleForTesting
  void noteAiAudioForTest() {
    if (_measuring && _userLastChunkMs != null) {
      final latency = _nowMs() - _userLastChunkMs!;
      lastLatencyMs = latency;
      _latencyTracker.add(latency);
      _measuring = false;
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
