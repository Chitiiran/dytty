# Dytty Progress

## Current Status
On branch `e2e-playwright-setup` (off main). Core app on `main` is stable.

**This branch (`e2e-playwright-setup`):** Playwright E2E tests wired with anonymous sign-in. 10 real tests (3 auth, 7 journal/calendar) + 1 debug diagnostic. npm/Playwright installed. Flutter web server on :5555 connects to Firebase emulators automatically via `kDebugMode`.

**Key finding this session:** Stale `flutter run -d web-server` causes Flutter to silently fail to render (CanvasKit loads, DDC loads 607 scripts, but `flutter-view` never appears, zero errors). Restarting the dev server fixes it. Tests not yet run against fresh server.

## Blockers
- None currently — Java 21 found at `C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`, emulators run fine with `JAVA_HOME` override
- Stale Flutter dev server can cause silent failures — always restart before test runs

## Active Branches
| Branch | Purpose | Status |
|--------|---------|--------|
| `main` | Stable core app | Firebase + Auth + Firestore CRUD working |
| `e2e-playwright-setup` | Playwright E2E testing | **Committed** (e4e5e15) — fresh server works, tests pending |
| `genui-playground` | GenUI design playground | Committed, separate experiment |

## Branch Naming Convention
- `feature/<name>` — new features
- `fix/<name>` — bug fixes
- `e2e-<name>` — E2E testing work
- `experiment/<name>` — exploratory/prototype work (e.g., genui-playground)

## What's Built (main)
- Firebase Auth (Google Sign-In + anonymous debug sign-in) + Firestore CRUD
- Anonymous sign-in (debug-only) for emulator testing — no OAuth popup needed
- Lazy GoogleSignIn init (fixes web crash when client ID meta tag missing)
- Emulator connection in debug mode (`kDebugMode` guard in `main.dart`)
- `.firebaserc` with default project `dytty-4b83d`
- Home screen with calendar (table_calendar), day markers, today's progress card
- Daily journal screen: 5 category cards with color accents, empty states, delete confirmation, snackbar feedback, relative timestamps
- Settings screen, auth-reactive routing
- Login screen with scroll support (overflow fix)
- 34 unit tests (models, repository, provider, categories)

## Next Steps
- [x] Fix Java 21 PATH — found at `C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`, use `JAVA_HOME` override
- [ ] Run Playwright tests against fresh Flutter server
- [ ] Fix any test failures (semantic labels, selectors)
- [ ] Merge `e2e-playwright-setup` to main when tests pass
- [ ] UX polish pass — UI is functional but scaffoldy

---

## Log

### 2026-02-28 (session 7)
- Resolved Java 21 PATH blocker: JDK 21 at `C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`, emulators start with `JAVA_HOME` override
- Found Firebase emulators already running (ports 9099, 8080) from prior session
- Diagnosed Flutter silent render failure: stale `flutter run -d web-server` serves DDC scripts + CanvasKit but never creates `flutter-view` — zero errors in browser
- Created `e2e/diagnose.mjs` diagnostic script (CDP runtime monitoring, network tracing)
- Confirmed fix: killing stale server (PID 37576) and restarting `flutter run -d web-server` resolves rendering
- Fresh server: Firebase init logs appear, Auth emulator connects, semantics tree renders with `flt-semantics` nodes
- `useEmulators` flag works automatically via `kDebugMode` in debug builds — no `--dart-define` needed
- Next: run actual Playwright tests, fix failures, commit

### 2026-02-28 (session 6)
- Isolated E2E testing work from genui-playground branch
- Created `e2e-playwright-setup` branch off main
- Committed E2E testing setup (e4e5e15): Playwright tests, useEmulators flag, semantic labels
- Updated Claude Code permissions in `~/.claude/settings.json`
- Blocker: Java 11 in PATH instead of Java 21 — emulators won't start

### 2026-02-27 (session 5)
- Added anonymous sign-in for emulator testing (debug-only, `kDebugMode` guard)
- Fixed eager `GoogleSignIn()` crash on web — made initialization lazy in `AuthService`
- `signOut()` now safe for anonymous users (skips Google sign-out if never initialized)
- Manual E2E test: anonymous login -> home screen -> journal entry CRUD — all working
- UI noted as scaffoldy — needs polish pass

### 2026-02-27 (session 4)
- Added emulator connection logic to `main.dart` (kDebugMode guard: Auth :9099, Firestore :8080)
- Created `.firebaserc` with default project `dytty-4b83d`
- Fixed login screen bottom overflow — wrapped in `SingleChildScrollView`
- Installed JDK 21 via winget (Firebase emulators require Java 21+)
- First live run: `firebase emulators:start` + `flutter run -d chrome` — app loads, emulator banner confirms connection
- Committed Firebase project config (`firebase_options.dart`, `firebase.json`, `PROGRESS.md`)
- 2 commits pushed to origin/main

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
