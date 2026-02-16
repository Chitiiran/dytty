# Dytty - Voice-First Daily Journaling App

## Project Overview
Daily voice conversations guided by an LLM that extract structured journal entries across 5 categories, with automated weekly reflection.

## Tech Stack
- Flutter 3.41.1 / Dart 3.11.0
- State management: Provider
- Database: sqflite (local SQLite)
- STT: speech_to_text (device STT initially)
- LLM: Provider-agnostic interface (mock for MVP)

## Architecture
Clean architecture with features-based organization:
- `lib/core/` - Constants, theme, utilities
- `lib/data/` - Models, repositories, datasources
- `lib/features/` - UI screens organized by feature
- `lib/services/` - LLM, speech, notification service interfaces

## Daily Categories (enum: JournalCategory)
1. positive, 2. negative, 3. gratitude, 4. beauty, 5. identity

## Commands
- `flutter pub get` - Install dependencies
- `flutter analyze` - Static analysis
- `flutter test` - Run tests
- `flutter run` - Run app (requires device/emulator)

## Conventions
- Files: kebab-case (daily-journal-screen.dart)
- Classes: PascalCase
- Functions/variables: camelCase
- Constants: UPPER_SNAKE_CASE
- 2-space indentation, Dart formatting via `dart format`
