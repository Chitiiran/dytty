# Dytty — Testing Strategy

> Comprehensive testing guide covering all test layers, tools, and workflows.

---

## Philosophy

**TDD is mandatory.** Every feature and bug fix follows: tests first → implement → iterate → verify.

Every bug fix must include a test that reproduces the bug before the fix. Every feature must include tests for its acceptance criteria. E2E tests are required for cross-screen UI state changes.

---

## Test Layers

| Layer | Tool | Target | Speed | Location |
|-------|------|--------|-------|----------|
| Unit | `flutter test` | Bloc logic, repositories, models | Fast (~2s) | `test/` |
| Widget | `flutter test` | Individual widget rendering | Fast (~2s) | `test/` |
| E2E (Web) | Playwright | Full user flows on web | Medium (~30s) | `e2e/` |
| E2E (Android) | Maestro | Full user flows on Android | Slow (~60s) | `.maestro/` |

---

## Unit Tests

**Libraries:** `bloc_test`, `fake_cloud_firestore`, `mockito`

**What to test:**
- Bloc state transitions (events → states)
- Repository CRUD operations (using `FakeFirebaseFirestore`)
- Model serialization/deserialization (toMap/fromMap)
- Service interfaces (using fakes/mocks)

**Commands:**
```bash
flutter test                          # Run all unit tests
flutter test test/features/auth/      # Run specific directory
flutter test --coverage               # With coverage report
```

**Conventions:**
- Test files mirror `lib/` structure: `lib/features/auth/` → `test/features/auth/`
- File naming: `<source>_test.dart`
- Use `blocTest<Bloc, State>()` for Bloc testing
- Use `FakeFirebaseFirestore()` — never mock Firestore

---

## E2E Tests — Web (Playwright)

**Tool:** Playwright v1.50.0

**How it works:**
1. Build web app with emulator flag: `flutter build web --dart-define=USE_EMULATORS=true`
2. Serve the build: `npx serve build/web -l 5555`
3. Playwright drives headless Chromium against the served app
4. Firebase emulators provide backend (Auth :9099, Firestore :8080)

**Commands:**
```bash
npm install                           # Install Playwright
npx playwright test                   # Run all E2E tests
npx playwright test --headed          # Run with visible browser
npx playwright test --debug           # Debug mode (step through)
```

**Structure:**
```
e2e/
├── auth.spec.ts          # Login/sign-out flows
├── journal.spec.ts       # CRUD operations
├── home-state.spec.ts    # Dashboard state management
├── debug.spec.ts         # Debug-specific tests
└── helpers.ts            # Firebase emulator setup, Flutter DOM helpers
```

**Key helpers:**
- `clearEmulatorAuth()` / `clearEmulatorFirestore()` — reset emulator state
- `waitForFlutterReady()` — wait for `flutter-view` + `flt-semantics` elements
- `signInAnonymously()` — click emulator debug button, wait for navigation
- `clickByLabel()` / `expectTextVisible()` — accessibility tree queries

**Flutter semantics tips:**
- Use `tooltip` on `IconButton` (renders as text content in DOM)
- Use `Semantics(label:)` for explicit labels on non-button widgets
- Use `getByRole('button', { name })` for tooltip-based buttons
- Use `getByLabel()` for `Semantics(label:)` wrappers

**Config:** `playwright.config.ts` — timeout 120s per test, 180s server startup, HTML reporter with screenshots on failure.

---

## E2E Tests — Android (Maestro)

**Tool:** Maestro 2.3.0+

**How it works:**
1. Build debug APK with emulator flag
2. Install APK on Android emulator via ADB
3. Maestro runs YAML flows — interacts with the app via accessibility/view hierarchy
4. `takeScreenshot` captures visual state at key points for developer review
5. CI uploads screenshots as artifacts for every PR

### Prerequisites

- **Maestro CLI**: `curl -fsSL "https://get.maestro.mobile.dev" | bash`
- **JDK 17+** (JDK 21 available at `C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`)
- **ADB**: Android SDK platform-tools (at `$LOCALAPPDATA/Android/Sdk/platform-tools/`)
- **Android emulator** running and visible via `adb devices`
- **Firebase emulators** running (Auth :9099, Firestore :8080)

### Commands

