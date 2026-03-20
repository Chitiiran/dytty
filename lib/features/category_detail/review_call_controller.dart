import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/core/constants/review_prompts.dart';
import 'package:dytty/core/constants/review_questions.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/review_summary.dart';
import 'package:dytty/features/category_detail/bloc/category_detail_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/audio/audio_playback_service.dart';
import 'package:dytty/services/audio/pcm_sound_playback_service.dart';
import 'package:dytty/services/call_session.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';
import 'package:dytty/core/utils/date_utils.dart' as app_date;
import 'package:intl/intl.dart';

/// Manages the review call lifecycle for a category detail screen.
///
/// Extracted from _CategoryDetailViewState to satisfy SRP: the screen
/// renders UI while this controller owns call state and audio plumbing.
class ReviewCallController extends ChangeNotifier {
  // Dependencies (injected)
  final CategoryDetailBloc detailBloc;
  final JournalBloc journalBloc;
  final LlmService llmService;
  final AudioStorageService audioStorage;
  final String? uid;
  final String categoryId;
  final void Function(String message) onError;

  // Testable factory overrides
  final AudioRecorder Function() _recorderFactory;
  final AudioPlaybackService Function() _playbackFactory;
  final GeminiLiveService Function() _geminiServiceFactory;
  final VoiceCallBloc Function({
    required GeminiLiveService service,
    required JournalBloc journalBloc,
    required LlmService llmService,
    required AudioStorageService audioStorage,
    required String? uid,
  })
  _voiceCallBlocFactory;

  // Internal call state
  VoiceCallBloc? _voiceCallBloc;
  GeminiLiveService? _geminiService;
  CallSession? _session;
  StreamSubscription<VoiceCallState>? _voiceStateSub;
  bool _callActive = false;
  int _processedEntryCount = 0;
  bool _postCallHandled = false;
  bool _lastMuted = false;
  Duration? _lastElapsed;
  bool _disposed = false;

  // Public getters
  bool get callActive => _callActive;
  bool get muted => _lastMuted;
  Duration? get elapsed => _lastElapsed;
  VoiceCallBloc? get voiceCallBloc => _voiceCallBloc;

  ReviewCallController({
    required this.detailBloc,
    required this.journalBloc,
    required this.llmService,
    required this.audioStorage,
    this.uid,
    required this.categoryId,
    required this.onError,
    AudioRecorder Function()? recorderFactory,
    AudioPlaybackService Function()? playbackFactory,
    GeminiLiveService Function()? geminiServiceFactory,
    VoiceCallBloc Function({
      required GeminiLiveService service,
      required JournalBloc journalBloc,
      required LlmService llmService,
      required AudioStorageService audioStorage,
      required String? uid,
    })?
    voiceCallBlocFactory,
  }) : _recorderFactory = recorderFactory ?? (() => AudioRecorder()),
       _playbackFactory = playbackFactory ?? (() => PcmSoundPlaybackService()),
       _geminiServiceFactory =
           geminiServiceFactory ?? (() => GeminiLiveService()),
       _voiceCallBlocFactory = voiceCallBlocFactory ?? _defaultBlocFactory;

