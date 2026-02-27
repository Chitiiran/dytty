# Dytty - Daily Journaling App

> **Start of session:** Read `PROGRESS.md` — only the top section (above the `## Log` heading). This has current status, blockers, and next steps.
> **End of session:** Update `PROGRESS.md` — refresh the top section with current state, and append a dated entry to the `## Log` section.

## Project Overview
Daily journaling app with 5 structured categories. Cross-platform Flutter app backed by Firebase (Auth + Firestore). First target: web app with Playwright E2E tests.

## Tech Stack
- Flutter 3.41.1 / Dart 3.11.0
- Firebase Auth (Google Sign-In)
- Cloud Firestore (database)
- State management: Provider
- E2E tests: Playwright

## Architecture
Clean architecture with features-based organization:
- `lib/core/` - Constants (categories enum), theme
- `lib/data/` - Models (DailyEntry, CategoryEntry), repositories (Firestore CRUD)
- `lib/features/` - UI screens: auth, daily_journal, settings
- `lib/services/` - Auth service (Firebase Auth wrapper)

## Firestore Schema
```
users/{uid}/
  profile: { displayName, email, createdAt }
  dailyEntries/{date-string}/   # e.g. "2026-02-22"
    createdAt, updatedAt
    categoryEntries/{autoId}/
      category, text, source, createdAt
```

## Daily Categories (enum: JournalCategory)
1. positive, 2. negative, 3. gratitude, 4. beauty, 5. identity

## Commands
- `flutter pub get` - Install dependencies
- `flutter analyze` - Static analysis
- `flutter test` - Run unit tests
- `flutter build web` - Build for web
- `flutter run -d chrome` - Run in Chrome
- `npm install` - Install Playwright
- `npx playwright test` - Run E2E tests
- `firebase emulators:start` - Start Firebase emulators for local dev

## Firebase Setup (manual steps)
1. `dart pub global activate flutterfire_cli`
2. `flutterfire configure` - generates `lib/firebase_options.dart`
3. Enable Google Sign-In in Firebase Console > Authentication
4. `firebase init` - for emulators/hosting

## Conventions
- Files: snake_case (daily_journal_screen.dart)
- Classes: PascalCase
- Functions/variables: camelCase
- Constants: UPPER_SNAKE_CASE
- 2-space indentation, Dart formatting via `dart format`