```bash
# Run all flows
bash scripts/maestro-test.sh

# Run specific feature flows
bash scripts/maestro-test.sh --flow auth
bash scripts/maestro-test.sh --flow journal

# Run by tag
bash scripts/maestro-test.sh --tags smoke

# Skip APK build (reuse existing)
bash scripts/maestro-test.sh --skip-build

# Interactive flow builder (great for debugging selectors)
maestro studio
```

### Flow Structure

```
.maestro/
├── config.yaml
├── helpers/
│   └── login.yaml                # Reusable: emulator login (clearState + sign in)
├── auth/
│   ├── login-flow.yaml           # Emulator login → verify home screen
│   └── logout-flow.yaml          # Login → settings → sign out → verify login screen
├── journal/
│   ├── add-entry-flow.yaml       # Add entry to Positive Things category
│   ├── dashboard-flow.yaml       # Verify calendar, progress, nudge card, FAB
│   └── navigate-days-flow.yaml   # Navigate between days via chevrons
├── state/
│   ├── nudge-disappears-after-entry.yaml   # #21 regression: nudge gone after add
│   ├── progress-updates-after-entry.yaml   # #22 regression: progress 0→1→2 of 5
│   ├── all-categories-complete.yaml        # Fill all 5 → "All categories complete!"
│   └── streak-updates-after-entry.yaml     # Streak shows "1 day" after first entry
└── screenshots/                  # Git-ignored output directory
```

### Tags

| Tag | Purpose | When to run |
|-----|---------|-------------|
| `smoke` | Core happy paths — login, dashboard, add entry, nudge + progress state | Every PR (CI) |
| `state` | State management regression tests (cross-screen updates) | Every PR (CI) |
| `auth` | Authentication flows only | Auth changes |
| `journal` | Journal CRUD + navigation | Journal changes |
| `dashboard` | Dashboard element verification | Dashboard/state changes |

### Writing Maestro Flows

**Flow file anatomy:**
```yaml
appId: com.dytty.dytty          # App package ID
name: "Human-readable name"
tags:
  - smoke
  - feature-area
---
# Commands (sequential)
- launchApp:
    clearState: true

- takeScreenshot: "feature/01-step-name"

- assertVisible: "Button Text"

- tapOn: "Element text or regex"

- waitForAnimationToEnd:
    timeout: 5000

- inputText: "typed content"
```

**Key Maestro commands:**
| Command | Usage |
|---------|-------|
| `launchApp` | Start app (with `clearState: true` for clean slate) |
| `tapOn` | Tap by text, id, or regex pattern |
| `assertVisible` | Verify element is on screen |
| `inputText` | Type into focused field |
| `takeScreenshot` | Capture PNG for visual verification |
| `waitForAnimationToEnd` | Wait for Flutter transitions to settle |
| `scroll` / `scrollUntilVisible` | Scroll to find elements |
| `back` | Android back button |
| `pressKey` | Simulate hardware key (Enter, etc.) |
| `runFlow` | Compose flows (e.g., reuse login) |

**Element identification (what Maestro sees):**
- `tooltip` on `IconButton` → text content
- `Semantics(label:)` → accessibility label
- Visible text on widgets
- Resource IDs (less common in Flutter)

**Key semantic labels in Dytty:**

| Label | Widget |
|-------|--------|
| `"Sign in anonymously (emulator)"` | Emulator login button |
| `"Sign in with Google"` | Google login button |
| `"\\?"` | Settings icon button (shows as `?` in accessibility tree) |
| `"Record voice note"` | Mic FAB tooltip |
| `"Calendar"` | Calendar widget |
| `"Progress X of Y"` | Progress card |
| `"Today button"` | Write journal button |
| `"Previous day"` / `"Next day"` | Journal day navigation |
| `"Add [Category] entry"` | Category add buttons |
| `"Journal entry: [text]"` | Entry tiles |
| `"Edit entry"` / `"Delete entry"` | Entry action buttons |

### Maestro Gotchas & Lessons Learned

1. **`assertVisible` does NOT do substring matching** — it matches against the full `accessibilityText` of a node. Use regex `".*partial text.*"` for partial matching.

