import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/constants/categories.dart';
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
  final JournalCategory category;

  const UpdateCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class UpdateText extends VoiceNoteEvent {
  final String text;

  const UpdateText(this.text);

  @override
  List<Object?> get props => [text];
}

class ResetVoiceNote extends VoiceNoteEvent {
  const ResetVoiceNote();
}

// --- State ---

enum VoiceNoteStatus {
  initial,
  ready,
  listening,
  processing,
  reviewing,
  error,
  unavailable,
}

class VoiceNoteState extends Equatable {
  final VoiceNoteStatus status;
  final String transcript;
  final String summary;
  final JournalCategory? suggestedCategory;
  final List<String> suggestedTags;
  final double confidence;
  final String? error;

  const VoiceNoteState({
    this.status = VoiceNoteStatus.initial,
    this.transcript = '',
    this.summary = '',
    this.suggestedCategory,
    this.suggestedTags = const [],
    this.confidence = 0.0,
    this.error,
  });

  VoiceNoteState copyWith({
    VoiceNoteStatus? status,
    String? transcript,
    String? summary,
    JournalCategory? suggestedCategory,
    List<String>? suggestedTags,
    double? confidence,
    String? error,
  }) {
    return VoiceNoteState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      suggestedTags: suggestedTags ?? this.suggestedTags,
      confidence: confidence ?? this.confidence,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        transcript,
        summary,
        suggestedCategory,
        suggestedTags,
        confidence,
        error,
      ];
}

// --- Bloc ---

class VoiceNoteBloc extends Bloc<VoiceNoteEvent, VoiceNoteState> {
  final SpeechService _speechService;
  final LlmService _llmService;

  VoiceNoteBloc({
    required SpeechService speechService,
    required LlmService llmService,
  })  : _speechService = speechService,
        _llmService = llmService,
        super(const VoiceNoteState()) {
    on<InitializeSpeech>(_onInitializeSpeech);
    on<StartListening>(_onStartListening);
    on<StopListening>(_onStopListening);
    on<_SpeechResultReceived>(_onSpeechResultReceived);
    on<CategorizeTranscript>(_onCategorizeTranscript);
    on<UpdateCategory>(_onUpdateCategory);
    on<UpdateText>(_onUpdateText);
    on<ResetVoiceNote>(_onResetVoiceNote);
  }

  Future<void> _onInitializeSpeech(
    InitializeSpeech event,
    Emitter<VoiceNoteState> emit,
  ) async {
    try {
      final available = await _speechService.initialize();
      emit(state.copyWith(
        status: available
            ? VoiceNoteStatus.ready
            : VoiceNoteStatus.unavailable,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: VoiceNoteStatus.error,
        error: 'Failed to initialize speech: $e',
      ));
    }
  }

  Future<void> _onStartListening(
    StartListening event,
    Emitter<VoiceNoteState> emit,
  ) async {
    emit(state.copyWith(
      status: VoiceNoteStatus.listening,
      transcript: '',
    ));
    await _speechService.startListening(
      onResult: (result) {
        add(_SpeechResultReceived(
          text: result.recognizedWords,
          isFinal: result.finalResult,
        ));
      },
    );
  }

  void _onSpeechResultReceived(
    _SpeechResultReceived event,
    Emitter<VoiceNoteState> emit,
  ) {
    emit(state.copyWith(transcript: event.text));
    if (event.isFinal && event.text.isNotEmpty) {
      add(const CategorizeTranscript());
    }
  }

  Future<void> _onStopListening(
    StopListening event,
    Emitter<VoiceNoteState> emit,
  ) async {
    await _speechService.stopListening();
    if (state.transcript.isNotEmpty) {
      add(const CategorizeTranscript());
    } else {
      emit(state.copyWith(status: VoiceNoteStatus.ready));
    }
  }

  Future<void> _onCategorizeTranscript(
    CategorizeTranscript event,
    Emitter<VoiceNoteState> emit,
  ) async {
    emit(state.copyWith(status: VoiceNoteStatus.processing));
    try {
      final result = await _llmService.categorizeEntry(state.transcript);
      emit(state.copyWith(
        status: VoiceNoteStatus.reviewing,
        summary: result.summary.isNotEmpty ? result.summary : state.transcript,
        suggestedCategory: result.suggestedCategory,
        suggestedTags: result.suggestedTags,
        confidence: result.confidence,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: VoiceNoteStatus.error,
        error: 'Failed to categorize: $e',
      ));
    }
  }

  void _onUpdateCategory(
    UpdateCategory event,
    Emitter<VoiceNoteState> emit,
  ) {
    emit(state.copyWith(suggestedCategory: event.category));
  }

  void _onUpdateText(
    UpdateText event,
    Emitter<VoiceNoteState> emit,
  ) {
    emit(state.copyWith(summary: event.text));
  }

  void _onResetVoiceNote(
    ResetVoiceNote event,
    Emitter<VoiceNoteState> emit,
  ) {
    _speechService.cancel();
    emit(const VoiceNoteState(status: VoiceNoteStatus.ready));
  }

  @override
  Future<void> close() {
    _speechService.dispose();
    return super.close();
  }
}
