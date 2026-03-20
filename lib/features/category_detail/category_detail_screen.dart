import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/record.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/core/constants/review_prompts.dart';
import 'package:dytty/core/constants/review_questions.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/review_summary.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/category_detail/bloc/category_detail_bloc.dart';
import 'package:dytty/features/category_detail/widgets/call_controls_overlay.dart';
import 'package:dytty/features/category_detail/widgets/date_group_header.dart';
import 'package:dytty/features/category_detail/widgets/empty_category_state.dart';
import 'package:dytty/features/category_detail/widgets/inline_entry_tile.dart';
import 'package:dytty/features/category_detail/widgets/review_summary_card.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/audio/audio_playback_service.dart';
import 'package:dytty/services/audio/pcm_sound_playback_service.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';
import 'package:dytty/core/theme/app_colors.dart';
import 'package:dytty/core/utils/date_utils.dart' as app_date;
import 'package:intl/intl.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String categoryId;

  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final journalBloc = context.read<JournalBloc>();

    return BlocProvider(
      create: (_) =>
          CategoryDetailBloc(repository: journalBloc.repository)
            ..add(LoadCategoryDetail(categoryId)),
      child: _CategoryDetailView(categoryId: categoryId),
    );
  }
}

class _CategoryDetailView extends StatefulWidget {
  final String categoryId;

  const _CategoryDetailView({required this.categoryId});

  @override
  State<_CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends State<_CategoryDetailView> {
  // Call lifecycle
  VoiceCallBloc? _voiceCallBloc;
  GeminiLiveService? _geminiService;
  AudioRecorder? _recorder;
  AudioPlaybackService? _playback;
  StreamSubscription<Uint8List>? _audioOutputSub;
  StreamSubscription<VoiceCallState>? _voiceStateSub;
  bool _callActive = false;
  int _processedEntryCount = 0;
  bool _postCallHandled = false;
  bool _lastMuted = false;
  Duration? _lastElapsed;

  @override
  void dispose() {
    _cleanupCall();
    super.dispose();
  }

  void _cleanupCall() {
    _audioOutputSub?.cancel();
    _audioOutputSub = null;
    _voiceStateSub?.cancel();
    _voiceStateSub = null;
    _recorder?.dispose();
    _recorder = null;
    _playback?.dispose();
    _playback = null;
    _voiceCallBloc?.close();
    _voiceCallBloc = null;
    _geminiService?.dispose();
    _geminiService = null;
  }

  Future<void> _startReviewCall() async {
    // Read context before async gap
    final authState = context.read<AuthBloc>().state;
    final uid = authState is Authenticated ? authState.uid : null;
    final journalBloc = context.read<JournalBloc>();
    final llmService = context.read<LlmService>();
    final audioStorage = context.read<AudioStorageService>();

    final recorder = AudioRecorder();
    if (!await recorder.hasPermission()) {
      recorder.dispose();
      return;
    }

    final geminiService = GeminiLiveService();
    final playback = PcmSoundPlaybackService();

    final bloc = VoiceCallBloc(
      service: geminiService,
      journalBloc: journalBloc,
      llmService: llmService,
      audioStorage: audioStorage,
      uid: uid,
    );

    setState(() {
      _geminiService = geminiService;
      _recorder = recorder;
      _playback = playback;
      _voiceCallBloc = bloc;
      _callActive = true;
      _processedEntryCount = 0;
      _postCallHandled = false;
    });

    // Listen to voice call state for tool calls and status changes
    _voiceStateSub = bloc.stream.listen((voiceState) {
      _handleVoiceCallState(voiceState);
    });

    // Build review-specific prompt
    final category = JournalCategory.values.firstWhere(
      (c) => c.name == widget.categoryId,
      orElse: () => JournalCategory.positive,
    );
    final questions = reviewQuestions[category] ?? [];
    final entries = _allRecentEntries();
    final prompt = buildReviewPrompt(category.displayName, questions, entries);

    // Start the call with review-specific prompt and tools
    bloc.add(const StartCall());

    await playback.init(sampleRate: 24000, channels: 1);

    _audioOutputSub = bloc.audioOutputStream.listen((audioData) {
      try {
        playback.feed(audioData);
      } catch (e) {
        debugPrint('Audio playback feed error: $e');
      }
    });

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
      debugPrint('Review call connect failed: $e');
      _endReviewCall();
      return;
    }

    // Start recording and streaming audio
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    stream.listen((data) {
      bloc.sendAudio(Uint8List.fromList(data));
    });
  }

