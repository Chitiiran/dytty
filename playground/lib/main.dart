import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';
import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'theme/dytty_theme.dart';

import 'catalog/dytty_catalog.dart';
import 'system_prompt.dart';

// Passed via --dart-define=GEMINI_API_KEY=...
const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  final logger = configureGenUiLogging(level: Level.INFO);
  logger.onRecord.listen((record) {
    debugPrint('${record.loggerName}: ${record.message}');
  });

  runApp(const PlaygroundApp());
}

class PlaygroundApp extends StatelessWidget {
  const PlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dytty GenUI Playground',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const PlaygroundScreen(),
    );
  }
}

class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  late final A2uiMessageProcessor _processor;
  late final GenUiConversation _conversation;
  final _textController = TextEditingController();
  final _surfaceIds = <String>[];
  bool _loading = false;

  // Speech
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();

    _initSpeech();

    if (_apiKey.isEmpty) return;

    final catalog = dyttyCatalog;

    _processor = A2uiMessageProcessor(catalogs: [catalog]);

    final contentGenerator = GoogleGenerativeAiContentGenerator(
      catalog: catalog,
      systemInstruction: systemPrompt,
      modelName: 'models/gemini-2.5-flash',
      apiKey: _apiKey,
    );

    _conversation = GenUiConversation(
      a2uiMessageProcessor: _processor,
      contentGenerator: contentGenerator,
      onSurfaceAdded: _onSurfaceAdded,
      onSurfaceDeleted: _onSurfaceDeleted,
      onTextResponse: (_) => setState(() => _loading = false),
      onError: (error) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${error.error}')),
          );
        }
      },
    );
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  void _startListening() {
    if (!_speechAvailable) return;
    _speech.listen(
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
    );
    setState(() => _isListening = true);
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _onSurfaceAdded(SurfaceAdded update) {
    setState(() {
      _surfaceIds.add(update.surfaceId);
      _loading = false;
    });
  }

  void _onSurfaceDeleted(SurfaceRemoved update) {
    setState(() {
      _surfaceIds.remove(update.surfaceId);
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty || _apiKey.isEmpty) return;
    if (_isListening) _stopListening();
    setState(() => _loading = true);
    _conversation.sendRequest(UserMessage.text(text));
    _textController.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.cancel();
    if (_apiKey.isNotEmpty) {
      _conversation.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_apiKey.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.key_off, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'No API key provided',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const SelectableText(
                  'Run with:\n'
                  'flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          Expanded(
            child: _surfaceIds.isEmpty && !_loading
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _surfaceIds.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _surfaceIds.length && _loading) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GenUiSurface(
                          host: _conversation.host,
                          surfaceId: _surfaceIds[index],
                        ),
                      );
                    },
                  ),
          ),
          // Input bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g. "Show the journal with 2 gratitude entries"',
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mic button
                  if (_speechAvailable)
                    IconButton.filled(
                      onPressed:
                          _isListening ? _stopListening : _startListening,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isListening
                            ? theme.colorScheme.error.withValues(alpha: 0.15)
                            : theme.colorScheme.secondaryContainer,
                        foregroundColor: _isListening
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSecondaryContainer,
                      ),
                      tooltip: _isListening ? 'Stop listening' : 'Voice input',
                    ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () => _sendMessage(_textController.text),
                    icon: const Icon(Icons.send),
                    label: const Text('Generate'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Dytty'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'GenUI',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Describe a Dytty screen',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Type or speak a prompt to generate journal UI',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