2. **Curly/smart apostrophes** — Source code may use `\u2019` (right single quote) in strings like "haven't". Maestro can't match literal `'`. Use regex: `"You haven.*journaled today.*"`.

3. **Flutter cold start timing** — `waitForAnimationToEnd` completes instantly if no animation is detected (white screen = no pixel changes). Chain triple `waitForAnimationToEnd` after login to catch route transition → loading spinner → data load animations.

4. **Parallel flow interference** — Flows sharing an emulator with `clearState: true` can interfere with each other. The runner script (`scripts/maestro-test.sh`) runs each flow individually and sequentially to avoid this.

5. **`scrollUntilVisible` + `centerElement: true`** — When elements are below the fold (like the 5th category card), `centerElement: true` ensures the element is scrolled to center, not just barely visible at the edge. Without it, tap targets may be partially off-screen.

6. **`retryTapIfNoChange: true`** — Use on buttons that may not register the first tap (e.g., after scroll, or when the view is still settling).

7. **`inputText` for autofocused fields** — If a TextField has `autofocus: true`, you can use `inputText` directly without tapping the field first.

8. **Stylus handwriting dialog** — Android emulators may show "Try out your stylus" dialog when tapping text fields. Disable with: `adb shell settings put secure stylus_handwriting_enabled 0`.

9. **Firebase emulator host on Android** — Use `10.0.2.2` (not `localhost`) to reach the host machine from an Android emulator.

10. **Settings button accessibility** — The settings `IconButton` with a `?` icon renders as `"?"` in the accessibility tree, not the tooltip text. Tap with: `tapOn: "\\?"`.

### Screenshot-Driven AI Development Workflow

This is the primary workflow for AI-assisted development with Maestro:

1. **Write unit tests** (`flutter test`) — fast TDD cycle for logic
2. **Implement** — minimum code to pass unit tests
3. **Run Maestro flows** — `bash scripts/maestro-test.sh`
4. **Review screenshots** — developer inspects `.maestro/screenshots/<timestamp>/` for visual correctness
5. **Iterate** — AI agent adjusts code based on screenshot feedback
6. **CI verification** — PR triggers Maestro job, screenshots uploaded as artifacts

**In CI (GitHub Actions):**
- The `maestro` job runs `smoke`-tagged flows on every PR and main push
- Screenshots are uploaded as artifacts (14-day retention)
- Download from: Actions tab → workflow run → Artifacts → `maestro-screenshots`
- JUnit XML results included for pass/fail reporting

---

## CI/CD Pipeline

**File:** `.github/workflows/ci.yml`

### Jobs

| Job | Trigger | Runner | What it does |
|-----|---------|--------|--------------|
| `ci` | PR + main push | ubuntu-latest | Analyze, unit test, build web, upload artifact |
| `maestro` | PR + main push | ubuntu-latest | Build APK, start emulator, run Maestro smoke flows, upload screenshots |
| `deploy` | main push only | ubuntu-latest | Deploy web build to Firebase Hosting |

### Required GitHub Secrets

| Secret | Purpose | Status |
|--------|---------|--------|
| `FIREBASE_WEB_API_KEY` | Web build dart-define | Needed |
| `FIREBASE_SERVICE_ACCOUNT_DYTTY_4B83D` | Firebase Hosting deploy | Needed |

### Maestro CI Details

The Maestro job:
1. Checks out code
2. Sets up JDK 21 + Flutter 3.41.1
3. Builds debug APK with `USE_EMULATORS=true`
4. Installs Maestro CLI
5. Starts Android emulator via `reactivecircus/android-emulator-runner@v2` (API 33, x86_64)
6. Installs APK and runs `smoke`-tagged flows
7. Uploads screenshots + JUnit results as `maestro-screenshots` artifact

**Note:** The Maestro CI job runs without Firebase emulators — flows that depend on emulator auth will fail in CI until Firebase emulator setup is added to the workflow. This is a known limitation; smoke flows should be designed to handle this gracefully.

---

## Adding Tests — Checklist

### New feature
- [ ] Unit tests for Bloc events/states
- [ ] Unit tests for repository methods (if new)
- [ ] Unit tests for model serialization (if new model)
- [ ] Playwright E2E if the feature involves cross-screen state changes (web)
- [ ] Maestro flow if the feature has an Android-specific interaction
- [ ] `takeScreenshot` at key visual states in Maestro flows

### Bug fix
- [ ] Unit test that reproduces the bug (must fail before fix)
- [ ] Fix the bug
- [ ] Verify test passes
- [ ] Add Maestro screenshot if the bug was visual

### Refactor
- [ ] Existing tests still pass
- [ ] No new tests needed unless behavior changes