  void _handleVoiceCallState(VoiceCallState voiceState) {
    if (!mounted) return;

    final detailBloc = context.read<CategoryDetailBloc>();

    // Process only newly added entries (avoid re-dispatching on every state change)
    if (voiceState.savedEntries.length > _processedEntryCount) {
      for (
        int i = _processedEntryCount;
        i < voiceState.savedEntries.length;
        i++
      ) {
        final entry = voiceState.savedEntries[i];
        if (entry.categoryId == widget.categoryId) {
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

    // Handle call ended — post-call: mark entries reviewed + generate summary
    if (voiceState.status == VoiceCallStatus.ended && !_postCallHandled) {
      _postCallHandled = true;
      setState(() => _callActive = false);
      _performPostCallActions(detailBloc, voiceState);
      return;
    }

    // Only rebuild when call controls state actually changed
    if (_callActive && mounted) {
      final mutedChanged = voiceState.isMuted != _lastMuted;
      final elapsedChanged = voiceState.elapsed != _lastElapsed;
      if (mutedChanged || elapsedChanged) {
        _lastMuted = voiceState.isMuted;
        _lastElapsed = voiceState.elapsed;
        setState(() {});
      }
    }
  }

  /// Post-call: mark all recent entries as reviewed, generate and save review summary.
  Future<void> _performPostCallActions(
    CategoryDetailBloc detailBloc,
    VoiceCallState voiceState,
  ) async {
    // Capture context-dependent values before async gap
    final llmService = context.read<LlmService>();
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
        (c) => c.name == widget.categoryId,
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
        if (summaryText.isNotEmpty && mounted) {
          final now = DateTime.now();
          final weekStart = app_date.mondayOfWeek(now);
          final summary = ReviewSummary(
            id: '',
            categoryId: widget.categoryId,
            weekStart: DateFormat('yyyy-MM-dd').format(weekStart),
            summary: summaryText,
            createdAt: now,
            updatedAt: now,
          );
          detailBloc.add(SaveReviewSummaryEvent(summary));
        }
      } catch (e) {
        debugPrint('Failed to generate review summary: $e');
      }
    }
  }

  Future<void> _endReviewCall() async {
    await _recorder?.stop();
    _audioOutputSub?.cancel();
    _audioOutputSub = null;
    await _playback?.stop();
    _voiceCallBloc?.add(const EndCall());

    setState(() => _callActive = false);
  }

  List<CategoryEntry> _allRecentEntries() {
    final state = context.read<CategoryDetailBloc>().state;
    return state.recentEntries.expand((g) => g.entries).toList();
  }

  @override
  Widget build(BuildContext context) {
    final category = JournalCategory.values.firstWhere(
      (c) => c.name == widget.categoryId,
      orElse: () => JournalCategory.positive,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(category.displayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          BlocBuilder<CategoryDetailBloc, CategoryDetailState>(
            buildWhen: (prev, curr) =>
                prev.hasRecentEntries != curr.hasRecentEntries,
            builder: (context, state) {
              return _CallBadge(
                categoryId: widget.categoryId,
                hasRecentEntries: state.hasRecentEntries,
                isCallActive: _callActive,
                onCallTap: state.hasRecentEntries && !_callActive
                    ? _startReviewCall
                    : null,
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<CategoryDetailBloc, CategoryDetailState>(
        builder: (context, state) {
          if (state.status == CategoryDetailStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == CategoryDetailStatus.error) {
            return Center(
              child: Text(
                state.error ?? 'Something went wrong',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          if (state.recentEntries.isEmpty && state.reviewSummary == null) {
            return EmptyCategoryState(categoryId: widget.categoryId);
          }

          return Column(
            children: [
              // Category-color tint during active call
              if (_callActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: category.color.withValues(alpha: 0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.callActiveRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'Review call in progress',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(child: _buildEntryList(context, state)),

              // Call controls at bottom
              if (_callActive && _voiceCallBloc != null)
                CallControlsOverlay(
                  isMuted: _voiceCallBloc!.state.isMuted,
                  onToggleMute: () => _voiceCallBloc!.add(const ToggleMute()),
                  onEndCall: _endReviewCall,
                  elapsed: _voiceCallBloc!.state.elapsed,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEntryList(BuildContext context, CategoryDetailState state) {
    final items = _buildFlatItems(state);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _SummaryItem(:final summary) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ReviewSummaryCard(
              summary: summary,
              categoryId: widget.categoryId,
            ),
          ),
          _HeaderItem(:final group) => DateGroupHeader(
            displayDate: group.displayDate,
            entryCount: group.entries.length,
            isCollapsed: group.isCollapsed,
            onTap: () {
              context.read<CategoryDetailBloc>().add(
                ToggleDateGroup(group.date),
              );
            },
          ),
          _EntryItem(:final entry, :final date, :final isOlder) =>
            InlineEntryTile(
              entry: entry,
              isEditing: state.editingEntryId == entry.id,
              isOlderEntry: isOlder,
              onTapEdit: () {
                context.read<CategoryDetailBloc>().add(
                  StartInlineEdit(entry.id),
                );
              },
              onSaveEdit: (newText) {
                context.read<CategoryDetailBloc>().add(
                  SaveInlineEdit(
                    date: date,
                    entryId: entry.id,
                    newText: newText,
                  ),
                );
              },
              onCancelEdit: () {
                context.read<CategoryDetailBloc>().add(
                  const CancelInlineEdit(),
                );
              },
            ),
        };
      },
    );
  }

  List<_ListItem> _buildFlatItems(CategoryDetailState state) {
    final items = <_ListItem>[];

    if (state.reviewSummary != null) {
      items.add(_SummaryItem(state.reviewSummary!));
    }

    for (final group in state.recentEntries) {
      items.add(_HeaderItem(group));
      if (!group.isCollapsed) {
        for (final entry in group.entries) {
          items.add(_EntryItem(entry: entry, date: group.date));
        }
      }
    }

    for (final group in state.olderEntries) {
      items.add(_HeaderItem(group));
      if (!group.isCollapsed) {
        for (final entry in group.entries) {
          items.add(_EntryItem(entry: entry, date: group.date, isOlder: true));
        }
      }
    }

    return items;
  }
}

/// Flat list items for the heterogeneous entry list.
sealed class _ListItem {}

class _SummaryItem extends _ListItem {
  final ReviewSummary summary;
  _SummaryItem(this.summary);
}

class _HeaderItem extends _ListItem {
  final DateGroup group;
  _HeaderItem(this.group);
}

class _EntryItem extends _ListItem {
  final CategoryEntry entry;
  final String date;
  final bool isOlder;
  _EntryItem({required this.entry, required this.date, this.isOlder = false});
}

/// Call badge icon for the AppBar.
/// Shows red dot during active call, green when entries available, grey when empty.
class _CallBadge extends StatelessWidget {
  final String categoryId;
  final bool hasRecentEntries;
  final bool isCallActive;
  final VoidCallback? onCallTap;

  const _CallBadge({
    required this.categoryId,
    required this.hasRecentEntries,
    required this.isCallActive,
    this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = JournalCategory.values.firstWhere(
      (c) => c.name == categoryId,
      orElse: () => JournalCategory.positive,
    );

    final Color badgeColor;
    if (isCallActive) {
      badgeColor = AppColors.callActiveRed; // red during call
    } else if (hasRecentEntries) {
      badgeColor = Colors.green;
    } else {
      badgeColor = theme.colorScheme.outline;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: isCallActive ? 'Call in progress' : 'Start review call',
        child: InkWell(
          onTap: onCallTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(category.icon, color: category.color, size: 28),
                Positioned(
                  right: 2,
                  bottom: 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
