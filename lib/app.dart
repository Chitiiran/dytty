import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dytty/core/theme/app_theme.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/daily_journal/home_screen.dart';
import 'package:dytty/features/daily_journal/journal_provider.dart';
import 'package:dytty/features/settings/settings_provider.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/llm/mock_llm_service.dart';
import 'package:dytty/services/speech/device_speech_service.dart';
import 'package:dytty/services/speech/speech_service.dart';

class DyttyApp extends StatelessWidget {
  const DyttyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = JournalRepository();

    return MultiProvider(
      providers: [
        Provider<JournalRepository>.value(value: repository),
        Provider<LlmService>(create: (_) => MockLlmService()),
        Provider<SpeechService>(create: (_) => DeviceSpeechService()),
        ChangeNotifierProvider(
          create: (_) => JournalProvider(repository),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(repository)..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Dytty',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
