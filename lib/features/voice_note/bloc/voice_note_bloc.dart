import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/speech/speech_service.dart';

// --- Events ---

sealed class VoiceNoteEvent extends Equatable {
  const VoiceNoteEvent();

  @override
  List<Object?> get props => [];
}

class InitializeSpeech extends VoiceNoteEvent {
  const InitializeSpeech();
}

class StartListening extends VoiceNoteEvent {
  const StartListening();
}

class StopListening extends VoiceNoteEvent {
  const StopListening();
}

class _SpeechResultReceived extends VoiceNoteEvent {
  final String text;
  final bool isFinal;

  const _SpeechResultReceived({required this.text, required this.isFinal});

  @override
  List<Object?> get props => [text, isFinal];
}

class CategorizeTranscript extends VoiceNoteEvent {
  const CategorizeTranscript();
}

class UpdateCategory extends VoiceNoteEvent {
  final String categoryId;

  const UpdateCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class UpdateText extends VoiceNoteEvent {
  final String text;

  const UpdateText(this.text);

  @override
  List<Object?> get props => [text];
}

class RequestCategorization extends VoiceNoteEvent {
  const RequestCategorization();
}

class UpdateTranscript extends VoiceNoteEvent {
  final String text;

  const UpdateTranscript(this.text);

  @override
  List<Object?> get props => [text];
}

class ReconcileSummary extends VoiceNoteEvent {
  const ReconcileSummary();
}

class ResetVoiceNote extends VoiceNoteEvent {
  const ResetVoiceNote();
}

// --- State ---

enum VoiceNoteStatus {
  initial,
  ready,
  listening,
  transcriptReview,
  processing,
  reviewing,
  reconciling,
  error,
  unavailable,
}

class VoiceNoteState extends Equatable {
  final VoiceNoteStatus status;
  final String transcript;
  final String originalTranscript;
  final String summary;
  final String? suggestedCategory;
  final List<String> suggestedTags;
  final double confidence;
  final bool transcriptEdited;
  final String? error;

  const VoiceNoteState({
    this.status = VoiceNoteStatus.initial,
    this.transcript = '',
    this.originalTranscript = '',
    this.summary = '',
    this.suggestedCategory,
    this.suggestedTags = const [],
    this.confidence = 0.0,
    this.transcriptEdited = false,
    this.error,
  });

  VoiceNoteState copyWith({
    VoiceNoteStatus? status,
    String? transcript,
    String? originalTranscript,
    String? summary,
    String? suggestedCategory,
    List<String>? suggestedTags,
    double? confidence,
    bool? transcriptEdited,
    String? error,
  }) {
    return VoiceNoteState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      originalTranscript: originalTranscript ?? this.originalTranscript,
      summary: summary ?? this.summary,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      suggestedTags: suggestedTags ?? this.suggestedTags,
      confidence: confidence ?? this.confidence,
      transcriptEdited: transcriptEdited ?? this.transcriptEdited,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    transcript,
    originalTranscript,
    summary,
    suggestedCategory,
    suggestedTags,
    confidence,
    transcriptEdited,
    error,
  ];
}

// --- Bloc ---

class VoiceNoteBloc extends Bloc<VoiceNoteEvent, VoiceNoteState> {
  /// Tag for structured log lines, filterable via `adb logcat`.
  static const _logTag = '[DYTTY]';
  static void _log(String message) => debugPrint('$_logTag $message');

  final SpeechService _speechService;
  final LlmService _llmService;
  final Duration _categorizationTimeout;

  VoiceNoteBloc({
    required SpeechService speechService,
    required LlmService llmService,
    Duration categorizationTimeout = const Duration(seconds: 10),
  }) : _speechService = speechService,
       _llmService = llmService,
       _categorizationTimeout = categorizationTimeout,
       super(const VoiceNoteState()) {
    on<InitializeSpeech>(_onInitializeSpeech);
    on<StartListening>(_onStartListening);
    on<StopListening>(_onStopListening);
    on<_SpeechResultReceived>(_onSpeechResultReceived);
    on<RequestCategorization>(_onRequestCategorization);
    on<CategorizeTranscript>(_onCategorizeTranscript);
    on<UpdateCategory>(_onUpdateCategory);
    on<UpdateText>(_onUpdateText);
    on<UpdateTranscript>(_onUpdateTranscript);
    on<ReconcileSummary>(_onReconcileSummary);
    on<ResetVoiceNote>(_onResetVoiceNote);
  }

  Future<void> _onInitializeSpeech(
    InitializeSpeech event,
    Emitter<VoiceNoteState> emit,
  ) async {
    try {
      final available = await _speechService.initialize();
      emit(
        state.copyWith(
          status: available
              ? VoiceNoteStatus.ready
              : VoiceNoteStatus.unavailable,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: VoiceNoteStatus.error,
          error: 'Failed to initialize speech: $e',
        ),
      );
    }
  }

