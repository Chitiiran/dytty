import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
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

/// User spoke over the AI; Gemini cancelled its turn (#12).
class InterruptReceived extends VoiceCallEvent {
  const InterruptReceived();
}

/// Post-call holistic reconciliation (#224): re-reads the full transcript and
/// adds items the live model dropped / rewords ones it captured incompletely.
class ReconcileSession extends VoiceCallEvent {
  final String transcript;
  const ReconcileSession({required this.transcript});

  @override
  List<Object?> get props => [transcript];
}

/// User accepted all reconciled entries — clears the post-call AI markers.
class AcceptAllReconciled extends VoiceCallEvent {
  const AcceptAllReconciled();
}

/// User rejected a (usually AI-added) entry from the post-call screen.
class RejectReconciledEntry extends VoiceCallEvent {
  final String entryId;
  const RejectReconciledEntry(this.entryId);

  @override
  List<Object?> get props => [entryId];
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
  final String? entryId; // Firestore id once persisted; null until then
  final String categoryId;
  final String text;
  final String transcript;
  final bool addedByAi; // reconciliation marker: surfaced post-call
  final bool rewordedByAi; // reconciliation marker: reworded post-call

  const SavedEntry({
    required this.categoryId,
    required this.text,
    required this.transcript,
    this.entryId,
    this.addedByAi = false,
    this.rewordedByAi = false,
  });

