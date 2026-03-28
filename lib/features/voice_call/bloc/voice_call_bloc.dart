import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

// --- Events ---

sealed class VoiceCallEvent extends Equatable {
  const VoiceCallEvent();

  @override
  List<Object?> get props => [];
}

class StartCall extends VoiceCallEvent {
  final String? systemPrompt;
  const StartCall({this.systemPrompt});

  @override
  List<Object?> get props => [systemPrompt];
}

class EndCall extends VoiceCallEvent {
  const EndCall();
}

class TranscriptReceived extends VoiceCallEvent {
  final Transcript transcript;
  const TranscriptReceived(this.transcript);

  @override
  List<Object?> get props => [transcript];
}

class ToolCallReceived extends VoiceCallEvent {
  final FunctionCall functionCall;
  const ToolCallReceived(this.functionCall);

  @override
  List<Object?> get props => [functionCall];
}

class ServiceStateChanged extends VoiceCallEvent {
  final GeminiLiveState state;
  const ServiceStateChanged(this.state);

  @override
  List<Object?> get props => [state];
}

class LatencyUpdated extends VoiceCallEvent {
  final int latencyMs;
  const LatencyUpdated(this.latencyMs);

  @override
  List<Object?> get props => [latencyMs];
}

class _SessionTick extends VoiceCallEvent {
  const _SessionTick();
}

class GenerateSessionSummary extends VoiceCallEvent {
  final List<String> transcripts;
  const GenerateSessionSummary(this.transcripts);

  @override
  List<Object?> get props => [transcripts];
}

class ToggleMute extends VoiceCallEvent {
  const ToggleMute();
}

class ToggleSpeaker extends VoiceCallEvent {
  const ToggleSpeaker();
}

// --- State ---

enum VoiceCallStatus { idle, connecting, active, ending, ended, error }

class SavedEntry {
  final String categoryId;
  final String text;
  final String transcript;

  const SavedEntry({
    required this.categoryId,
    required this.text,
    required this.transcript,
  });
}

class VoiceCallState extends Equatable {
  final VoiceCallStatus status;
  final List<Transcript> transcripts;
  final List<SavedEntry> savedEntries;
  final int? latencyMs;
  final Duration elapsed;
  final String? error;
  final bool showTimeWarning;

  /// Session time limit (Gemini enforces 10 minutes).
  static const sessionLimit = Duration(minutes: 10);
  static const _warningAt5 = Duration(minutes: 5);
  static const _warningAt9 = Duration(minutes: 9);

  final String? audioUrl;
  final bool uploadingAudio;
  final String? sessionSummary;
  final bool generatingSummary;
  final bool isMuted;
  final bool isSpeakerOn;
  final int? latencyP50;
  final int? latencyP95;

  const VoiceCallState({
    this.status = VoiceCallStatus.idle,
    this.transcripts = const [],
    this.savedEntries = const [],
    this.latencyMs,
    this.elapsed = Duration.zero,
    this.error,
    this.showTimeWarning = false,
    this.audioUrl,
    this.uploadingAudio = false,
    this.sessionSummary,
    this.generatingSummary = false,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.latencyP50,
    this.latencyP95,
  });

