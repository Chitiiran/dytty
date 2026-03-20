import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/models/review_summary.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/category_detail/bloc/category_detail_bloc.dart';
import 'package:dytty/features/category_detail/review_call_controller.dart';
import 'package:dytty/features/category_detail/widgets/call_controls_overlay.dart';
import 'package:dytty/features/category_detail/widgets/date_group_header.dart';
import 'package:dytty/features/category_detail/widgets/empty_category_state.dart';
import 'package:dytty/features/category_detail/widgets/inline_entry_tile.dart';
import 'package:dytty/features/category_detail/widgets/review_summary_card.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
import 'package:dytty/core/theme/app_colors.dart';

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
  ReviewCallController? _callController;

  @override
  void dispose() {
    _callController?.dispose();
    super.dispose();
  }

  void _startReviewCall() {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is Authenticated ? authState.uid : null;

    _callController = ReviewCallController(
      detailBloc: context.read<CategoryDetailBloc>(),
      journalBloc: context.read<JournalBloc>(),
      llmService: context.read<LlmService>(),
      audioStorage: context.read<AudioStorageService>(),
      uid: uid,
      categoryId: widget.categoryId,
      onError: (message) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );
    _callController!.addListener(() {
      if (mounted) setState(() {});
    });
    _callController!.startCall();
  }

  bool get _callActive => _callController?.callActive ?? false;

  @override
  Widget build(BuildContext context) {
    final category = JournalCategory.values.firstWhere(
      (c) => c.name == widget.categoryId,
      orElse: () => JournalCategory.positive,
    );

    return BlocListener<CategoryDetailBloc, CategoryDetailState>(
      listenWhen: (prev, curr) =>
          curr.error != null &&
          prev.error != curr.error &&
          curr.status != CategoryDetailStatus.error,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
      },
      child: Scaffold(
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

            final voiceBloc = _callController?.voiceCallBloc;

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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),

                Expanded(child: _buildEntryList(context, state)),

                // Call controls at bottom
                if (_callActive && voiceBloc != null)
                  CallControlsOverlay(
                    isMuted: voiceBloc.state.isMuted,
                    onToggleMute: () => voiceBloc.add(const ToggleMute()),
                    onEndCall: () => _callController?.endCall(),
                    elapsed: voiceBloc.state.elapsed,
                  ),
              ],
            );
          },
        ),
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
