# Dytty Progress

## Current Status
Firebase setup complete. Project `dytty-4b83d` created, Google Sign-In enabled, Firestore in test mode, `firebase_options.dart` has real web config. Firebase CLI v15.8.0 + FlutterFire CLI v1.3.1 installed. 34 tests pass, analysis clean.

## Blockers
- None — ready to run app end-to-end

## Manual Steps Remaining
1. `npm install` for Playwright

## What's Built
- Firebase Auth (Google Sign-In) + Firestore CRUD
- Home screen with calendar (table_calendar), day markers, today's progress card
- Daily journal screen: 5 category cards with color accents, empty states, delete confirmation, snackbar feedback, relative timestamps
- Settings screen, auth-reactive routing
- Playwright E2E scaffolding (skipped until emulators ready)
- 34 unit tests (models, repository, provider, categories)

## Next Steps
- [ ] Run app end-to-end with real Firebase (`firebase emulators:start` + `flutter run -d chrome`)
- [ ] Flesh out Playwright E2E tests (`npm install` first)

---

## Log

### 2026-02-27 (session 3)
- Created Firebase project `dytty-4b83d` in Firebase Console
- Enabled Google Sign-In in Authentication > Sign-in method
- Created Firestore database in test mode (nam5/us-central)
- Installed Firebase CLI (v15.8.0) and FlutterFire CLI (v1.3.1)
- Logged into Firebase CLI, verified project access
- `firebase_options.dart` populated with real web config
- Emulators pre-configured in `firebase.json` (Auth :9099, Firestore :8080, UI :4000)
- All blockers resolved — ready for first live run

### 2026-02-27 (session 2)
- Added category colors (amber, indigo, green, pink, cyan) to JournalCategory enum
- Polished daily journal screen: colored left borders, tinted category names, empty state hints, empty day banner, delete confirmation, snackbar feedback, relative timestamps
- Added today's progress card to home screen (X of 5 categories filled + progress bar)
- Added 34 unit tests covering CategoryEntry, DailyEntry, JournalRepository, JournalProvider, and categories
- Moved widget_test.dart to proper test directory structure
- All 4 commits clean: `flutter analyze` = no issues, `flutter test` = 34/34 pass

### 2026-02-27
- Reviewed project state: 1 commit (initial scaffold), large uncommitted Firebase pivot
- Analysis clean, 3/3 tests pass, web build succeeds
- Identified blockers: Firebase project setup is manual
- Created PROGRESS.md for session tracking
