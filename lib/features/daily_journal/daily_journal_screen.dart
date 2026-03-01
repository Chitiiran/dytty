import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/core/theme/app_colors.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/core/widgets/shimmer_loading.dart';
import 'package:dytty/features/daily_journal/journal_provider.dart';
import 'package:dytty/features/daily_journal/widgets/entry_bottom_sheet.dart';

String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dateTime);
}

class DailyJournalScreen extends StatefulWidget {
  const DailyJournalScreen({super.key});

  @override
  State<DailyJournalScreen> createState() => _DailyJournalScreenState();
}

class _DailyJournalScreenState extends State<DailyJournalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<JournalProvider>();
      if (provider.entries.isEmpty && !provider.loading) {
        provider.loadEntries();
      }
    });
  }

  Future<void> _addEntry(
    JournalProvider provider,
    JournalCategory category,
    String text,
  ) async {
    await provider.addEntry(category, text);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entry added')));
    }
  }

  Future<void> _updateEntry(
    JournalProvider provider,
    String entryId,
    String text,
  ) async {
    await provider.updateEntry(entryId, text);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entry updated')));
    }
  }

  void _deleteEntryOptimistic(JournalProvider provider, CategoryEntry entry) {
    // Optimistic delete: remove immediately, offer undo
    provider.deleteEntry(entry.id);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Re-add the entry
            provider.addEntry(entry.category, entry.text);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _navigateDay(JournalProvider provider, int delta) {
    final newDate = provider.selectedDate.add(Duration(days: delta));
    provider.selectDate(newDate);
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final theme = Theme.of(context);
    final selectedDate = journalProvider.selectedDate;
    final dayOfWeek = DateFormat('EEEE').format(selectedDate);
    final dateStr = DateFormat('MMMM d, yyyy').format(selectedDate);
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    final allEmpty = JournalCategory.values.every(
      (c) => journalProvider.entriesForCategory(c).isEmpty,
    );

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Journal date',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? 'Today' : dayOfWeek,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                dateStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _navigateDay(journalProvider, -1),
            tooltip: 'Previous day',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _navigateDay(journalProvider, 1),
            tooltip: 'Next day',
          ),
        ],
      ),
      body: journalProvider.loading
          ? const ShimmerJournalLoading()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: AnimationLimiter(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (allEmpty && !journalProvider.loading)
                        _EmptyDayBanner()
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1, end: 0, duration: 400.ms),
                      ...JournalCategory.values.asMap().entries.map((mapEntry) {
                        final index = mapEntry.key;
                        final category = mapEntry.value;
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 30,
                            child: FadeInAnimation(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CategoryCard(
                                  category: category,
                                  entries: journalProvider.entriesForCategory(
                                    category,
                                  ),
                                  onAdd: (text) => _addEntry(
                                    journalProvider,
                                    category,
                                    text,
                                  ),
                                  onEdit: (entryId, text) => _updateEntry(
                                    journalProvider,
                                    entryId,
                                    text,
                                  ),
                                  onDelete: (entry) => _deleteEntryOptimistic(
                                    journalProvider,
                                    entry,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyDayBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time to reflect',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap + on any category to start writing.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final JournalCategory category;
  final List<CategoryEntry> entries;
  final ValueChanged<String> onAdd;
  final Future<void> Function(String entryId, String text) onEdit;
  final void Function(CategoryEntry entry) onDelete;

  const _CategoryCard({
    required this.category,
    required this.entries,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final surfaceColor = AppColors.categorySurface(category.name, brightness);

    return Semantics(
      label: '${category.displayName} category',
      child: Card(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: category.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tinted header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(category.icon, size: 18, color: category.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entries.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entries.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: category.color,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () => _showAddSheet(context),
                    tooltip: 'Add ${category.displayName} entry',
                    color: category.color,
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entries.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        category.prompt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                  ...entries.map(
                    (entry) => _EntryTile(
                      entry: entry,
                      category: category,
                      onEdit: (text) => onEdit(entry.id, text),
                      onDelete: () => onDelete(entry),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) async {
    final text = await showEntryBottomSheet(context, category: category);
    if (text != null) {
      onAdd(text);
    }
  }
}

class _EntryTile extends StatelessWidget {
  final CategoryEntry entry;
  final JournalCategory category;
  final ValueChanged<String> onEdit;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Journal entry: ${entry.text}',
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: theme.colorScheme.error,
          ),
        ),
        child: GestureDetector(
          onLongPress: () => _showContextMenu(context),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.text, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        formatRelativeTime(entry.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: () => _showEditSheet(context),
                  tooltip: 'Edit entry',
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onDelete,
                  tooltip: 'Delete entry',
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditSheet(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) async {
    final text = await showEntryBottomSheet(
      context,
      category: category,
      initialText: entry.text,
    );
    if (text != null) {
      onEdit(text);
    }
  }
}