  static VoiceCallBloc _defaultBlocFactory({
    required GeminiLiveService service,
    required JournalBloc journalBloc,
    required LlmService llmService,
    required AudioStorageService audioStorage,
    required String? uid,
  }) {
    return VoiceCallBloc(
      service: service,
      journalBloc: journalBloc,
      llmService: llmService,
      audioStorage: audioStorage,
      uid: uid,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    cleanup();
    super.dispose();
  }

  /// Releases all call-related resources.
  void cleanup() {
    _voiceStateSub?.cancel();
    _voiceStateSub = null;
    _session?.dispose();
    _session = null;
    _voiceCallBloc?.close();
    _voiceCallBloc = null;
    _geminiService?.dispose();
    _geminiService = null;
  }

  /// Start the review call: request mic permission, set up audio plumbing,
  /// connect to Gemini, and begin streaming.
  Future<void> startCall() async {
    if (_callActive || _disposed) return;

    final recorder = _recorderFactory();
    if (!await recorder.hasPermission()) {
      recorder.dispose();
      return;
    }

    final playback = _playbackFactory();
    final geminiService = _geminiServiceFactory();

    final bloc = _voiceCallBlocFactory(
      service: geminiService,
      journalBloc: journalBloc,
      llmService: llmService,
      audioStorage: audioStorage,
      uid: uid,
    );

    final session = CallSession(
      recorder: recorder,
      playback: playback,
      bloc: bloc,
    );

    _geminiService = geminiService;
    _session = session;
    _voiceCallBloc = bloc;
    _callActive = true;
    _processedEntryCount = 0;
    _postCallHandled = false;
    if (!_disposed) notifyListeners();

    // Listen to voice call state for tool calls and status changes
    _voiceStateSub = bloc.stream.listen(_handleVoiceCallState);

    // Build review-specific prompt
    final category = JournalCategory.values.firstWhere(
      (c) => c.name == categoryId,
      orElse: () => JournalCategory.positive,
    );
    final questions = reviewQuestions[category] ?? [];
    final entries = _allRecentEntries();
    final prompt = buildReviewPrompt(category.displayName, questions, entries);

    // Start the call with review-specific prompt and tools
    bloc.add(const StartCall());

    await session.initPlayback();
    if (_disposed) {
      cleanup();
      return;
    }

    // Connect the service with custom prompt
    try {
      await geminiService.connect(
        systemPrompt: prompt,
        tools: [
          GeminiLiveService.saveEntryDeclaration,
          GeminiLiveService.editEntryDeclaration,
        ],
      );
    } catch (e) {
      if (!_disposed) {
        onError('Failed to start review call: $e');
      }
      await endCall();
      return;
    }

    if (_disposed) {
      cleanup();
      return;
    }

    await session.startRecording();
  }

  void _handleVoiceCallState(VoiceCallState voiceState) {
    if (_disposed) return;

    // Process only newly added entries (avoid re-dispatching on every state change)
    if (voiceState.savedEntries.length > _processedEntryCount) {
      for (
        int i = _processedEntryCount;
        i < voiceState.savedEntries.length;
        i++
      ) {
        final entry = voiceState.savedEntries[i];
        if (entry.categoryId == categoryId) {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          detailBloc.add(
            EntryAddedFromCall(
              entry: CategoryEntry(
                id: 'call-${DateTime.now().millisecondsSinceEpoch}-$i',
                categoryId: entry.categoryId,
                text: entry.text,
                source: 'voice',
                transcript: entry.transcript,
                createdAt: DateTime.now(),
              ),
              date: today,
            ),
          );
        }
      }
      _processedEntryCount = voiceState.savedEntries.length;
    }

    // Handle call ended -- post-call: mark entries reviewed + generate summary
    if (voiceState.status == VoiceCallStatus.ended && !_postCallHandled) {
      _postCallHandled = true;
      _callActive = false;
      notifyListeners();
      _performPostCallActions(voiceState);
      return;
    }

    // Only notify when call controls state actually changed
    if (_callActive) {
      final mutedChanged = voiceState.isMuted != _lastMuted;
      final elapsedChanged = voiceState.elapsed != _lastElapsed;
      if (mutedChanged || elapsedChanged) {
        _lastMuted = voiceState.isMuted;
        _lastElapsed = voiceState.elapsed;
        notifyListeners();
      }
    }
  }

  /// Post-call: mark all recent entries as reviewed, generate and save review summary.
  Future<void> _performPostCallActions(VoiceCallState voiceState) async {
    final state = detailBloc.state;

    // 1. Mark all recent entries as reviewed
    final entries = <EntryReference>[];
    for (final group in state.recentEntries) {
      for (final entry in group.entries) {
        entries.add(EntryReference(date: group.date, entryId: entry.id));
      }
    }
    if (entries.isNotEmpty) {
      detailBloc.add(MarkEntriesReviewed(entries: entries));
    }

    // 2. Generate review summary via LlmService
    if (voiceState.transcripts.isNotEmpty) {
      final transcript = voiceState.transcripts
          .map((t) => '${t.speaker == Speaker.user ? "You" : "AI"}: ${t.text}')
          .join('\n');

      final category = JournalCategory.values.firstWhere(
        (c) => c.name == categoryId,
        orElse: () => JournalCategory.positive,
      );
      final questions = reviewQuestions[category] ?? [];

      try {
        final response = await llmService.generateResponse(
          'You are summarizing a category review call about ${category.displayName} '
          'entries. The review focused on these questions:\n'
          '${questions.map((q) => '- $q').join('\n')}\n\n'
          'Write a warm, personal summary (3-5 sentences) highlighting key themes, '
          'insights, and patterns from the conversation. Use the user\'s own words '
          'when possible. Write in second person ("you").\n\n'
          'Transcript:\n$transcript',
        );

        final summaryText = response.text.trim();
        if (summaryText.isNotEmpty && !_disposed) {
          final now = DateTime.now();
          final weekStart = app_date.mondayOfWeek(now);
          final summary = ReviewSummary(
            id: '',
            categoryId: categoryId,
            weekStart: DateFormat('yyyy-MM-dd').format(weekStart),
            summary: summaryText,
            createdAt: now,
            updatedAt: now,
          );
          detailBloc.add(SaveReviewSummaryEvent(summary));
        }
      } catch (e) {
        if (!_disposed) {
          onError('Failed to generate summary: $e');
        }
      }
    }
  }

  /// Stops recording, cancels audio subscription, and ends the voice call.
  Future<void> endCall() async {
    await _session?.stop();
    _voiceCallBloc?.add(const EndCall());

    _callActive = false;
    if (!_disposed) notifyListeners();
  }

  List<CategoryEntry> _allRecentEntries() {
    final state = detailBloc.state;
    return state.recentEntries.expand((g) => g.entries).toList();
  }
}
