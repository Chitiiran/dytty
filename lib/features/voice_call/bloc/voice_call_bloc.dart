import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
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

class _SessionTick extends VoiceCallEvent {
  const _SessionTick();
}

// --- State ---

enum VoiceCallStatus { idle, connecting, active, ending, ended, error }

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
  final bool showTimeWarning;

  /// Session time limit (Gemini enforces 10 minutes).
  static const sessionLimit = Duration(minutes: 10);
  static const _warningAt5 = Duration(minutes: 5);
  static const _warningAt9 = Duration(minutes: 9);

  const VoiceCallState({
    this.status = VoiceCallStatus.idle,
    this.transcripts = const [],
    this.savedEntries = const [],
    this.latencyMs,
    this.elapsed = Duration.zero,
    this.error,
    this.showTimeWarning = false,
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
  }) {
    return VoiceCallState(
      status: status ?? this.status,
      transcripts: transcripts ?? this.transcripts,
      savedEntries: savedEntries ?? this.savedEntries,
      latencyMs: latencyMs ?? this.latencyMs,
      elapsed: elapsed ?? this.elapsed,
      error: error,
      showTimeWarning: showTimeWarning ?? this.showTimeWarning,
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
      ];
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
  final JournalBloc? _journalBloc;

  StreamSubscription<Transcript>? _transcriptSub;
  StreamSubscription<FunctionCall>? _toolCallSub;
  StreamSubscription<GeminiLiveState>? _stateSub;
  Timer? _elapsedTimer;
  DateTime? _callStartTime;
  bool _warned5 = false;
  bool _warned9 = false;

  /// Audio output stream for the UI to play back.
  Stream<Uint8List> get audioOutputStream => _service.audioStream;

  VoiceCallBloc({
    required GeminiLiveService service,
    JournalBloc? journalBloc,
  })  : _service = service,
        _journalBloc = journalBloc,
        super(const VoiceCallState()) {
    on<StartCall>(_onStartCall);
    on<EndCall>(_onEndCall);
    on<TranscriptReceived>(_onTranscriptReceived);
    on<ToolCallReceived>(_onToolCallReceived);
    on<ServiceStateChanged>(_onServiceStateChanged);
    on<LatencyUpdated>(_onLatencyUpdated);
    on<_SessionTick>(_onSessionTick);
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
      showTimeWarning: false,
    ));
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
      if (_service.lastLatencyMs != null) {
        add(LatencyUpdated(_service.lastLatencyMs!));
      }
    });

    try {
      await _service.connect();
      _callStartTime = DateTime.now();
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        add(const _SessionTick());
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
    emit(state.copyWith(status: VoiceCallStatus.ending));
    _elapsedTimer?.cancel();
    _callStartTime = null;
    await _cancelSubscriptions();
    await _service.disconnect();
    emit(state.copyWith(status: VoiceCallStatus.ended));
  }

  void _onSessionTick(
    _SessionTick event,
    Emitter<VoiceCallState> emit,
  ) {
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

    emit(state.copyWith(
      status: VoiceCallStatus.active,
      elapsed: elapsed,
      showTimeWarning: showWarning,
    ));
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

      // Persist to Firestore via JournalBloc
      _journalBloc?.add(AddVoiceEntry(
        category: category,
        text: text,
        transcript: transcript,
        tags: const ['voice-call'],
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
        if (state.status == VoiceCallStatus.connecting) {
          emit(state.copyWith(status: VoiceCallStatus.active));
        }
      case GeminiLiveState.error:
        emit(state.copyWith(
          status: VoiceCallStatus.error,
          error: 'Connection error',
        ));
      case GeminiLiveState.idle:
        if (state.status == VoiceCallStatus.active) {
          // Server closed the connection (e.g. timeout)
          add(const EndCall());
        }
      default:
        break;
    }
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
