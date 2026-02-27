import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/features/daily_journal/journal_provider.dart';

class DailyJournalScreen extends StatefulWidget {
  const DailyJournalScreen({super.key});

  @override
  State<DailyJournalScreen> createState() => _DailyJournalScreenState();
}

class _DailyJournalScreenState extends State<DailyJournalScreen> {
  @override
  void initState() {
    super.initState();
    // Load entries if not already loaded by selectDate() from HomeScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<JournalProvider>();
      if (provider.entries.isEmpty && !provider.loading) {
        provider.loadEntries();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final dateStr =
        DateFormat('EEEE, MMMM d').format(journalProvider.selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Journal date',
          child: Text(dateStr),
        ),
      ),
      body: journalProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: JournalCategory.values
                  .map((category) => _CategoryCard(
                        category: category,
                        entries: journalProvider.entriesForCategory(category),
                        onAdd: (text) =>
                            journalProvider.addEntry(category, text),
                        onEdit: journalProvider.updateEntry,
                        onDelete: journalProvider.deleteEntry,
                      ))
                  .toList(),
            ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final JournalCategory category;
  final List<CategoryEntry> entries;
  final ValueChanged<String> onAdd;
  final Future<void> Function(String entryId, String text) onEdit;
  final Future<void> Function(String entryId) onDelete;

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

    return Semantics(
      label: '${category.displayName} category',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    category.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Add ${category.displayName} entry',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _showAddDialog(context),
                      tooltip: 'Add entry',
                    ),
                  ),
                ],
              ),
              Text(
                category.prompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...entries.map((entry) => _EntryTile(
                      entry: entry,
                      onEdit: (text) => onEdit(entry.id, text),
                      onDelete: () => onDelete(entry.id),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${category.displayName}'),
        content: Semantics(
          label: 'Entry text',
          textField: true,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: category.prompt,
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          Semantics(
            label: 'Save entry',
            button: true,
            child: FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  onAdd(text);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}

class _EntryTile extends StatelessWidget {
  final CategoryEntry entry;
  final ValueChanged<String> onEdit;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Journal entry: ${entry.text}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 6),
            ),
            Expanded(
              child: Text(entry.text),
            ),
            Semantics(
              label: 'Edit entry',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _showEditDialog(context),
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
              ),
            ),
            Semantics(
              label: 'Delete entry',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: onDelete,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: entry.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Entry'),
        content: Semantics(
          label: 'Entry text',
          textField: true,
          child: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          Semantics(
            label: 'Save changes',
            button: true,
            child: FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  onEdit(text);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}
