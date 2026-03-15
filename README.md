# Dytty - Voice-First Daily Journaling App

A voice-first AI companion for daily journaling. Guided conversations extract structured entries across 5 configurable categories, with streaks, progress tracking, and a dashboard to keep you consistent.

## Tech Stack

- **Framework**: Flutter 3.41.1 / Dart 3.11.0
- **State Management**: Bloc (`flutter_bloc`)
- **Backend**: Firebase (Auth, Cloud Firestore, Storage)
- **Auth**: Google Sign-In via Firebase Auth
- **LLM**: Swappable interface — Gemini 2.5 Flash (`firebase_ai`), falls back to `NoOpLlmService`
- **Speech**: `speech_to_text` (platform STT), `record` (audio capture)
- **Platforms**: Web, Android (iOS structure exists but untested)

## Project Structure

```
lib/
├── main.dart                  # Entry point, Firebase init, emulator config
├── app.dart                   # Bloc providers, MaterialApp, routing
├── core/
│   ├── constants/             # App constants
│   ├── theme/                 # Material 3 theme (AppColors, AppTheme)
│   └── widgets/               # Shared widgets (empty state, etc.)
├── data/
│   ├── models/                # DailyEntry, CategoryEntry, CategoryConfig
│   └── repositories/          # JournalRepository, CategoryRepository (Firestore)
├── features/
│   ├── auth/                  # LoginScreen, AuthBloc (Google Sign-In)
│   ├── daily_journal/         # HomeScreen, DailyJournalScreen, JournalBloc
│   ├── settings/              # SettingsScreen, ThemeCubit, CategoryCubit, SettingsCubit
│   ├── voice_note/            # VoiceNoteBloc, mic FAB → STT → LLM categorization
│   └── voice_call/            # VoiceCallScreen (daily guided conversation)
└── services/
    ├── llm/                   # LlmService interface, GeminiLlmService, NoOpLlmService
    └── speech/                # SpeechService interface, DeviceSpeechService
```

## Journal Categories

5 default categories (user-configurable via Firestore):

1. **Positive** - Good things that happened
2. **Negative** - Challenges or difficulties
3. **Gratitude** - Things to be grateful for
4. **Beauty** - Beautiful moments noticed
5. **Identity** - Self-reflections and growth

## Testing

5-layer test pyramid with 124 tests:

| Layer | Tool | Count | Location |
|-------|------|-------|----------|
| Unit | `flutter test` | 100 | `test/` |
| Widget | `flutter test` (Robot pattern) | 17 | `test/widgets/` |
| Golden | `flutter test` (visual regression) | 7 | `test/goldens/` |
| Integration | Patrol (scaffold) | — | `integration_test/` |
| Black Box E2E | Maestro | 9 flows | `.maestro/` |

```bash
flutter test                                    # Run unit + widget + golden tests
flutter test --update-goldens test/goldens/     # Regenerate golden baselines
bash scripts/maestro-test.sh                    # Run Maestro Android E2E flows
bash scripts/maestro-test.sh --tags smoke       # Smoke tests only
```

## Commands

```bash
# Setup
flutter pub get                                 # Install dependencies

# Development
flutter analyze                                 # Static analysis
flutter test                                    # Run all tests
flutter run -d chrome --dart-define=FIREBASE_WEB_API_KEY=<key>     # Run web
flutter run -d <device> --dart-define=FIREBASE_ANDROID_API_KEY=<key>  # Run Android

# Build
flutter build web --no-tree-shake-icons --dart-define=FIREBASE_WEB_API_KEY=<key>
flutter build apk --debug --dart-define=FIREBASE_ANDROID_API_KEY=<key>

# Release
bash scripts/distribute.sh "Release notes"      # Build + upload to Firebase App Distribution
bash scripts/release.sh 0.2.0                   # Cut a release branch from develop
```

## Environment Variables

API keys live in `.env` (gitignored) and are injected via `--dart-define`:

| Variable | Purpose |
|----------|---------|
| `FIREBASE_WEB_API_KEY` | Firebase web API key |
| `FIREBASE_ANDROID_API_KEY` | Firebase Android API key |
| `GEMINI_API_KEY` | Gemini LLM (optional — falls back to NoOpLlmService) |

## CI/CD

Three GitHub Actions workflows:

- **`ci.yml`** — PRs: analyze, test, coverage (60% min), build web + APK, Maestro smoke
- **`release-candidate.yml`** — Release branches: full test suite + Maestro + Firebase App Distribution
- **`deploy.yml`** — Main: build web, deploy to Firebase Hosting, git tag

## Milestone Status

| Milestone | Status |
|-----------|--------|
| M0: Foundation | Done |
| M1: Anytime Voice Notes | Done |
| M2: Dashboard + Daily Experience | Done |
| M3: Voice Call Prototypes | Done |
| M4: Daily Call | Done |
| M5: Weekly Review | Not started |
| M6: Configurable Categories | Data model done, UI pending |
| M7: Launch Prep | Not started |
