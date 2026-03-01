import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dytty/core/constants/categories.dart';

/// Bottom sheet for adding or editing a journal entry.
/// Returns the entered text, or null if cancelled.
Future<String?> showEntryBottomSheet(
  BuildContext context, {
  required JournalCategory category,
  String? initialText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _EntryBottomSheetContent(category: category, initialText: initialText),
  );
}

class _EntryBottomSheetContent extends StatefulWidget {
  final JournalCategory category;
  final String? initialText;

  const _EntryBottomSheetContent({required this.category, this.initialText});

  @override
  State<_EntryBottomSheetContent> createState() =>
      _EntryBottomSheetContentState();
}

class _EntryBottomSheetContentState extends State<_EntryBottomSheetContent> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initialText != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.category.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.category.icon,
                  size: 18,
                  color: widget.category.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing
                      ? 'Edit ${widget.category.displayName}'
                      : widget.category.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              widget.category.prompt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Text field
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Entry text',
              hintText: widget.category.prompt,
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            minLines: 2,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _hasText ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: widget.category.color,
              ),
              child: Text(
                isEditing ? 'Update' : 'Save',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
