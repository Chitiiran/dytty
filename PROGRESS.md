# Dytty Progress

## Current Status
Firebase pivot complete. App compiles, analyzes clean, 3 unit tests pass. Uncommitted on `master` branch.

## Blockers
- Firebase project not yet created (manual step)
- `flutterfire configure` needed to generate real `firebase_options.dart`
- Google Sign-In must be enabled in Firebase Console
- Firebase CLI / emulators not yet initialized locally

## Manual Steps Remaining
1. Create Firebase project
2. `dart pub global activate flutterfire_cli && flutterfire configure`
3. Enable Google Sign-In in Firebase Console > Authentication > Sign-in method
4. `firebase init` for emulators
5. `npm install` for Playwright

## What's Built
- Firebase Auth (Google Sign-In) + Firestore CRUD
- Home screen with calendar (table_calendar), day markers
- Daily journal screen: 5 category cards, add/edit/delete via dialogs
- Settings screen, auth-reactive routing
- Playwright E2E scaffolding (skipped until emulators ready)
- Old voice/SQLite/LLM code removed

## Next Steps
- [ ] Commit the Firebase pivot (large uncommitted changeset)
- [ ] Complete Firebase manual setup
- [ ] Run app end-to-end with real Firebase
- [ ] Flesh out Playwright E2E tests
- [ ] UX polish (inline entry input, empty states, better card styling)

---

## Log

### 2026-02-27
- Reviewed project state: 1 commit (initial scaffold), large uncommitted Firebase pivot
- Analysis clean, 3/3 tests pass, web build succeeds
- Identified blockers: Firebase project setup is manual
- Created PROGRESS.md for session tracking
