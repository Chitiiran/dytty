import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/speech/speech_service.dart';

class VoiceSessionScreen extends StatefulWidget {
  final DateTime date;

  const VoiceSessionScreen({super.key, required this.date});

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

enum _SessionPhase { conversation, review }

class _VoiceSessionScreenState extends State<VoiceSessionScreen> {
  late final LlmService _llm;
  late final SpeechService _speech;
  late final JournalRepository _repository;

  final _messages = <LlmMessage>[];
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  _SessionPhase _phase = _SessionPhase.conversation;
  bool _isListening = false;
  bool _isProcessing = false;
  String _partialTranscript = '';
  List<ExtractedEntry> _extractedEntries = [];
  late DateTime _sessionStart;

  @override
  void initState() {
    super.initState();
    _llm = context.read<LlmService>();
    _speech = context.read<SpeechService>();
    _repository = context.read<JournalRepository>();
    _sessionStart = DateTime.now();
    _startConversation();
  }

  Future<void> _startConversation() async {
    setState(() => _isProcessing = true);
    final response = await _llm.chat([]);
    _messages.add(LlmMessage(role: 'assistant', content: response));
    setState(() => _isProcessing = false);
    _scrollToBottom();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.isAvailable();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available. Use text input.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _partialTranscript = '';
    });

    await _speech.startListening(
      onResult: (text, isFinal) {
        setState(() => _partialTranscript = text);
        if (isFinal && text.trim().isNotEmpty) {
          _sendUserMessage(text.trim());
        }
      },
      onDone: () {
        setState(() => _isListening = false);
      },
    );
  }

  Future<void> _sendUserMessage(String text) async {
    _messages.add(LlmMessage(role: 'user', content: text));
    setState(() {
      _isProcessing = true;
      _isListening = false;
      _partialTranscript = '';
    });
    _scrollToBottom();

    final response = await _llm.chat(_messages);
    _messages.add(LlmMessage(role: 'assistant', content: response));
    setState(() => _isProcessing = false);
    _scrollToBottom();

    // Check if conversation is complete (5 user messages = 5 categories)
    final userCount = _messages.where((m) => m.role == 'user').length;
    if (userCount >= JournalCategory.values.length) {
      await _extractEntries();
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _sendUserMessage(text);
  }

  Future<void> _extractEntries() async {
    final transcript = _messages
        .where((m) => m.role == 'user')
        .map((m) => m.content)
        .join('\n');
    _extractedEntries = await _llm.extractEntries(transcript);
    setState(() => _phase = _SessionPhase.review);
  }

  Future<void> _saveEntries() async {
    final dailyEntry = await _repository.getOrCreateDailyEntry(widget.date);
    final durationSeconds = DateTime.now().difference(_sessionStart).inSeconds;

    // Save voice session transcript
    final transcript = _messages
        .map((m) => '${m.role}: ${m.content}')
        .join('\n');
    await _repository.saveVoiceSession(
      dailyEntryId: dailyEntry.id,
      transcript: transcript,
      durationSeconds: durationSeconds,
      startedAt: _sessionStart,
    );

    // Save extracted entries
    for (final extracted in _extractedEntries) {
      if (extracted.text.trim().isNotEmpty) {
        await _repository.addCategoryEntry(
          dailyEntryId: dailyEntry.id,
          category: extracted.category,
          text: extracted.text,
          source: EntrySource.voice,
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    if (_speech.isListening) _speech.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Session'),
        actions: [
          if (_phase == _SessionPhase.conversation)
            TextButton(
              onPressed: _messages.where((m) => m.role == 'user').isNotEmpty
                  ? _extractEntries
                  : null,
              child: const Text('Done'),
            ),
        ],
      ),
      body: _phase == _SessionPhase.conversation
          ? _buildConversation()
          : _buildReview(),
    );
  }

  Widget _buildConversation() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_partialTranscript.isNotEmpty ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i < _messages.length) {
                final msg = _messages[i];
                final isUser = msg.role == 'user';
                return _buildBubble(
                  text: msg.content,
                  isUser: isUser,
                  theme: theme,
                );
              }
              // Partial transcript
              return _buildBubble(
                text: '$_partialTranscript...',
                isUser: true,
                theme: theme,
                isPartial: true,
              );
            },
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        _buildInputBar(theme),
      ],
    );
  }

  Widget _buildBubble({
    required String text,
    required bool isUser,
    required ThemeData theme,
    bool isPartial = false,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isUser
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
            fontStyle: isPartial ? FontStyle.italic : null,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isProcessing ? null : _sendTextMessage,
              icon: const Icon(Icons.send),
            ),
            IconButton(
              onPressed: _isProcessing ? null : _toggleListening,
              icon: Icon(
                _isListening ? Icons.stop_circle : Icons.mic,
                color: _isListening ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Review your entries',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _extractedEntries.length,
            itemBuilder: (ctx, i) {
              final entry = _extractedEntries[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(
                    entry.category.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(entry.category.displayName),
                  subtitle: Text(entry.text),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _editExtractedEntry(i),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saveEntries,
            icon: const Icon(Icons.check),
            label: const Text('Save Entries'),
          ),
        ),
      ],
    );
  }

  void _editExtractedEntry(int index) {
    final entry = _extractedEntries[index];
    final controller = TextEditingController(text: entry.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.category.displayName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _extractedEntries[index] = ExtractedEntry(
                  category: entry.category,
                  text: controller.text.trim(),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
