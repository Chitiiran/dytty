import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/features/voice_note/bloc/voice_note_bloc.dart';
import 'package:dytty/features/voice_note/voice_note_result.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/speech/speech_service.dart';

/// Opens the voice recording bottom sheet. Returns a [VoiceNoteResult] if the
/// user saves, or null if they discard/dismiss.
Future<VoiceNoteResult?> showVoiceRecordingSheet(BuildContext context) {
  return showModalBottomSheet<VoiceNoteResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return BlocProvider(
        create: (_) => VoiceNoteBloc(
          speechService: context.read<SpeechService>(),
          llmService: context.read<LlmService>(),
        )..add(const InitializeSpeech()),
        child: const _VoiceRecordingSheetBody(),
      );
    },
  );
}

class _VoiceRecordingSheetBody extends StatelessWidget {
  const _VoiceRecordingSheetBody();

  @override
  Widget build(BuildContext context) {
    return BlocListener<VoiceNoteBloc, VoiceNoteState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        // Auto-start listening when speech is ready
        if (state.status == VoiceNoteStatus.ready) {
          context.read<VoiceNoteBloc>().add(const StartListening());
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: BlocBuilder<VoiceNoteBloc, VoiceNoteState>(
                builder: (context, state) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTitle(context, state),
                      const SizedBox(height: 24),
                      _buildContent(context, state),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle(BuildContext context, VoiceNoteState state) {
    final theme = Theme.of(context);
    final title = switch (state.status) {
      VoiceNoteStatus.initial => 'Initializing...',
      VoiceNoteStatus.ready => 'Ready to listen',
      VoiceNoteStatus.listening => 'Listening...',
      VoiceNoteStatus.processing => 'Processing...',
      VoiceNoteStatus.reviewing => 'Review your note',
      VoiceNoteStatus.error => 'Something went wrong',
      VoiceNoteStatus.unavailable => 'Speech unavailable',
    };

    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildContent(BuildContext context, VoiceNoteState state) {
    return switch (state.status) {
      VoiceNoteStatus.initial => const _LoadingView(),
      VoiceNoteStatus.ready => const _LoadingView(),
      VoiceNoteStatus.listening => _ListeningView(transcript: state.transcript),
      VoiceNoteStatus.processing =>
        _ProcessingView(transcript: state.transcript),
      VoiceNoteStatus.reviewing => _ReviewingView(state: state),
      VoiceNoteStatus.error =>
        _ErrorView(error: state.error ?? 'Unknown error'),
      VoiceNoteStatus.unavailable => const _UnavailableView(),
    };
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: CircularProgressIndicator(),
    );
  }
}

class _ListeningView extends StatelessWidget {
  final String transcript;

  const _ListeningView({required this.transcript});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Pulsing mic icon
        Semantics(
          label: 'Listening for speech',
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic_rounded,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.15, 1.15),
                duration: 800.ms,
              ),
        ),
        const SizedBox(height: 24),

        // Live transcript
        Semantics(
          label: 'Transcript',
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              transcript.isNotEmpty ? transcript : 'Start speaking...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: transcript.isNotEmpty
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
                fontStyle: transcript.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Done button
        FilledButton.icon(
          onPressed: () {
            context.read<VoiceNoteBloc>().add(const StopListening());
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Done'),
        ),
      ],
    );
  }
}

class _ProcessingView extends StatelessWidget {
  final String transcript;

  const _ProcessingView({required this.transcript});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(transcript, style: theme.textTheme.bodyLarge),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          'Categorizing...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ReviewingView extends StatefulWidget {
  final VoiceNoteState state;

  const _ReviewingView({required this.state});

  @override
  State<_ReviewingView> createState() => _ReviewingViewState();
}

class _ReviewingViewState extends State<_ReviewingView> {
  late TextEditingController _textController;
  bool _transcriptExpanded = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.state.summary);
  }

  @override
  void didUpdateWidget(covariant _ReviewingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.summary != widget.state.summary &&
        _textController.text != widget.state.summary) {
      _textController.text = widget.state.summary;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible transcript
        GestureDetector(
          onTap: () => setState(() => _transcriptExpanded = !_transcriptExpanded),
          child: Row(
            children: [
              Icon(
                _transcriptExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Transcript',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (_transcriptExpanded) ...[
          const SizedBox(height: 8),
          Semantics(
            label: 'Transcript',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.transcript,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Editable summary
        Text(
          'Summary',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            hintText: 'Edit your note...',
          ),
          onChanged: (text) {
            context.read<VoiceNoteBloc>().add(UpdateText(text));
          },
        ),
        const SizedBox(height: 16),

        // Category selection
        Text(
          'Category',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: JournalCategory.values.map((cat) {
            final isSelected = cat == state.suggestedCategory;
            return ChoiceChip(
              label: Text(cat.displayName),
              avatar: Icon(cat.icon, size: 18, color: cat.color),
              selected: isSelected,
              onSelected: (_) {
                context.read<VoiceNoteBloc>().add(UpdateCategory(cat));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Tags
        if (state.suggestedTags.isNotEmpty) ...[
          Text(
            'Tags',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: state.suggestedTags.map((tag) {
              return Chip(
                label: Text(tag),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Action buttons
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Discard'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: state.suggestedCategory != null
                    ? () {
                        Navigator.pop(
                          context,
                          VoiceNoteResult(
                            category: state.suggestedCategory!,
                            text: _textController.text.isNotEmpty
                                ? _textController.text
                                : state.transcript,
                            transcript: state.transcript,
                            tags: state.suggestedTags,
                          ),
                        );
                      }
                    : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(
          error,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            context.read<VoiceNoteBloc>().add(const ResetVoiceNote());
            context.read<VoiceNoteBloc>().add(const InitializeSpeech());
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
        ),
      ],
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          Icons.mic_off_rounded,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'Speech recognition is not supported on this device.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
