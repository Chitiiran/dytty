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
import 'package:intl/intl.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String categoryId;

  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final journalBloc = context.read<JournalBloc>();

    return BlocProvider(
      create: (_) => CategoryDetailBloc(
        repository: journalBloc.repository,
      )..add(LoadCategoryDetail(categoryId)),
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
    final questions = reviewQuestions[widget.categoryId] ?? [];
    final entries = _allRecentEntries();
    final prompt = buildReviewPrompt(
      category.displayName,
      questions,
      entries,
    );

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
      for (int i = _processedEntryCount;
          i < voiceState.savedEntries.length;
          i++) {
        final entry = voiceState.savedEntries[i];
        if (entry.categoryId == widget.categoryId) {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          detailBloc.add(EntryAddedFromCall(
            entry: CategoryEntry(
              id: 'call-${DateTime.now().millisecondsSinceEpoch}-$i',
              categoryId: entry.categoryId,
              text: entry.text,
              source: 'voice',
              transcript: entry.transcript,
              createdAt: DateTime.now(),
            ),
            date: today,
          ));
        }
      }
      _processedEntryCount = voiceState.savedEntries.length;
    }

    // Handle call ended — post-call: mark entries reviewed + generate summary
    if (voiceState.status == VoiceCallStatus.ended && !_postCallHandled) {
      _postCallHandled = true;
      setState(() => _callActive = false);
      _performPostCallActions(detailBloc, voiceState);
    }

    // Refresh UI for mute/elapsed changes
    if (mounted) setState(() {});
  }

  /// Post-call: mark all recent entries as reviewed, generate and save review summary.
  Future<void> _performPostCallActions(
    CategoryDetailBloc detailBloc,
    VoiceCallState voiceState,
  ) async {
    final state = detailBloc.state;

    // 1. Mark all recent entries as reviewed
    final entryIds = <String>[];
    final dates = <String>[];
    for (final group in state.recentEntries) {
      for (final entry in group.entries) {
        entryIds.add(entry.id);
        dates.add(group.date);
      }
    }
    if (entryIds.isNotEmpty) {
      detailBloc.add(MarkEntriesReviewed(
        entryIds: entryIds,
        dates: dates,
      ));
    }

    // 2. Generate review summary via LlmService
    if (voiceState.transcripts.isNotEmpty) {
      final llmService = context.read<LlmService>();
      final transcript = voiceState.transcripts
          .map((t) =>
              '${t.speaker == Speaker.user ? "You" : "AI"}: ${t.text}')
          .join('\n');

      final category = JournalCategory.values.firstWhere(
        (c) => c.name == widget.categoryId,
        orElse: () => JournalCategory.positive,
      );
      final questions = reviewQuestions[widget.categoryId] ?? [];

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
          final weekStart = _mondayOfWeek(now);
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

  DateTime _mondayOfWeek(DateTime date) {
    final weekday = date.weekday; // Monday = 1
    return DateTime(date.year, date.month, date.day - (weekday - 1));
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
                          color: const Color(0xFFEF4444),
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
                  onToggleMute: () =>
                      _voiceCallBloc!.add(const ToggleMute()),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _itemCount(state),
      itemBuilder: (context, index) {
        int currentIndex = 0;

        // Review summary card at the top
        if (state.reviewSummary != null) {
          if (index == currentIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ReviewSummaryCard(
                summary: state.reviewSummary!,
                categoryId: widget.categoryId,
              ),
            );
          }
          currentIndex++;
        }

        // Recent entries grouped by date
        for (final group in state.recentEntries) {
          // Date group header
          if (index == currentIndex) {
            return DateGroupHeader(
              displayDate: group.displayDate,
              entryCount: group.entries.length,
              isCollapsed: group.isCollapsed,
              onTap: () {
                context
                    .read<CategoryDetailBloc>()
                    .add(ToggleDateGroup(group.date));
              },
            );
          }
          currentIndex++;

          // Entries (if not collapsed)
          if (!group.isCollapsed) {
            for (final entry in group.entries) {
              if (index == currentIndex) {
                return InlineEntryTile(
                  entry: entry,
                  isEditing: state.editingEntryId == entry.id,
                  onTapEdit: () {
                    context
                        .read<CategoryDetailBloc>()
                        .add(StartInlineEdit(entry.id));
                  },
                  onSaveEdit: (newText) {
                    context.read<CategoryDetailBloc>().add(SaveInlineEdit(
                      date: group.date,
                      entryId: entry.id,
                      newText: newText,
                    ));
                  },
                  onCancelEdit: () {
                    context
                        .read<CategoryDetailBloc>()
                        .add(const CancelInlineEdit());
                  },
                );
              }
              currentIndex++;
            }
          }
        }

        // Older entries (greyed)
        for (final group in state.olderEntries) {
          if (index == currentIndex) {
            return DateGroupHeader(
              displayDate: group.displayDate,
              entryCount: group.entries.length,
              isCollapsed: group.isCollapsed,
              onTap: () {
                context
                    .read<CategoryDetailBloc>()
                    .add(ToggleDateGroup(group.date));
              },
            );
          }
          currentIndex++;

          if (!group.isCollapsed) {
            for (final entry in group.entries) {
              if (index == currentIndex) {
                return InlineEntryTile(
                  entry: entry,
                  isEditing: state.editingEntryId == entry.id,
                  isOlderEntry: true,
                  onTapEdit: () {
                    context
                        .read<CategoryDetailBloc>()
                        .add(StartInlineEdit(entry.id));
                  },
                  onSaveEdit: (newText) {
                    context.read<CategoryDetailBloc>().add(SaveInlineEdit(
                      date: group.date,
                      entryId: entry.id,
                      newText: newText,
                    ));
                  },
                  onCancelEdit: () {
                    context
                        .read<CategoryDetailBloc>()
                        .add(const CancelInlineEdit());
                  },
                );
              }
              currentIndex++;
            }
          }
        }

        return const SizedBox.shrink();
      },
    );
  }

  int _itemCount(CategoryDetailState state) {
    int count = 0;
    if (state.reviewSummary != null) count++;

    for (final group in state.recentEntries) {
      count++; // header
      if (!group.isCollapsed) count += group.entries.length;
    }

    for (final group in state.olderEntries) {
      count++;
      if (!group.isCollapsed) count += group.entries.length;
    }

    return count;
  }
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
      badgeColor = const Color(0xFFEF4444); // red during call
    } else if (hasRecentEntries) {
      badgeColor = Colors.green;
    } else {
      badgeColor = theme.colorScheme.outline;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onCallTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                category.icon,
                color: category.color,
                size: 28,
              ),
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
    );
  }
}
