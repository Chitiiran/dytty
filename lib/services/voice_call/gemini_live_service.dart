import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Speaker in a voice call transcript.
enum Speaker { user, ai }

/// A structured transcript entry with speaker and text.
class Transcript {
  final Speaker speaker;
  final String text;

  const Transcript({required this.speaker, required this.text});
}

/// Wraps the Firebase AI Live API for bidirectional voice streaming.
///
/// Manages session lifecycle, audio I/O, tool calling, and latency tracking.
class GeminiLiveService {
  static const _model = 'gemini-2.5-flash-native-audio-preview-12-2025';

  LiveSession? _session;
  StreamSubscription<LiveServerResponse>? _responseSubscription;

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

  /// Timestamp when the user's last audio chunk was sent (for latency measurement).
  DateTime? _lastUserAudioSent;

  /// Timestamp when first model audio was received after user turn.
  DateTime? _firstModelAudioReceived;

  /// Last measured response latency in milliseconds.
  int? lastLatencyMs;

  /// Connect to the Gemini Live API and start a session.
  Future<void> connect() async {
    _stateController.add(GeminiLiveState.connecting);

    try {
      final liveModel = FirebaseAI.googleAI().liveGenerativeModel(
        model: _model,
        liveGenerationConfig: LiveGenerationConfig(
          responseModalities: [ResponseModalities.audio],
          inputAudioTranscription: AudioTranscriptionConfig(),
          outputAudioTranscription: AudioTranscriptionConfig(),
          speechConfig: SpeechConfig(voiceName: 'Aoede'),
        ),
        systemInstruction: Content.text(_systemPrompt),
        tools: [
          Tool.functionDeclarations([_saveEntryDeclaration]),
        ],
      );

      _session = await liveModel.connect();
      _listenToResponses();
      _stateController.add(GeminiLiveState.active);
    } catch (e) {
      _stateController.add(GeminiLiveState.error);
      rethrow;
    }
  }

  /// Send a PCM audio chunk to the model.
  ///
  /// Audio format: 16-bit PCM, 16kHz, mono, little-endian.
  void sendAudio(Uint8List pcmData) {
    if (_session == null) return;
    _lastUserAudioSent = DateTime.now();
    _firstModelAudioReceived = null;
    _session!.sendAudioRealtime(InlineDataPart('audio/pcm', pcmData));
  }

  /// Send a text message to the model.
  Future<void> sendText(String text) async {
    if (_session == null) return;
    await _session!.send(
      input: Content.text(text),
      turnComplete: true,
    );
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
    _stateController.add(GeminiLiveState.disconnecting);
    await _responseSubscription?.cancel();
    _responseSubscription = null;
    await _session?.close();
    _session = null;
    _stateController.add(GeminiLiveState.idle);
  }

  void dispose() {
    _audioController.close();
    _transcriptController.close();
    _toolCallController.close();
    _stateController.close();
  }

  void _listenToResponses() {
    // Listen on the broadcast stream from the session's message controller
    // rather than receive() which stops at turnComplete.
    _responseSubscription =
        _session!.receive().listen(
      (response) {
        final message = response.message;

        if (message is LiveServerContent) {
          _handleContent(message);
        } else if (message is LiveServerToolCall) {
          _handleToolCall(message);
        } else if (message is GoingAwayNotice) {
          debugPrint(
              'Gemini session ending soon: ${message.timeLeft} remaining');
        }
      },
      onError: (error) {
        debugPrint('Gemini Live stream error: $error');
        _stateController.add(GeminiLiveState.error);
      },
      onDone: () {
        _stateController.add(GeminiLiveState.idle);
      },
    );
  }

  void _handleContent(LiveServerContent content) {
    // Extract audio from model turn
    if (content.modelTurn != null) {
      for (final part in content.modelTurn!.parts) {
        if (part is InlineDataPart && part.mimeType.startsWith('audio/')) {
          // Measure latency: time from last user audio to first model audio
          if (_firstModelAudioReceived == null && _lastUserAudioSent != null) {
            _firstModelAudioReceived = DateTime.now();
            lastLatencyMs = _firstModelAudioReceived!
                .difference(_lastUserAudioSent!)
                .inMilliseconds;
            debugPrint('Response latency: ${lastLatencyMs}ms');
          }
          _audioController.add(part.bytes);
        }
      }
    }

    // Handle transcriptions
    if (content.inputTranscription?.text != null) {
      _transcriptController.add(Transcript(
        speaker: Speaker.user,
        text: content.inputTranscription!.text!,
      ));
    }
    if (content.outputTranscription?.text != null) {
      _transcriptController.add(Transcript(
        speaker: Speaker.ai,
        text: content.outputTranscription!.text!,
      ));
    }
  }

  void _handleToolCall(LiveServerToolCall toolCall) {
    if (toolCall.functionCalls == null) return;
    for (final call in toolCall.functionCalls!) {
      _toolCallController.add(call);
    }
  }

  static final _saveEntryDeclaration = FunctionDeclaration(
    'save_entry',
    'Save a journal entry for the user. Call this when the user shares '
        'something they want to remember — a thought, feeling, experience, or '
        'reflection. Categorize it into the most appropriate category.',
    parameters: {
      'category': Schema.enumString(
        enumValues: ['positive', 'negative', 'gratitude', 'beauty', 'identity'],
        description: 'The journal category that best fits this entry.',
      ),
      'text': Schema.string(
        description: 'A concise summary of what the user shared, written in '
            'first person as if the user wrote it.',
      ),
      'transcript': Schema.string(
        description:
            'The raw transcript of what the user said that led to this entry.',
      ),
    },
  );

  static const _systemPrompt = '''
You are a warm, encouraging best friend helping the user reflect on their day
through a natural voice conversation. Your name is Dytty.

Your role:
- Ask open-ended questions about their day
- Listen actively and respond with empathy
- When they share something meaningful, use the save_entry tool to capture it
- Guide them through 5 reflection categories: positive experiences, negative
  experiences, gratitude, beauty they noticed, and identity/growth moments
- Keep the conversation natural — don't interrogate or rush through categories
- If they seem done with a topic, gently transition to the next
- End the session warmly when they indicate they're finished

Tone: warm, casual, genuinely interested. Like talking to a close friend who
really listens. Use short sentences. Don't be overly enthusiastic or fake.

Important: This is a VOICE conversation. Keep responses brief and natural.
Avoid long monologues. Ask one question at a time.
''';
}

/// Connection states for the Gemini Live session.
enum GeminiLiveState {
  idle,
  connecting,
  active,
  disconnecting,
  error,
}
