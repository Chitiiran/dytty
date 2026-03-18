import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/features/category_detail/bloc/category_detail_bloc.dart';
import 'package:dytty/features/category_detail/widgets/category_detail_header.dart';
import 'package:dytty/features/category_detail/widgets/date_group_header.dart';
import 'package:dytty/features/category_detail/widgets/empty_category_state.dart';
import 'package:dytty/features/category_detail/widgets/inline_entry_tile.dart';
import 'package:dytty/features/category_detail/widgets/review_summary_card.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';

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

class _CategoryDetailView extends StatelessWidget {
  final String categoryId;

  const _CategoryDetailView({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final category = JournalCategory.values.firstWhere(
      (c) => c.name == categoryId,
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
              return CategoryDetailHeader(
                categoryId: categoryId,
                hasRecentEntries: state.hasRecentEntries,
                onCallTap: state.hasRecentEntries ? () {
                  // Phase 5: will wire up review call here
                } : null,
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
            return EmptyCategoryState(categoryId: categoryId);
          }

          return _buildEntryList(context, state);
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
                categoryId: categoryId,
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
