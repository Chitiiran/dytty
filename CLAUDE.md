# Dytty - Daily Journaling App

> **Start of session:**
> 1. Read `PROGRESS.md` — only the top section (above the `## Log` heading).
> 2. Read `docs/planning/BACKLOG.md` — open bugs and feature requests.
> 3. Brief the user: where we are (current milestone status, any blockers), and where we can go next (top-priority backlog items, next milestone work). Keep it to a few sentences.
>
> **End of session:** Update `PROGRESS.md` — refresh the top section with current state, and append a dated entry to the `## Log` section. Update `BACKLOG.md` if any bugs were fixed or features completed.

## Project Overview
Daily journaling app with 5 structured categories. Cross-platform Flutter app backed by Firebase (Auth + Firestore). First target: web app with Playwright E2E tests.

## Tech Stack
- Flutter 3.41.1 / Dart 3.11.0
- Firebase Auth (Google Sign-In)
- Cloud Firestore (database)
- State management: Bloc
- E2E tests: Playwright (web), Maestro (Android)

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

## Environment Variables
API keys live in `.env` (gitignored) and are injected via `--dart-define` at build time. See `.env.example` for required variables.

| Variable | Purpose |
|----------|---------|
| `FIREBASE_WEB_API_KEY` | Firebase web API key (required for web builds) |
| `FIREBASE_ANDROID_API_KEY` | Firebase Android API key (required for Android builds) |
| `GEMINI_API_KEY` | Gemini LLM API key (optional — falls back to NoOpLlmService) |

## Commands

### Build & Run
- `flutter pub get` - Install dependencies
- `flutter analyze` - Static analysis
- `flutter build web --dart-define=FIREBASE_WEB_API_KEY=<key>` - Build for web
- `flutter run -d chrome --dart-define=FIREBASE_WEB_API_KEY=<key>` - Run in Chrome
- `firebase emulators:start` - Start Firebase emulators for local dev

### Testing (5-layer pyramid)
- `flutter test` - Run all unit + widget + golden tests
- `flutter test test/widgets/` - Widget tests only
- `flutter test test/goldens/` - Golden tests only (verify visual regression)
- `flutter test --update-goldens test/goldens/` - Regenerate golden baselines
- `flutter test --coverage` - Run tests with coverage report
- `npx playwright test` - Run web E2E tests
- `bash scripts/maestro-test.sh` - Run all Maestro Android E2E flows
- `bash scripts/maestro-test.sh --flow auth` - Run only auth flows
- `bash scripts/maestro-test.sh --tags smoke` - Run smoke-tagged flows (includes state tests)
- `bash scripts/maestro-test.sh --flow state` - Run state management regression flows only
- `bash scripts/maestro-test.sh --skip-build` - Skip APK build, reuse existing
- `bash scripts/patrol-test.sh` - Run Patrol integration tests (Android)
- `bash scripts/patrol-test.sh --flow auth` - Run specific Patrol flow

### Release & Distribution
- `bash scripts/release.sh <version>` - Create release branch from develop with version bump
- `bash scripts/release.sh <version> --dry-run` - Preview release steps without executing
- `bash scripts/distribute.sh "Release notes"` - Build debug APK and upload to Firebase App Distribution
  - The release notes string should include: (1) a short summary of what changed, and (2) a test checklist of specific things to verify. This text is emailed to the tester, so make it human-friendly and complete.

## Firebase Setup (manual steps)
1. `dart pub global activate flutterfire_cli`
2. `flutterfire configure` - generates `lib/firebase_options.dart`
3. Enable Google Sign-In in Firebase Console > Authentication
4. `firebase init` - for emulators/hosting

## Git Workflow
Follow `docs/planning/GIT_WORKFLOW.md` strictly. Key points:
- **Branch model**: Trunk-based — feature branches target `main` directly
- Every change needs a GitHub Issue (check existing before creating)
- Branch naming: `<type>/<issue#>-<short-name>` (e.g. `feat/14-voice-sheet`)
- Conventional commits: `type(scope): what` + body with why + key decisions + `Refs #N`
- PRs target `main`, use `.github/pull_request_template.md`, include `Fixes #N`
- Always ask user before pushing or creating PRs
- Milestones M0-M2 closed, M3-M7 open on GitHub

## Testing Strategy
TDD is mandatory. 5-layer test pyramid. Full details in `docs/planning/TESTING.md`.

- **Layer 1: Unit tests** (`flutter test`) — Bloc logic, repository methods, model serialization. Use `bloc_test` + `FakeFirebaseFirestore`.
- **Layer 2: Widget tests** (`flutter test test/widgets/`) — Robot pattern, mock Blocs via `mocktail`. `test/robots/` + `test/widgets/`.
- **Layer 3: Golden tests** (`flutter test test/goldens/`) — Visual regression via `matchesGoldenFile`. Baselines in `test/goldens/fixtures/`.
- **Layer 4: Integration tests** (Patrol) — On-device tests with native OS dialog support. `integration_test/`.
- **Layer 5: E2E Android** (`bash scripts/maestro-test.sh`) — Black-box Maestro YAML flows. Screenshots as artifacts.
- **E2E web** (`npx playwright test`) — Playwright against web build + Firebase emulators.
- **Coverage enforcement**: CI enforces minimum coverage (ratchets up 10% weekly toward 100%). Current gate: 40%.
- **Test coverage rule**: Every bug fix must include a test that reproduces the bug before the fix. Every feature must include tests for its acceptance criteria. E2E required for cross-screen UI state changes.

## Conventions
- Files: snake_case (daily_journal_screen.dart)
- Classes: PascalCase
- Functions/variables: camelCase
- Constants: UPPER_SNAKE_CASE
- 2-space indentation, Dart formatting via `dart format`
