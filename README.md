# Dytty - Voice-First Daily Journaling App

Daily voice conversations guided by an LLM that extract structured journal entries across 5 categories, with automated weekly reflection.

## Tech Stack

- **Framework**: Flutter 3.41.1 / Dart 3.11.0
- **State Management**: Provider
- **Database**: sqflite (local SQLite)
- **Speech-to-Text**: speech_to_text (device STT)
- **LLM**: Provider-agnostic interface (mock for MVP)

## Project Structure

```
lib/
├── main.dart                  # Entry point, initializes notifications
├── app.dart                   # Provider setup, routes
├── core/
│   ├── constants/             # App constants, category definitions
│   └── theme/                 # Material 3 theme config
├── data/
│   ├── models/                # DailyEntry, CategoryEntry, VoiceSession
│   ├── datasources/           # DatabaseHelper (SQLite schema)
│   └── repositories/          # JournalRepository (CRUD operations)
├── features/
│   ├── daily_journal/         # Home, journal, voice session screens
│   ├── settings/              # Settings screen + provider
│   └── weekly_review/         # (empty - not yet implemented)
└── services/
    ├── llm/                   # LlmService interface + MockLlmService
    ├── speech/                # SpeechService interface + DeviceSpeechService
    └── notification/          # NotificationService (Android daily reminders)
```

## Journal Categories

1. **Positive** - Good things that happened
2. **Negative** - Challenges or difficulties
3. **Gratitude** - Things to be grateful for
4. **Beauty** - Beautiful moments noticed
5. **Identity** - Self-reflections and growth

## Current Status

### Done
- SQLite database with 4 tables (daily_entries, category_entries, voice_sessions, user_settings)
- Full CRUD via JournalRepository
- Home screen with calendar view and day markers
- Daily journal screen with per-category entry management (add/edit/delete)
- Voice session screen with two-phase flow: conversation → review
- Voice input with real-time transcription + fallback text input
- Mock LLM with scripted 5-message conversation flow
- Auto-extraction of entries after conversation completes
- Settings screen with notification toggle and reminder time picker
- Basic unit tests for models and mock LLM

### Incomplete
- **Weekly review** - Feature directory exists but has no implementation
- **Real LLM integration** - Using MockLlmService with hardcoded responses
- **Entry extraction** - Naive (splits by newline, assigns categories sequentially)
- **Error handling** - Minimal across screens
- **iOS/Windows support** - Notifications and speech only configured for Android
- **Multi-language** - Languages defined but not utilized in extraction

### Next Steps (MVP Priority)
1. Replace MockLlmService with real LLM (Claude API)
2. Test on device (speech permissions, notifications, DB persistence)
3. Build weekly review screen
4. Add error handling to voice session flow
5. Improve entry extraction logic

### Post-MVP
- Multi-language entry support
- Export to PDF/JSON
- Search/filter by category or date
- Dark mode polish
- Analytics (sessions/entries per week)

## Commands

```bash
flutter pub get       # Install dependencies
flutter analyze       # Static analysis
flutter test          # Run tests
flutter run           # Run app (requires device/emulator)
```
