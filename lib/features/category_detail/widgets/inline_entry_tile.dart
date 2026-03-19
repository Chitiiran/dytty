import 'package:flutter/material.dart';
import 'package:dytty/data/models/category_entry.dart';

/// Tile for a single category entry, supporting inline editing
/// and transcript toggle (easter egg).
class InlineEntryTile extends StatefulWidget {
  final CategoryEntry entry;
  final bool isEditing;
  final bool isOlderEntry;
  final VoidCallback? onTapEdit;
  final void Function(String)? onSaveEdit;
  final VoidCallback? onCancelEdit;

  const InlineEntryTile({
    super.key,
    required this.entry,
    this.isEditing = false,
    this.isOlderEntry = false,
    this.onTapEdit,
    this.onSaveEdit,
    this.onCancelEdit,
  });

  @override
  State<InlineEntryTile> createState() => _InlineEntryTileState();
}

class _InlineEntryTileState extends State<InlineEntryTile> {
  late TextEditingController _editController;
  bool _showTranscript = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.entry.text);
  }

  @override
  void didUpdateWidget(InlineEntryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !oldWidget.isEditing) {
      _editController.text = widget.entry.text;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  bool get _hasTranscript =>
      widget.entry.transcript != null && widget.entry.transcript!.isNotEmpty;

  String get _displayText => _showTranscript && _hasTranscript
      ? widget.entry.transcript!
      : widget.entry.text;

  IconData get _sourceIcon => widget.entry.source == 'voice'
      ? Icons.mic_rounded
      : Icons.edit_note_rounded;

  String get _relativeTime {
    final now = DateTime.now();
    final diff = now.difference(widget.entry.createdAt);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = widget.isOlderEntry ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: widget.isEditing
            ? _buildEditMode(theme)
            : _buildDisplayMode(theme),
      ),
    );
  }

  Widget _buildDisplayMode(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        // Easter egg: toggle transcript display
        if (_hasTranscript) {
          setState(() => _showTranscript = !_showTranscript);
        } else {
          setState(() => _isExpanded = !_isExpanded);
        }
      },
      onLongPress: widget.onTapEdit,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _sourceIcon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayText,
                  maxLines: _isExpanded ? null : 3,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _relativeTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_showTranscript && _hasTranscript) ...[
                      const SizedBox(width: 8),
                      Text(
                        'transcript',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (widget.entry.isReviewed)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditMode(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _editController,
            autofocus: true,
            maxLines: null,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.check_rounded, color: theme.colorScheme.primary),
          tooltip: 'Save edit',
          onPressed: () {
            final text = _editController.text.trim();
            if (text.isNotEmpty) {
              widget.onSaveEdit?.call(text);
            }
          },
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.error),
          tooltip: 'Cancel edit',
          onPressed: widget.onCancelEdit,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