  SavedEntry copyWith({String? entryId, String? text, bool? rewordedByAi}) =>
      SavedEntry(
        entryId: entryId ?? this.entryId,
        categoryId: categoryId,
        text: text ?? this.text,
        transcript: transcript,
        addedByAi: addedByAi,
        rewordedByAi: rewordedByAi ?? this.rewordedByAi,
      );
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

/// Normalizes text for the mechanical dedup backstop (#224): lowercase, strip
/// punctuation, collapse whitespace. Two entries with the same category and the
/// same normalized text are treated as duplicates.
String normalizeForDedup(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Tagged structured logging for the acoustic test harness (verify.py parses
/// these). Mirrors the `[DYTTY]` tag used by GeminiLiveService.
void _harnessLog(String msg) => debugPrint('[DYTTY] $msg');

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
  final JournalRepository? _journalRepository;
  final LlmService? _llmService;
  final AudioStorageService? _audioStorage;
  final String? _uid;
  bool _reconciled = false; // idempotency guard for ReconcileSession

  StreamSubscription<Transcript>? _transcriptSub;
  StreamSubscription<void>? _interruptSub;
  StreamSubscription<FunctionCall>? _toolCallSub;
  StreamSubscription<GeminiLiveState>? _stateSub;
  StreamSubscription<int>? _latencySub;
  Timer? _elapsedTimer;
  DateTime? _callStartTime;

  /// The session's journal date (yyyy-MM-dd), captured when the call starts so
  /// in-call saves, post-call reconcile, and post-call rejects all write to the
  /// SAME day — even if the call spans midnight or the user acts after the day
  /// rolls over. (#232) Falls back to today when not set (e.g. test seeding).
  String? _sessionDate;
  String get _journalDate =>
      _sessionDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _warned5 = false;
  bool _warned9 = false;

  /// Wiring probe (#224 regression guard): production construction sites must
  /// pass a repository or reconcile/reword silently no-op. The first shipped
  /// version of this feature was dead in production for exactly this reason —
  /// tests injected a mock repo, nothing asserted what the screen constructs.
  @visibleForTesting
  bool get hasJournalRepository => _journalRepository != null;

  /// Test seam: pin the session journal date without a live connect (#232).
  @visibleForTesting
  void debugSetSessionDate(String date) => _sessionDate = date;

  /// Accumulates mic input PCM data during a call for upload after.
  final List<int> _recordedAudio = [];

  /// Recorded audio buffer from the last call (available after EndCall).
  Uint8List? get recordedAudio =>
      _recordedAudio.isEmpty ? null : Uint8List.fromList(_recordedAudio);

  /// Audio output stream for the UI to play back.
  Stream<Uint8List> get audioOutputStream => _service.audioStream;

  /// Barge-in signal (#12): fires when Gemini cancels its turn because the
  /// user spoke over the AI. The audio session flushes playback on this.
  Stream<void> get interruptStream => _service.interruptStream;

  VoiceCallBloc({
    required GeminiLiveService service,
    JournalBloc? journalBloc,
    JournalRepository? journalRepository,
    LlmService? llmService,
    AudioStorageService? audioStorage,
    String? uid,
  }) : _service = service,
       _journalBloc = journalBloc,
       _journalRepository = journalRepository,
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
    on<InterruptReceived>(_onInterruptReceived);
    on<ToggleMute>(_onToggleMute);
    on<ToggleSpeaker>(_onToggleSpeaker);
    on<ReconcileSession>(_onReconcileSession);
    on<AcceptAllReconciled>(_onAcceptAllReconciled);
    on<RejectReconciledEntry>(_onRejectReconciledEntry);
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
    _interruptSub = _service.interruptStream.listen((_) {
      add(const InterruptReceived());
    });

    try {
      await _service.connect(systemPrompt: event.systemPrompt);
      _callStartTime = DateTime.now();
      // Pin the session's journal date now so every save/reconcile/reject in
      // this session writes to the same day, even across midnight. (#232)
      _sessionDate = DateFormat('yyyy-MM-dd').format(_callStartTime!);
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

    // #224: kick off holistic reconciliation now that the call is over and the
    // in-call save_entry writes have settled (each is awaited in
    // _onToolCallReceived, so by here they hold real ids). Runs once.
    final fullTranscript = state.transcripts
        .map((t) => '${t.speaker == Speaker.user ? "You" : "AI"}: ${t.text}')
        .join('\n');
    if (fullTranscript.trim().isNotEmpty) {
      add(ReconcileSession(transcript: fullTranscript));
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

  /// #224: holistic post-call reconciliation. Feeds the full transcript +
  /// already-saved entries to the LLM, applies the returned add/reword tool
  /// calls (with an LLM-aware prompt + a mechanical dedup backstop), and marks
  /// the changes so the post-call screen can surface them.
  Future<void> _onReconcileSession(
    ReconcileSession event,
    Emitter<VoiceCallState> emit,
  ) async {
    if (_reconciled ||
        _llmService == null ||
        _journalRepository == null ||
        event.transcript.trim().isEmpty) {
      return;
    }
    _reconciled = true;

    final List<ReconciledItem> items;
    try {
      final snapshots = state.savedEntries
          .map(
            (e) => SavedEntrySnapshot(
              entryId: e.entryId,
              category: e.categoryId,
              text: e.text,
            ),
          )
          .toList();
      items = await _llmService.reconcileSession(event.transcript, snapshots);
    } catch (e) {
      debugPrint('reconcileSession failed: $e'); // silent no-op
      return;
    }

    final updated = List<SavedEntry>.of(state.savedEntries);
    var addedCount = 0;
    var rewordedCount = 0;
    for (final item in items) {
      if (item.action == ReconcileAction.add) {
        // Mechanical dedup backstop (category + normalized text).
        final dup = updated.any(
          (e) =>
              e.categoryId == item.category &&
              normalizeForDedup(e.text) == normalizeForDedup(item.text),
        );
        if (dup) continue;
        try {
          final created = await _journalRepository.addCategoryEntry(
            _journalDate,
            item.category,
            item.text,
            source: 'voice',
            transcript: item.sourceTranscript,
            tags: const ['voice-call', 'post-call'],
          );
          updated.add(
            SavedEntry(
              entryId: created.id,
              categoryId: item.category,
              text: item.text,
              transcript: item.sourceTranscript,
              addedByAi: true,
            ),
          );
          addedCount++;
          _harnessLog('Entry saved: ${item.category} (origin: reconciled-add)');
        } catch (e) {
          debugPrint('reconcile add failed: $e');
        }
      } else {
        // reword — complete an entry captured incompletely in-call.
        // Guard null id: a reword with no id (or matching another null-id
        // entry) must not reach the `item.entryId!` force-unwrap below. (#232)
        if (item.entryId == null) continue;
        final idx = updated.indexWhere((e) => e.entryId == item.entryId);
        if (idx == -1) continue; // unknown/deleted id — skip
        // Persist to the repository directly (mirrors the add path) so the
        // reword isn't silently lost when _journalBloc is null but the repo is
        // wired; the bloc (if present) also gets it via its stream. (#232)
        // (_journalRepository is already non-null — guarded at method entry.)
        try {
          await _journalRepository.updateCategoryEntry(
            _journalDate,
            item.entryId!,
            item.text,
          );
        } catch (e) {
          debugPrint('reconcile reword failed: $e');
        }
        _journalBloc?.add(UpdateEntry(entryId: item.entryId!, text: item.text));
        updated[idx] = updated[idx].copyWith(
          text: item.text,
          rewordedByAi: true,
        );
        rewordedCount++;
        _harnessLog('Entry reworded: ${updated[idx].categoryId}');
      }
    }
    emit(state.copyWith(savedEntries: updated));
    _harnessLog(
      'Reconciliation complete: $addedCount added, $rewordedCount reworded',
    );
  }

  void _onAcceptAllReconciled(
    AcceptAllReconciled event,
    Emitter<VoiceCallState> emit,
  ) {
    // Entries are already persisted; "Accept all" just clears the AI markers.
    final cleared = state.savedEntries
        .map(
          (e) => SavedEntry(
            entryId: e.entryId,
            categoryId: e.categoryId,
            text: e.text,
            transcript: e.transcript,
          ),
        )
        .toList();
    emit(state.copyWith(savedEntries: cleared));
  }

  Future<void> _onRejectReconciledEntry(
    RejectReconciledEntry event,
    Emitter<VoiceCallState> emit,
  ) async {
    // Remove from the post-call list and tombstone-delete from Firestore.
    final remaining = state.savedEntries
        .where((e) => e.entryId != event.entryId)
        .toList();
    emit(state.copyWith(savedEntries: remaining));
    _journalBloc?.add(DeleteEntry(event.entryId));
    if (_journalRepository != null && _uid != null) {
      try {
        await _journalRepository.deleteCategoryEntry(
          _journalDate,
          event.entryId,
        );
      } catch (e) {
        debugPrint('reject entry delete failed: $e');
      }
    }
  }

  void _onSessionTick(_SessionTick event, Emitter<VoiceCallState> emit) {
    if (_callStartTime == null) return;
    // Never resurrect a terminal call from a stray in-flight tick (#227).
    if (state.status == VoiceCallStatus.error ||
        state.status == VoiceCallStatus.ended) {
      return;
    }
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

    // New bubble when: list is empty, speaker changed, or last bubble is final.
    if (current.isEmpty ||
        current.last.speaker != incoming.speaker ||
        current.last.isFinal) {
      emit(state.copyWith(transcripts: [...current, incoming]));
    } else {
      // #123: Gemini streams transcript as incremental DELTAS, so APPEND the
      // delta to the running bubble rather than replacing it (replacing left
      // only the last fragment visible — truncated speech).
      final updated = List<Transcript>.of(current);
      updated[updated.length - 1] = Transcript(
        speaker: incoming.speaker,
        text: current.last.text + incoming.text,
        isFinal: incoming.isFinal,
      );
      emit(state.copyWith(transcripts: updated));
    }
  }

  void _onInterruptReceived(
    InterruptReceived event,
    Emitter<VoiceCallState> emit,
  ) {
    final current = state.transcripts;
    // If the AI was mid-turn, mark its bubble interrupted + finalize it so the
    // history records that the rest of that response was never heard (#12).
    //
    // Open-mic: the user's partial transcript may have already been appended
    // before the interrupt signal arrives, so the AI bubble isn't necessarily
    // last. Find the most recent AI bubble rather than assuming `current.last`.
    final aiIndex = current.lastIndexWhere((t) => t.speaker == Speaker.ai);
    if (aiIndex != -1 && !current[aiIndex].isFinal) {
      final updated = List<Transcript>.of(current);
      updated[aiIndex] = current[aiIndex].copyWith(
        interrupted: true,
        isFinal: true,
      );
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

      // Capture the Firestore-assigned id so the post-call reconcile pass can
      // issue edit_entry against this entry (#224). When a repository is wired
      // we await it for the real id; otherwise fall back to the fire-and-forget
      // JournalBloc dispatch (preserves prior behavior + test setups).
      String? createdId;
      if (_journalRepository != null) {
        try {
          final created = await _journalRepository.addCategoryEntry(
            _journalDate,
            categoryName,
            text,
            source: 'voice',
            transcript: transcript,
            tags: const ['voice-call'],
          );
          createdId = created.id;
        } catch (e) {
          debugPrint('save_entry repository write failed: $e');
        }
      } else {
        _journalBloc?.add(
          AddVoiceEntry(
            categoryId: categoryName,
            text: text,
            transcript: transcript,
            tags: const ['voice-call'],
            date: DateTime.now(),
          ),
        );
      }

      final entry = SavedEntry(
        entryId: createdId,
        categoryId: categoryName,
        text: text,
        transcript: transcript,
      );

      emit(state.copyWith(savedEntries: [...state.savedEntries, entry]));

      // Acknowledge the tool call to the model
      await _service.sendToolResponse(call.name, call.id, {
        'status': 'saved',
        _SaveEntryArgs.category: categoryName,
      });

      debugPrint('Tool call: save_entry → $categoryName: $text');
      _harnessLog('Entry saved: $categoryName (origin: in-call)');
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
        // #227: tear down the call clock so the periodic tick can't revert the
        // status back to active (which would strand the user in a fake-active
        // call against a dead socket).
        _elapsedTimer?.cancel();
        _callStartTime = null;
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
    await _interruptSub?.cancel();
    _transcriptSub = null;
    _toolCallSub = null;
    _stateSub = null;
    _latencySub = null;
    _interruptSub = null;
  }

  @override
  Future<void> close() async {
    _elapsedTimer?.cancel();
    await _cancelSubscriptions();
    _service.dispose();
    return super.close();
  }
}
