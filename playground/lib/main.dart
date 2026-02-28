import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';
import 'package:logging/logging.dart';

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

  @override
  void initState() {
    super.initState();

    if (_apiKey.isEmpty) {
      return; // Show key-missing UI instead
    }

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
    setState(() => _loading = true);
    _conversation.sendRequest(UserMessage.text(text));
    _textController.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
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
        appBar: AppBar(title: const Text('Dytty GenUI Playground')),
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
      appBar: AppBar(title: const Text('Dytty GenUI Playground')),
      body: Column(
        children: [
          Expanded(
            child: _surfaceIds.isEmpty && !_loading
                ? Center(
                    child: Text(
                      'Describe a Dytty screen to generate it',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. "Show the journal with 2 gratitude entries"',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 12),
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
}