  Duration get timeRemaining {
    final remaining = sessionLimit - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isNearTimeout => elapsed >= _warningAt9;

  VoiceCallState copyWith({
    VoiceCallStatus? status,
    List<Transcript>? transcripts,
    List<SavedEntry>? savedEntries,
    int? latencyMs,
    Duration? elapsed,
    String? error,
    bool? showTimeWarning,
    String? audioUrl,
    bool? uploadingAudio,
    String? sessionSummary,
    bool? generatingSummary,
    bool? isMuted,
    bool? isSpeakerOn,
    int? latencyP50,
    int? latencyP95,
  }) {
    return VoiceCallState(
      status: status ?? this.status,
      transcripts: transcripts ?? this.transcripts,
      savedEntries: savedEntries ?? this.savedEntries,
      latencyMs: latencyMs ?? this.latencyMs,
      elapsed: elapsed ?? this.elapsed,
      error: error,
      showTimeWarning: showTimeWarning ?? this.showTimeWarning,
      audioUrl: audioUrl ?? this.audioUrl,
      uploadingAudio: uploadingAudio ?? this.uploadingAudio,
      sessionSummary: sessionSummary ?? this.sessionSummary,
      generatingSummary: generatingSummary ?? this.generatingSummary,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      latencyP50: latencyP50 ?? this.latencyP50,
      latencyP95: latencyP95 ?? this.latencyP95,
    );
  }

  @override
  List<Object?> get props => [
    status,
    transcripts,
    savedEntries,
    latencyMs,
    elapsed,
    error,
    showTimeWarning,
    audioUrl,
    uploadingAudio,
    sessionSummary,
    generatingSummary,
    isMuted,
    isSpeakerOn,
    latencyP50,
    latencyP95,
  ];
}

// --- Bloc ---

/// Tool call argument keys for the save_entry function.
class _SaveEntryArgs {
  static const category = 'category';
  static const text = 'text';
  static const transcript = 'transcript';
}

/// Tool call argument keys for the edit_entry function.
class _EditEntryArgs {
  static const entryId = 'entry_id';
  static const text = 'text';
}

class VoiceCallBloc extends Bloc<VoiceCallEvent, VoiceCallState> {
  final GeminiLiveService _service;
  final JournalBloc? _journalBloc;
  final LlmService? _llmService;
  final AudioStorageService? _audioStorage;
  final String? _uid;

  StreamSubscription<Transcript>? _transcriptSub;
  StreamSubscription<FunctionCall>? _toolCallSub;
  StreamSubscription<GeminiLiveState>? _stateSub;
  StreamSubscription<int>? _latencySub;
  Timer? _elapsedTimer;
  DateTime? _callStartTime;
  bool _warned5 = false;
  bool _warned9 = false;

  /// Accumulates mic input PCM data during a call for upload after.
  final List<int> _recordedAudio = [];

  /// Recorded audio buffer from the last call (available after EndCall).
  Uint8List? get recordedAudio =>
      _recordedAudio.isEmpty ? null : Uint8List.fromList(_recordedAudio);

  /// Audio output stream for the UI to play back.
  Stream<Uint8List> get audioOutputStream => _service.audioStream;

  VoiceCallBloc({
    required GeminiLiveService service,
    JournalBloc? journalBloc,
    LlmService? llmService,
    AudioStorageService? audioStorage,
    String? uid,
  }) : _service = service,
       _journalBloc = journalBloc,
       _llmService = llmService,
       _audioStorage = audioStorage,
       _uid = uid,
       super(const VoiceCallState()) {
    on<StartCall>(_onStartCall);
    on<EndCall>(_onEndCall);
    on<TranscriptReceived>(_onTranscriptReceived);
    on<ToolCallReceived>(_onToolCallReceived);
    on<ServiceStateChanged>(_onServiceStateChanged);
    on<LatencyUpdated>(_onLatencyUpdated);
    on<_SessionTick>(_onSessionTick);
    on<GenerateSessionSummary>(_onGenerateSessionSummary);
    on<ToggleMute>(_onToggleMute);
    on<ToggleSpeaker>(_onToggleSpeaker);
  }

