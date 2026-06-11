import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/constants/voice_note_handling.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/speech/speech_service.dart';

export 'package:dytty/core/constants/voice_note_handling.dart'
    show VoiceNoteHandling;

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

/// Save-as-is path (#32): advance to reviewing with the raw transcript
/// as the entry text, skipping the LLM entirely.
class SkipCategorization extends VoiceNoteEvent {
  const SkipCategorization();
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
  final SpeechService _speechService;
  final LlmService _llmService;
  final Duration _categorizationTimeout;
  final VoiceNoteHandling _handling;

  VoiceNoteBloc({
    required SpeechService speechService,
    required LlmService llmService,
    Duration categorizationTimeout = const Duration(seconds: 10),
    VoiceNoteHandling handling = VoiceNoteHandling.ask,
  }) : _speechService = speechService,
       _llmService = llmService,
       _categorizationTimeout = categorizationTimeout,
       _handling = handling,
       super(const VoiceNoteState()) {
    on<InitializeSpeech>(_onInitializeSpeech);
    on<StartListening>(_onStartListening);
    on<StopListening>(_onStopListening);
    on<_SpeechResultReceived>(_onSpeechResultReceived);
    on<RequestCategorization>(_onRequestCategorization);
    on<SkipCategorization>(_onSkipCategorization);
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
    emit(state.copyWith(transcript: event.text));
    if (event.isFinal && event.text.isNotEmpty) {
      _advancePastTranscript(emit);
    }
  }

  /// Routes a finished transcript per the handling preference (#32):
  /// ask pauses at transcriptReview; summarize/raw skip it.
  ///
  /// Called from both the final speech result and StopListening — on
  /// Android the plugin flushes a final result while stopListening is in
  /// flight, so both paths fire back to back. The status guard plus the
  /// synchronous emits below keep that second call a no-op (one LLM call,
  /// no late state clobber).
  void _advancePastTranscript(Emitter<VoiceNoteState> emit) {
    if (state.status != VoiceNoteStatus.listening) return;
    switch (_handling) {
      case VoiceNoteHandling.ask:
        emit(state.copyWith(status: VoiceNoteStatus.transcriptReview));
      case VoiceNoteHandling.summarize:
        emit(state.copyWith(status: VoiceNoteStatus.processing));
        add(const CategorizeTranscript());
      case VoiceNoteHandling.raw:
        emit(_skippedCategorizationState());
    }
  }

  Future<void> _onStopListening(
    StopListening event,
    Emitter<VoiceNoteState> emit,
  ) async {
    await _speechService.stopListening();
    if (state.transcript.isNotEmpty) {
      _advancePastTranscript(emit);
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

  /// Save-as-is (#32): reviewing with the raw transcript as the entry
  /// text and no suggested category — the user picks one manually.
  void _onSkipCategorization(
    SkipCategorization event,
    Emitter<VoiceNoteState> emit,
  ) {
    emit(_skippedCategorizationState());
  }

  /// originalTranscript must be recorded even without an LLM pass —
  /// Re-summarize in reviewing feeds it to reconcileSummary.
  VoiceNoteState _skippedCategorizationState() {
    return state.copyWith(
      status: VoiceNoteStatus.reviewing,
      originalTranscript: state.transcript,
      summary: state.transcript,
    );
  }

  Future<void> _onCategorizeTranscript(
    CategorizeTranscript event,
    Emitter<VoiceNoteState> emit,
  ) async {
    emit(state.copyWith(status: VoiceNoteStatus.processing));
    try {
      final result = await _llmService
          .categorizeEntry(state.transcript)
          .timeout(_categorizationTimeout);
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
    } catch (_) {
      // Any LLM unavailability — timeout, server overload (Gemini 500),
      // network — degrades to raw review: the user's words are never
      // hostage to the model, they just pick the category manually.
      emit(
        VoiceNoteState(
          status: VoiceNoteStatus.reviewing,
          transcript: state.transcript,
          originalTranscript: state.transcript,
          summary: state.transcript,
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
