# Dytty Progress

## Current Status
On `main`. UX redesign merged. Production deploy prepped (needs real OAuth client ID).

**What's on main now:**
- Full UX redesign: gradient login, calendar-focused home, redesigned journal cards, polished settings
- Theme: Google Fonts Inter, M3 component themes, extended color palette (AppColors)
- Animations: flutter_animate, staggered list animations, slide page transitions
- UX: bottom sheet for add/edit, swipe-to-delete with undo, day nav arrows, progress card, theme switcher
- Responsive: 600px max-width constraints for tablet/desktop
- Shimmer loading, reusable empty state widget
- Production deploy prep: OAuth client ID placeholder in `web/index.html`
- 35 unit tests passing, 0 analysis issues

## Blockers
- Production deploy: needs real Google OAuth client ID in `web/index.html`

## Active Branches
| Branch | Purpose | Status |
|--------|---------|--------|
| `main` | Stable app with UX redesign | All merged, ready for deploy |
| `genui-playground` | GenUI design playground | **Needs integration onto main** |

## Branch Naming Convention
- `feature/<name>` — new features
- `fix/<name>` — bug fixes
- `e2e-<name>` — E2E testing work
- `experiment/<name>` — exploratory/prototype work (e.g., genui-playground)

## What's Built (feature/ux-redesign)
### Core (from main)
- Firebase Auth (Google Sign-In + anonymous debug sign-in) + Firestore CRUD
- Anonymous sign-in (debug-only) for emulator testing
- Lazy GoogleSignIn init (fixes web crash when client ID meta tag missing)
- Emulator connection in debug mode (`kDebugMode` guard in `main.dart`)
- Home screen with calendar, day markers, progress card
- Daily journal: 5 category cards, entries, CRUD operations
- Settings screen, auth-reactive routing
- 35 unit tests, 10 E2E tests

### UX Redesign (this branch)
- **Theme**: Google Fonts Inter, M3 component themes, warm surfaces, extended color palette (`app_colors.dart`)
- **Login**: gradient background, staggered fade+slide animations, branded Google button with spinner
- **Home**: greeting text, avatar → Settings, enhanced calendar styling, progress card with category icons + motivational messages, full-width "Write Today's Journal" CTA
- **Daily Journal**: tinted category card headers, Material icons in colored circles, entry count badges, rounded entry tiles, bottom sheet for add/edit, swipe-to-delete with undo SnackBar, day nav arrows, shimmer loading
- **Settings**: large profile header with bordered avatar, grouped card sections (Appearance/Account/About), System/Light/Dark theme toggle, licenses page
- **App**: ThemeProvider for theme mode, slide-from-right page transitions
- **Responsive**: 600px max-width constraints on home + journal screens
- **New files**: `app_colors.dart`, `shimmer_loading.dart`, `empty_state.dart`, `entry_bottom_sheet.dart`, `theme_provider.dart`

## Next Steps
- [x] Merge `feature/ux-redesign` to main
- [x] Run E2E tests against redesigned build to verify selectors
- [ ] **GenUI integration** — bring playground/ onto main, update catalog + system prompt for new UX, add voice input via `speech_to_text` (see `~/.claude/projects/C--dojo-dytty/memory/genui-research.md`)
- [ ] Add real Google OAuth client ID to `web/index.html`
- [ ] Deploy to production: `flutter build web` + `firebase deploy`
- [ ] Verify production Google Sign-In works end-to-end

## Backlog
- [ ] Clicking a progress card emoji/icon should navigate to that category's journal page
- [ ] Upgrade dependencies to latest major versions (23 packages outdated)

### Current data context
- **Local emulator only** — all data lives in Firebase emulators (Auth :9099, Firestore :8080), ephemeral, lost when emulators stop
- **Emulator UI** at http://localhost:4000 to inspect data
- **No cloud data yet** — nothing has been written to the real Firebase project

---

## Log

### 2026-03-01 (session 8)
- Full UX redesign on `feature/ux-redesign` branch
- **Phase 1 — Foundation:**
  - Added 4 dependencies: `flutter_animate`, `shimmer`, `flutter_staggered_animations`, `google_fonts`
  - Created `app_colors.dart` with extended palette (category colors, surface tints for light/dark)
  - Overhauled `app_theme.dart`: Google Fonts Inter, full M3 component themes (inputs, buttons, snackbar, dialog, bottom sheet, divider)
  - Replaced emoji icons with Material Icons in `JournalCategory` (sunny, cloud, favorite, florist, fingerprint)
  - Updated categories test for `IconData` type + unique icon test (35 tests)
- **Phase 2 — Screen Redesigns:**
  - Login: gradient background, staggered entrance animations (fade+slide+scale), branded Google Sign-In button with spinner, styled error container with shake animation
  - Home: greeting text ("Good morning, Name"), user avatar → Settings, enhanced TableCalendar (custom header, pill selection, better today indicator), progress card with 5 category icons (filled/unfilled), motivational message, full-width "Write Today's Journal" CTA
  - Daily Journal: date header with day-of-week + nav arrows, tinted category card headers with Material icon in colored circle + entry count badge, rounded entry tiles with edit/delete buttons, swipe-to-delete with Dismissible, long-press context menu for fallback, bottom sheet for add/edit (replaces AlertDialog), optimistic delete with undo SnackBar, shimmer loading skeleton
  - Settings: 76px avatar with colored ring, grouped card sections (Appearance with System/Light/Dark toggle, Account with sign out, About with version + licenses)
- **Phase 3 — Polish:**
  - Created `ThemeProvider` for theme mode state (System/Light/Dark)
  - Added slide-from-right page transitions via `onGenerateRoute` in app.dart
  - Created `shimmer_loading.dart` with `ShimmerCategoryCard`, `ShimmerJournalLoading`, `ShimmerProgressCard`
  - Created `empty_state.dart` reusable widget
  - Added 600px max-width `ConstrainedBox` to home + journal screens for responsive layout
- **E2E test updates:**
  - Auth: updated subtitle text, sign-out flow (now via Settings screen)
  - Journal: edit uses "Edit entry" button + "Update" in bottom sheet, delete is optimistic (no confirmation dialog)
- Production deployment meta tag placeholder added to `web/index.html`
- 0 analysis issues, 35/35 unit tests passing, `dart format` clean

### 2026-02-28 (session 7)
- Resolved Java 21 PATH blocker: JDK 21 at `C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`
- Discovered `flutter run -d web-server` (DDC/debug mode) is unreliable with Playwright's headless Chromium — Flutter loads scripts but never renders, zero errors
- **Solution:** switched to release build strategy: `flutter build web --dart-define=USE_EMULATORS=true` + `npx serve build/web` — renders in <2s, fully reliable
- Updated `playwright.config.ts` webServer command to build+serve instead of `flutter run`
- Fixed Flutter semantics for E2E testing:
  - Removed double `Semantics` wrappers on `IconButton`s (outer wrapper intercepted clicks without forwarding to inner button)
  - Used `tooltip` directly on `IconButton` for semantic labels (renders as text content, not aria-label)
  - Used `InputDecoration.labelText` instead of outer `Semantics` on `TextField`
  - Used `getByRole('button', { name })` in tests instead of `getByLabel()` for tooltip-based labels
  - Used `getByLabel()` only for elements with explicit `Semantics(label:)` wrappers (category cards, calendar, today button)
- Inspected Flutter web accessibility tree to map exact DOM structure to Playwright selectors
- All 10 E2E tests passing, 34 unit tests passing
- Cleaned up diagnostic scripts (diagnose.mjs, inspect-a11y.mjs, global-setup.ts)

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