  Future<void> _onStartCall(
    StartCall event,
    Emitter<VoiceCallState> emit,
  ) async {
    _recordedAudio.clear();
    emit(
      state.copyWith(
        status: VoiceCallStatus.connecting,
        transcripts: [],
        savedEntries: [],
        latencyMs: null,
        elapsed: Duration.zero,
        showTimeWarning: false,
      ),
    );
    _warned5 = false;
    _warned9 = false;

    // Subscribe to service streams
    _transcriptSub = _service.transcriptStream.listen((transcript) {
      add(TranscriptReceived(transcript));
    });
    _toolCallSub = _service.toolCallStream.listen((call) {
      add(ToolCallReceived(call));
    });
    _stateSub = _service.stateStream.listen((s) {
      add(ServiceStateChanged(s));
    });
    _latencySub = _service.latencyStream.listen((ms) {
      add(LatencyUpdated(ms));
    });

    try {
      await _service.connect(systemPrompt: event.systemPrompt);
      _callStartTime = DateTime.now();
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        add(const _SessionTick());
      });
    } catch (e, stackTrace) {
      debugPrint('VoiceCallBloc: connect failed: $e');
      debugPrint('VoiceCallBloc: stack trace: $stackTrace');
      emit(state.copyWith(status: VoiceCallStatus.error, error: e.toString()));
    }
  }

  Future<void> _onEndCall(EndCall event, Emitter<VoiceCallState> emit) async {
    emit(state.copyWith(status: VoiceCallStatus.ending));
    _elapsedTimer?.cancel();
    _callStartTime = null;

    // Capture latency aggregates before disconnecting
    final p50 = _service.latencyP50;
    final p95 = _service.latencyP95;

    await _cancelSubscriptions();
    await _service.disconnect();

    // Upload recorded audio if storage is configured
    final hasAudio =
        _audioStorage != null && _uid != null && _recordedAudio.isNotEmpty;

    if (hasAudio) {
      emit(
        state.copyWith(
          status: VoiceCallStatus.ended,
          uploadingAudio: true,
          latencyP50: p50,
          latencyP95: p95,
        ),
      );

      try {
        final now = DateTime.now();
        final date = DateFormat('yyyy-MM-dd').format(now);
        final url = await _audioStorage.uploadCallAudio(
          uid: _uid,
          date: date,
          audioData: Uint8List.fromList(_recordedAudio),
        );
        debugPrint('Audio uploaded: $url');
        emit(state.copyWith(audioUrl: url, uploadingAudio: false));
      } catch (e) {
        debugPrint('Failed to upload audio: $e');
        emit(state.copyWith(uploadingAudio: false));
      }
    } else {
      emit(
        state.copyWith(
          status: VoiceCallStatus.ended,
          latencyP50: p50,
          latencyP95: p95,
        ),
      );
    }
  }

  Future<void> _onGenerateSessionSummary(
    GenerateSessionSummary event,
    Emitter<VoiceCallState> emit,
  ) async {
    if (_llmService == null || event.transcripts.isEmpty) return;

    emit(state.copyWith(generatingSummary: true));

    try {
      final transcript = event.transcripts.join('\n');
      final response = await _llmService.generateResponse(
        'You are summarizing a voice journal session between a user and their '
        'AI companion Dytty. Write a warm, personal summary (3-5 sentences) '
        'highlighting key themes, emotions, and insights from the conversation. '
        'Write in second person ("you"). Be concise and insightful.\n\n'
        'Transcript:\n$transcript',
      );

      // Don't show empty summaries (e.g. from NoOpLlmService)
      final summary = response.text.trim();
      if (summary.isNotEmpty) {
        emit(state.copyWith(sessionSummary: summary, generatingSummary: false));
      } else {
        emit(state.copyWith(generatingSummary: false));
      }
    } catch (e) {
      debugPrint('Failed to generate session summary: $e');
      emit(state.copyWith(generatingSummary: false));
    }
  }

  void _onSessionTick(_SessionTick event, Emitter<VoiceCallState> emit) {
    if (_callStartTime == null) return;
    final elapsed = DateTime.now().difference(_callStartTime!);

    // Auto-end at session limit
    if (elapsed >= VoiceCallState.sessionLimit) {
      add(const EndCall());
      return;
    }

    // Time warnings
    bool showWarning = state.showTimeWarning;
    if (!_warned5 && elapsed >= VoiceCallState._warningAt5) {
      _warned5 = true;
      showWarning = true;
      debugPrint('Session warning: 5 minutes remaining');
    }
    if (!_warned9 && elapsed >= VoiceCallState._warningAt9) {
      _warned9 = true;
      showWarning = true;
      debugPrint('Session warning: 1 minute remaining');
    }

    emit(
      state.copyWith(
        status: VoiceCallStatus.active,
        elapsed: elapsed,
        showTimeWarning: showWarning,
      ),
    );
  }

  void _onTranscriptReceived(
    TranscriptReceived event,
    Emitter<VoiceCallState> emit,
  ) {
    final current = state.transcripts;
    final incoming = event.transcript;

    // Append new bubble when: list is empty, speaker changed, or last was final
    if (current.isEmpty ||
        current.last.speaker != incoming.speaker ||
        current.last.isFinal) {
      emit(state.copyWith(transcripts: [...current, incoming]));
    } else {
      // Replace last partial with updated partial/final from same speaker
      final updated = List<Transcript>.of(current);
      updated[updated.length - 1] = incoming;
      emit(state.copyWith(transcripts: updated));
    }
  }

  Future<void> _onToolCallReceived(
    ToolCallReceived event,
    Emitter<VoiceCallState> emit,
  ) async {
    final call = event.functionCall;
    if (call.name == 'save_entry') {
      final args = call.args;
      final categoryName =
          args[_SaveEntryArgs.category] as String? ?? 'positive';
      final text = args[_SaveEntryArgs.text] as String? ?? '';
      final transcript = args[_SaveEntryArgs.transcript] as String? ?? '';

      final entry = SavedEntry(
        categoryId: categoryName,
        text: text,
        transcript: transcript,
      );

      emit(state.copyWith(savedEntries: [...state.savedEntries, entry]));

      // Persist to Firestore via JournalBloc
      _journalBloc?.add(
        AddVoiceEntry(
          categoryId: categoryName,
          text: text,
          transcript: transcript,
          tags: const ['voice-call'],
          date: DateTime.now(),
        ),
      );

      // Acknowledge the tool call to the model
      await _service.sendToolResponse(call.name, call.id, {
        'status': 'saved',
        _SaveEntryArgs.category: categoryName,
      });

      debugPrint('Tool call: save_entry → $categoryName: $text');
    } else if (call.name == 'edit_entry') {
      final args = call.args;
      final entryId = args[_EditEntryArgs.entryId] as String? ?? '';
      final text = args[_EditEntryArgs.text] as String? ?? '';

      // Persist edit via JournalBloc
      if (entryId.isNotEmpty) {
        _journalBloc?.add(UpdateEntry(entryId: entryId, text: text));
      }

      // Acknowledge the tool call to the model
      await _service.sendToolResponse(call.name, call.id, {
        'status': 'edited',
        _EditEntryArgs.entryId: entryId,
      });

      debugPrint('Tool call: edit_entry → $entryId: $text');
    }
  }

  void _onServiceStateChanged(
    ServiceStateChanged event,
    Emitter<VoiceCallState> emit,
  ) {
    switch (event.state) {
      case GeminiLiveState.active:
        if (state.status == VoiceCallStatus.connecting) {
          emit(state.copyWith(status: VoiceCallStatus.active));
        }
      case GeminiLiveState.error:
        emit(
          state.copyWith(
            status: VoiceCallStatus.error,
            error: 'Connection error',
          ),
        );
      case GeminiLiveState.idle:
        if (state.status == VoiceCallStatus.active) {
          // Server closed the connection (e.g. timeout)
          add(const EndCall());
        }
      default:
        break;
    }
  }

  void _onLatencyUpdated(LatencyUpdated event, Emitter<VoiceCallState> emit) {
    emit(state.copyWith(latencyMs: event.latencyMs));
  }

  void _onToggleMute(ToggleMute event, Emitter<VoiceCallState> emit) {
    emit(state.copyWith(isMuted: !state.isMuted));
  }

  void _onToggleSpeaker(ToggleSpeaker event, Emitter<VoiceCallState> emit) {
    emit(state.copyWith(isSpeakerOn: !state.isSpeakerOn));
  }

  /// Send mic audio to the model and accumulate for later upload.
  void sendAudio(Uint8List pcmData) {
    _recordedAudio.addAll(pcmData);
    if (!state.isMuted) {
      _service.sendAudio(pcmData);
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _transcriptSub?.cancel();
    await _toolCallSub?.cancel();
    await _stateSub?.cancel();
    await _latencySub?.cancel();
    _transcriptSub = null;
    _toolCallSub = null;
    _stateSub = null;
    _latencySub = null;
  }

  @override
  Future<void> close() async {
    _elapsedTimer?.cancel();
    await _cancelSubscriptions();
    _service.dispose();
    return super.close();
  }
}
