import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

// --- Events ---

sealed class VoiceCallEvent extends Equatable {
  const VoiceCallEvent();

  @override
  List<Object?> get props => [];
}

class StartCall extends VoiceCallEvent {
  const StartCall();
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

class _TimerTicked extends VoiceCallEvent {
  const _TimerTicked();
}

// --- State ---

enum VoiceCallStatus { idle, connecting, active, ending, error }

class SavedEntry {
  final JournalCategory category;
  final String text;
  final String transcript;

  const SavedEntry({
    required this.category,
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

  const VoiceCallState({
    this.status = VoiceCallStatus.idle,
    this.transcripts = const [],
    this.savedEntries = const [],
    this.latencyMs,
    this.elapsed = Duration.zero,
    this.error,
  });

  VoiceCallState copyWith({
    VoiceCallStatus? status,
    List<Transcript>? transcripts,
    List<SavedEntry>? savedEntries,
    int? latencyMs,
    Duration? elapsed,
    String? error,
  }) {
    return VoiceCallState(
      status: status ?? this.status,
      transcripts: transcripts ?? this.transcripts,
      savedEntries: savedEntries ?? this.savedEntries,
      latencyMs: latencyMs ?? this.latencyMs,
      elapsed: elapsed ?? this.elapsed,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [status, transcripts, savedEntries, latencyMs, elapsed, error];
}

// --- Bloc ---

/// Tool call argument keys for the save_entry function.
class _SaveEntryArgs {
  static const category = 'category';
  static const text = 'text';
  static const transcript = 'transcript';
}

class VoiceCallBloc extends Bloc<VoiceCallEvent, VoiceCallState> {
  final GeminiLiveService _service;

  StreamSubscription<Transcript>? _transcriptSub;
  StreamSubscription<FunctionCall>? _toolCallSub;
  StreamSubscription<GeminiLiveState>? _stateSub;
  Timer? _elapsedTimer;
  DateTime? _callStartTime;

  /// Audio output stream for the UI to play back.
  Stream<Uint8List> get audioOutputStream => _service.audioStream;

  VoiceCallBloc({required GeminiLiveService service})
      : _service = service,
        super(const VoiceCallState()) {
    on<StartCall>(_onStartCall);
    on<EndCall>(_onEndCall);
    on<TranscriptReceived>(_onTranscriptReceived);
    on<ToolCallReceived>(_onToolCallReceived);
    on<ServiceStateChanged>(_onServiceStateChanged);
    on<LatencyUpdated>(_onLatencyUpdated);
    on<_TimerTicked>(_onTimerTicked);
  }

  Future<void> _onStartCall(
    StartCall event,
    Emitter<VoiceCallState> emit,
  ) async {
    emit(state.copyWith(
      status: VoiceCallStatus.connecting,
      transcripts: [],
      savedEntries: [],
      latencyMs: null,
      elapsed: Duration.zero,
    ));

    // Subscribe to service streams
    _transcriptSub = _service.transcriptStream.listen((transcript) {
      add(TranscriptReceived(transcript));
    });
    _toolCallSub = _service.toolCallStream.listen((call) {
      add(ToolCallReceived(call));
    });
    _stateSub = _service.stateStream.listen((s) {
      add(ServiceStateChanged(s));
      if (_service.lastLatencyMs != null) {
        add(LatencyUpdated(_service.lastLatencyMs!));
      }
    });

    try {
      await _service.connect();
      _callStartTime = DateTime.now();
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_callStartTime != null) {
          add(const _TimerTicked());
        }
      });
    } catch (e) {
      emit(state.copyWith(
        status: VoiceCallStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onEndCall(
    EndCall event,
    Emitter<VoiceCallState> emit,
  ) async {
    _elapsedTimer?.cancel();
    _callStartTime = null;
    await _cancelSubscriptions();
    await _service.disconnect();
    emit(state.copyWith(status: VoiceCallStatus.idle));
  }

  void _onTranscriptReceived(
    TranscriptReceived event,
    Emitter<VoiceCallState> emit,
  ) {
    emit(state.copyWith(
      transcripts: [...state.transcripts, event.transcript],
    ));
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
      final transcript =
          args[_SaveEntryArgs.transcript] as String? ?? '';

      final category = JournalCategory.values.firstWhere(
        (c) => c.name == categoryName,
        orElse: () => JournalCategory.positive,
      );

      final entry = SavedEntry(
        category: category,
        text: text,
        transcript: transcript,
      );

      emit(state.copyWith(
        savedEntries: [...state.savedEntries, entry],
      ));

      // Acknowledge the tool call to the model
      await _service.sendToolResponse(
        call.name,
        call.id,
        {'status': 'saved', _SaveEntryArgs.category: categoryName},
      );

      debugPrint('Tool call: save_entry → $categoryName: $text');
    }
  }

  void _onServiceStateChanged(
    ServiceStateChanged event,
    Emitter<VoiceCallState> emit,
  ) {
    switch (event.state) {
      case GeminiLiveState.active:
        emit(state.copyWith(status: VoiceCallStatus.active));
      case GeminiLiveState.error:
        emit(state.copyWith(
          status: VoiceCallStatus.error,
          error: 'Connection error',
        ));
      case GeminiLiveState.idle:
        emit(state.copyWith(status: VoiceCallStatus.idle));
      default:
        break;
    }
  }

  void _onTimerTicked(
    _TimerTicked event,
    Emitter<VoiceCallState> emit,
  ) {
    final elapsed = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!)
        : Duration.zero;
    emit(state.copyWith(elapsed: elapsed));
  }

  void _onLatencyUpdated(
    LatencyUpdated event,
    Emitter<VoiceCallState> emit,
  ) {
    emit(state.copyWith(latencyMs: event.latencyMs));
  }

  /// Send mic audio to the model. Called by the UI's audio recorder.
  void sendAudio(Uint8List pcmData) {
    _service.sendAudio(pcmData);
  }

  Future<void> _cancelSubscriptions() async {
    await _transcriptSub?.cancel();
    await _toolCallSub?.cancel();
    await _stateSub?.cancel();
    _transcriptSub = null;
    _toolCallSub = null;
    _stateSub = null;
  }

  @override
  Future<void> close() async {
    _elapsedTimer?.cancel();
    await _cancelSubscriptions();
    _service.dispose();
    return super.close();
  }
}