  Future<void> _onStartListening(
    StartListening event,
    Emitter<VoiceNoteState> emit,
  ) async {
    _log('Voice note state: listening');
    emit(state.copyWith(status: VoiceNoteStatus.listening, transcript: ''));
    await _speechService.startListening(
      onResult: (result) {
        add(
          _SpeechResultReceived(
            text: result.recognizedWords,
            isFinal: result.finalResult,
          ),
        );
      },
    );
  }

  void _onSpeechResultReceived(
    _SpeechResultReceived event,
    Emitter<VoiceNoteState> emit,
  ) {
    _log('User said: ${event.text} (final: ${event.isFinal})');

    // Don't overwrite a valid transcript with empty partials.
    // STT can send empty strings after valid speech when the audio
    // stream ends or silence is detected (#199).
    final text = event.text.isNotEmpty ? event.text : state.transcript;
    emit(state.copyWith(transcript: text));

    if (event.isFinal) {
      if (text.isNotEmpty) {
        _log('Voice note state: transcriptReview');
        emit(state.copyWith(status: VoiceNoteStatus.transcriptReview));
      }
      // If both event.text and state.transcript are empty, stay listening.
    }
  }

  Future<void> _onStopListening(
    StopListening event,
    Emitter<VoiceNoteState> emit,
  ) async {
    _log('Voice note state: stopped');
    await _speechService.stopListening();
    if (state.transcript.isNotEmpty) {
      _log('Voice note state: transcriptReview');
      emit(state.copyWith(status: VoiceNoteStatus.transcriptReview));
    } else {
      emit(state.copyWith(status: VoiceNoteStatus.ready));
    }
  }

  void _onRequestCategorization(
    RequestCategorization event,
    Emitter<VoiceNoteState> emit,
  ) {
    add(const CategorizeTranscript());
  }

  Future<void> _onCategorizeTranscript(
    CategorizeTranscript event,
    Emitter<VoiceNoteState> emit,
  ) async {
    _log('Voice note state: processing');
    emit(state.copyWith(status: VoiceNoteStatus.processing));
    try {
      final result = await _llmService
          .categorizeEntry(state.transcript)
          .timeout(_categorizationTimeout);
      _log('Voice note state: reviewing');
      emit(
        state.copyWith(
          status: VoiceNoteStatus.reviewing,
          originalTranscript: state.transcript,
          summary: result.summary.isNotEmpty
              ? result.summary
              : state.transcript,
          suggestedCategory: result.suggestedCategory,
          suggestedTags: result.suggestedTags,
          confidence: result.confidence,
        ),
      );
    } on TimeoutException {
      // LLM timed out — let user pick category manually
      emit(
        VoiceNoteState(
          status: VoiceNoteStatus.reviewing,
          transcript: state.transcript,
          originalTranscript: state.transcript,
          summary: state.transcript,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: VoiceNoteStatus.error,
          error: 'Failed to categorize: $e',
        ),
      );
    }
  }

  void _onUpdateCategory(UpdateCategory event, Emitter<VoiceNoteState> emit) {
    emit(state.copyWith(suggestedCategory: event.categoryId));
  }

  void _onUpdateText(UpdateText event, Emitter<VoiceNoteState> emit) {
    emit(state.copyWith(summary: event.text));
  }

  void _onUpdateTranscript(
    UpdateTranscript event,
    Emitter<VoiceNoteState> emit,
  ) {
    emit(state.copyWith(transcript: event.text, transcriptEdited: true));
  }

  Future<void> _onReconcileSummary(
    ReconcileSummary event,
    Emitter<VoiceNoteState> emit,
  ) async {
    if (!state.transcriptEdited) return;

    emit(state.copyWith(status: VoiceNoteStatus.reconciling));
    try {
      final reconciled = await _llmService
          .reconcileSummary(state.originalTranscript, state.transcript)
          .timeout(_categorizationTimeout);
      emit(
        state.copyWith(status: VoiceNoteStatus.reviewing, summary: reconciled),
      );
    } on TimeoutException {
      // Fall back to edited transcript as summary
      emit(
        state.copyWith(
          status: VoiceNoteStatus.reviewing,
          summary: state.transcript,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: VoiceNoteStatus.reviewing,
          summary: state.transcript,
        ),
      );
    }
  }

  void _onResetVoiceNote(ResetVoiceNote event, Emitter<VoiceNoteState> emit) {
    _speechService.cancel();
    emit(const VoiceNoteState(status: VoiceNoteStatus.ready));
  }

  @override
  Future<void> close() {
    _speechService.dispose();
    return super.close();
  }
}
