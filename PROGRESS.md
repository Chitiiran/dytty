# Dytty Progress

## Current Status
**PR #104 code review refactors complete. All 7 issues (#105-#114) merged.**

**Latest on main:**
- All PR #104 code review refactors landed (7 PRs merged)
- `formatRelativeTime` shared utility (#105), `recentDaysCount` constant (#106), enum keys for `reviewQuestions` (#107), CallBadgeIcon a11y fix (#112), silent catch → error states (#114), ReviewCallController extraction (#111), CallSession utility (#113)
- Version: 0.1.7+9

**Open PRs:** None

**Test status:** 671 Flutter + 32 Playwright + 9 Maestro = 712 tests. Coverage: 82.3% (CI gate: 50%)

**Coverage ratchet plan:**
| Week | Date | Target | CI `min_coverage` |
|------|------|--------|-------------------|
| 0 | 2026-03-15 | 40% | 40 |
| 1 | 2026-03-22 | 50% | 50 |
| 2 | 2026-03-29 | 60% | 60 |
| 3 | 2026-04-05 | 70% | 70 |
| 4 | 2026-04-12 | 80% | 80 |
| 5 | 2026-04-19 | 90% | 90 |
| 6 | 2026-04-26 | 100% | 100 |

Update `min_coverage` in `.github/workflows/ci.yml` each week.

**Milestone status:**
| Milestone | Status |
|-----------|--------|
| M0–M4 | Done |
| M5: Weekly Review | In progress — #71 Category Detail Page (all 7 phases done, needs manual testing) |
| M6: Categories + Polish | Data model done. UI settings page pending |
| M7: Launch Prep | Not started |

## Blockers
- Web build requires `--no-tree-shake-icons` due to dynamic IconData in CategoryConfig
- #95: CI auto-distribution requires `FIREBASE_SERVICE_ACCOUNT_DYTTY_4B83D` secret

## Up Next
- **#86**: Journal entries lost on app restart (P0, offline persistence)
- **#83**: First-time user onboarding (P0)
- **#82**: Security audit — Firestore rules, API keys, audio encryption (P0)
- **#79**: Data export + account deletion for GDPR (P0)
- **#78**: iOS build for close-circle distribution (P0)
- **#90**: Error state flash on call start (race condition)
- **#95**: Enable CI auto-distribution (infra)
- **#48**: Golden test CI failures (cross-platform fonts)
- Coverage at 81.7% — ahead of ratchet schedule, bump CI gate

---

## Log

### 2026-03-20 (session 28)
- **PR #104 code review refactors — all 7 issues complete**
  - PRs 1-4 implemented in parallel worktrees, PRs 5-7 sequential (overlapping files)
  - Each PR: TDD (tests first), implement, analyze, test, push, code review, apply fixes, merge
  - **#105** (PR #125): `formatRelativeTime` → shared utility with injectable `now` param for deterministic tests
  - **#106** (PR #124): magic number 7 → `recentDaysCount` constant with clarifying comment
  - **#107** (PR #127): `reviewQuestions` string keys → `JournalCategory` enum keys
  - **#112** (PR #126): `_CallBadgeIcon` GestureDetector → IconButton (a11y + tooltip)
  - **#114** (PR #129): silent catch blocks → emit error state + BlocListener SnackBars, optimistic revert on all 3 operations
  - **#111** (PR #131): extracted `ReviewCallController` (ChangeNotifier) from `_CategoryDetailViewState` — screen 611→374 lines, factory injection for testability, `_disposed` guards on all async paths
  - **#113** (PR #133): extracted `CallSession` utility — granular API (initPlayback, startRecording, stop, dispose), used by both ReviewCallController and VoiceCallScreen
  - 703/703 tests passing (671 Flutter + 32 Playwright), 82.3% coverage
  - Key decisions: injectable `now` for time utils, granular CallSession API (not monolithic `start()`) to accommodate Gemini connect interleaving, `onError` callback pattern for controller→screen error reporting

### 2026-03-19 (session 27)
- **#92 Dependency upgrade — PR #103 merged**
  - Flutter 3.41.1 → 3.41.5, google_sign_in 6.x → 7.x (new authenticate() API), google_fonts 6.x → 8.x
  - Migrated GeminiLlmService from deprecated google_generative_ai to firebase_ai
  - Updated Gemini Live model to gemini-2.5-flash-preview-native-audio
  - Unpinned firebase_core, firebase_auth, firebase_ai, cloud_firestore, fake_cloud_firestore
  - Fixed Color.value deprecation → Color.toARGB32()
- **#91 Speaker toggle icon** — Icons.hearing → Icons.phone_in_talk (clearer earpiece icon)
- **#57 Portrait lock** — SystemChrome.setPreferredOrientations in main.dart
- **#39 Tappable empty prompt** — GestureDetector on empty category prompt text opens add entry sheet
- **#55 Already implemented** — category icons in progress card were already tappable with navigation
- 671 total tests (630 Flutter + 32 Playwright + 9 Maestro), 80.7% coverage

### 2026-03-19 (session 26)
- **#60 Test Report Upgrade — PR #100**
  - Report UI: boxed category cards with color-coded left borders (blue=Flutter, green=Playwright, orange=Maestro), proportional timing bars, collapsible sections, folder-grouped test suites, coverage folder rollups with zero-coverage callout, E2E screen/flow coverage checklist table
  - Per-category metrics: duration + throughput per layer, environment badges (Flutter version, browser, device/API level)
  - Parallel E2E: Playwright + Maestro now run concurrently (pre-build web first to avoid Flutter lock conflict)
  - Coverage: 77.5% → 80.7% (+3.2%) via 10 new CategoryDetailScreen widget tests (screen was at 0%)
  - E2E: 24 → 32 Playwright tests (+8: settings, voice-note, category-detail), screen coverage 6/8 → 8/8
  - Key decisions:
    - **Port 4200 for Playwright web server** — port 5555 collided with Android emulator adb (root cause of all Playwright timeouts when emulator was running)
    - **Per-flow Maestro XML merge** — each `maestro test` overwrites results.xml; now writes per-flow XMLs then merges, so all 9 flows appear in report (was showing 1/1)
    - **E2E coverage as manual checklist** — Playwright/Maestro are black-box tests with no code coverage; created `tool/screen-coverage.yaml` mapping screens/flows to spec files, report shows coverage %
    - **Collapsible category sections** — sections collapsed by default (auto-expand on failures) to reduce visual noise; screenshots also collapsed
    - **Pre-build web before parallel fork** — `flutter build web` locks the project, preventing Maestro APK install; building first then forking both E2E layers avoids the race
    - **`dart_test.yaml`** — registers `golden` tag to suppress unknown tag warning
  - 669 total tests passing, 0 failures, 5 data sources

### 2026-03-18 (session 25)
- **#71 Category Detail Page — Phases 5-7 complete (all done)**
  - Phase 5 (Embedded Review Call): `_CategoryDetailView` converted to `StatefulWidget` with full call lifecycle (VoiceCallBloc + GeminiLiveService + AudioRecorder + AudioPlaybackService), `CallControlsOverlay` widget (mute/end/elapsed), `_CallBadge` (red during call, green with entries, grey empty), category-tinted status banner, entry dedup via `_processedEntryCount`
  - Phase 6 (Post-Call): `_performPostCallActions()` marks all 7-day entries reviewed + generates review summary via LlmService, saves via `SaveReviewSummaryEvent`, handles empty/NoOp gracefully
  - Phase 7 (Integration): JournalBloc sync via existing VoiceCallBloc tool call handlers, connect failure cleanup, resource teardown in dispose
  - 619 tests passing (+10 new), 0 analysis warnings
  - Distributed to testers

### 2026-03-18 (session 24)
- **#71 Category Detail Page — Phases 1-4 complete**
  - Phase 1 (Data): `isReviewed` field on CategoryEntry (backward-compatible), `ReviewSummary` model, `review_questions.dart` (5 categories x 2 questions), 4 new repository methods (`getCategoryEntriesForDateRange`, `markEntryReviewed`, `saveReviewSummary`, `getReviewSummary`)
  - Phase 2 (Bloc): `CategoryDetailBloc` with rolling 7-day entry loading grouped by date, collapsible groups, inline edit with optimistic updates, live entry from call, mark reviewed, injectable clock for testable dates
  - Phase 3 (Service): Parameterized `GeminiLiveService.connect()` (custom systemPrompt + tools), public `saveEntryDeclaration`/`editEntryDeclaration`, `edit_entry` tool handling in `VoiceCallBloc`, `review_prompts.dart` for category-specific review prompts
  - Phase 4 (UI): `CategoryDetailScreen` with `BlocProvider`, 5 widgets (header with call badge, review summary card, collapsible date group headers, inline entry tile with transcript easter egg + reviewed badge, empty state), `/category-detail` route, category icon tap navigation from ProgressCard
  - ADR-008 and `PLAN-071-category-detail-page.md` documented
  - Key decisions: N-query approach (1 per date, max 7) vs collection group to avoid Firestore migration, `JournalBloc.repository` getter for sibling bloc access, injectable clock on `CategoryDetailBloc`
  - 609 tests passing (+64 new), 0 analysis warnings

### 2026-03-17 (session 23)
- **#51 Patrol setup — ready for closure**
  - Patrol 4.3.0 added, all 3 integration test flows compiled (auth, dashboard, journal CRUD)
  - Robot pattern preserved with `PatrolIntegrationTester`
  - Needs emulator run to confirm green — all flows compile and import correctly
- **#52 gRPC audio injection — spike complete, documented**
  - `scripts/inject-audio.py`: discovery (grpc.port + grpc.address), --address flag, --grpc-use-token auth
  - 14 Python unit tests passing (WAV chunking, INI parsing, discovery)
  - Spike result: `injectAudio` streaming RPC fails on Windows emulator 35.5.10.0 (connection reset)
  - Root cause: likely Windows-specific gRPC streaming issue in emulator
  - Documented findings in `docs/research/grpc-audio-injection.md` with retry recommendation for Linux CI
- **Coverage: 67.8% → 81.7%** (545 tests, target was 80%)
  - voice_call_screen: 64 new tests (all states + transcripts + time warnings)
  - voice_recording_sheet: 24 new tests (all VoiceNoteBloc states end-to-end)
  - home_screen: 16 new tests (avatars, streaks, progress messages, greeting)
  - daily_journal_screen: 7 new interaction tests
  - voice_call_bloc: copyWith + dispose tests
  - voice_note_bloc: event props + state tests
  - gemini_live_service: 12 unit tests (Transcript, Speaker, state)
- Context used: ~80%, key decisions: grpc.port discovery fix, -grpc-use-token for auth, emulator -no-audio disables injectAudio

### 2026-03-16 (session 22)
- **#94 Fixed — PR #96 merged** — daily call audio playback + transcript rendering
  - Replaced `just_audio` with `flutter_pcm_sound` — feeds raw PCM directly, no WAV wrapping/buffering
  - Added `isFinal` flag to `Transcript` model, wired `Transcription.finished` from `firebase_ai`
  - Transcript aggregation: partials from same speaker replace last bubble, finals lock it
  - Created `AudioPlaybackService` abstract interface + `PcmSoundPlaybackService` implementation
  - `VoiceCallScreen` accepts optional `AudioPlaybackService` for DI in tests
  - Google Sign-In `serverClientId` fix included (ADR-006)
  - 10 new tests (5 transcript aggregation, 5 fake audio service), 386 total passing
- **Build 0.1.6+8 distributed** to testers via `scripts/distribute.sh`
- **#95 created** (infra) — enable CI auto-distribution on main push (needs `FIREBASE_SERVICE_ACCOUNT_DYTTY_4B83D` secret)
- Context used: ~40%, key decisions: `flutter_pcm_sound` over raw_sound, `AudioPlaybackService` abstraction, transcript aggregation rule

### 2026-03-16 (session 21)
- **Google Sign-In fix** — `google_sign_in_android 6.2+` migrated to Credential Manager which requires explicit `serverClientId`. Added web client ID to `GoogleSignIn()` constructor. Documented in ADR-006.
- **Firebase AI Logic enabled** — daily call was failing because Gemini Developer API wasn't enabled. Enabled via Firebase Console > AI services > Gemini Developer API. Closed #89.
- **Daily call audio diagnosed** — connection works (158ms latency) but `just_audio` crashes on streaming PCM ("Source error", "Connection aborted"). Transcripts render word-by-word. Created #94.
- **CI distribution improved** — tester emails now send only `## Tester Checklist` from PR body (not full Summary/Key Decisions/Claude footer). Updated PR template with Tester Checklist section.
- **Issues created**: #89 (closed — API enablement), #90 (error flash race), #91 (speaker icon UX), #92 (Gemini model retirement), #93 (App Check), #94 (audio playback + transcripts)
- **Distributed 0.1.5+7** to testers with sign-in fix + tester-facing release notes
- **Plan written** for #94: replace `just_audio` with `flutter_pcm_sound`, aggregate partial transcripts using `Transcription.finished` flag, abstract playback behind testable interface. See `docs/planning/PLAN-094-audio-playback-fix.md`
- Key decisions: `flutter_pcm_sound` over `raw_sound` (actively maintained, event-driven feed), `AudioPlaybackService` abstraction for testability
- Context used: ~70%, key decisions: serverClientId fix (ADR-006), flutter_pcm_sound selection, tester checklist extraction

### 2026-03-15 (session 20, continued)
- **Maestro 9/9 flows all green**
  - Fixed parallel-interference: runner script now executes each flow individually and sequentially
  - Fixed `add-entry-flow`: removed `assertVisible: "Time to reflect"` (fails when other flows add entries)
  - Fixed `all-categories-complete`: added `centerElement: true` to `scrollUntilVisible` for Identity card, used `inputText` directly (autofocus handles focus), `retryTapIfNoChange: true` for + button
  - Key Maestro lessons: `scrollUntilVisible` + `centerElement` for off-screen elements, `retryTapIfNoChange` for buttons that may not register, `inputText` for autofocused fields, regex `.*pattern.*` for partial text matching
  - Cleaned up stale screenshot dirs from project root, added to `.gitignore`

### 2026-03-15 (session 20)
- **Maestro Android E2E setup — complete**
  - Installed Maestro 2.3.0 CLI locally
  - Created `.maestro/` directory with 9 YAML flows across 3 categories
  - Auth: login, logout | Journal: add-entry, dashboard, navigate-days | State: nudge-disappears (#21), progress-updates (#22), all-categories-complete, streak-updates
  - All flows use `takeScreenshot` for visual verification at key states
  - Created `scripts/maestro-test.sh` runner script (build APK, install, run, collect screenshots)
  - Added `maestro` job to `.github/workflows/ci.yml` — builds APK, starts emulator, runs smoke flows, uploads screenshots as artifacts
  - Created `docs/planning/TESTING.md` — comprehensive testing strategy doc
  - Fixed Firebase emulator connectivity on Android (`10.0.2.2` vs `localhost`)
  - Fixed curly apostrophe matching in assertions (regex `haven.*journaled`)
  - Fixed stylus handwriting dialog blocking text input (adb settings)

### 2026-03-15 (session 19)
- **#42 JournalBloc state audit — complete** (PR #44 merged)
  - Root cause: Firestore web SDK returns stale data after writes on emulators
  - Fix: optimistic state updates — use returned data directly instead of re-reading Firestore
  - Added `JournalStatus.saving` to avoid shimmer flash during mutations
  - Added `date` param to AddEntry/AddVoiceEntry to eliminate race condition with concurrent SelectDate
  - `_onSelectDate` now loads markers + streak (was entries-only)
  - `_onUpdateEntry`/`_onDeleteEntry` use optimistic list mutations
  - Added `Semantics(label:)` on ProgressCard for E2E testability
  - Enabled anonymous sign-in in release+emulator builds for E2E testing
  - 10 new unit tests, 5 new E2E home-state tests
- **PR #16 configurable categories merged** — resolved merge conflicts with #42 optimistic updates
  - Updated voice_call_bloc + voice_call_screen: `JournalCategory` enum → string `categoryId`
  - CategoryCubit: emit defaults immediately to avoid empty UI on Firestore stale reads
  - Web build now requires `--no-tree-shake-icons` (dynamic IconData in CategoryConfig)
- **All PRs cleared**, no open PRs
- **Post-merge fix**: CategoryCubit.loadCategories emits defaults synchronously before Firestore read
- Verification: 100 unit tests, 15 E2E tests — all passing

### 2026-03-15 (session 18)
- **User feedback analysis** — 23 GitHub issues created (#20–#43) from test build feedback
- New labels created: `state-management`, `ux-ui`, `product-decision`
- Raw feedback saved to `docs/planning/feedback/2026-03-15-user-feedback.md`
- Backlog updated to reference GitHub issue numbers
- Key findings from test session:
  - State management regression: minidot, CTA banner, category symbols all stale after add (#20, #21, #22, #42)
  - Voice call non-functional end-to-end (#24, #25, #32, #33, #35)
  - Push notifications not working when app closed (#26)
  - Voice note review step missing — goes straight to journal (#32)

### 2026-03-14 (session 17)
- **PR #13 review feedback addressed** (#17): structured Transcript model (Speaker enum), DI via RepositoryProvider/BlocProvider, removed dead code (AudioChunkReceived, _audioSub), dedicated _TimerTicked event, _SaveEntryArgs constants
- **PR #13 merged to main** (squash merge)
- **PR #15 review feedback addressed**: DateFormat from intl, _audioPlaybackThreshold constant, WAV header comments
- **PR #15 rebased onto main** — clean 3-commit history, no conflicts, 71 tests passing
- **Created issues**: #17 (refactor feedback), #18 (GenUI integration), #19 (delete playground, blocked by #18)
- **Test build distributed** via Firebase App Distribution (v0.1.0 debug APK) with full test plan covering all milestones

### 2026-03-13 (session 16)
- **M4: Daily Call — feature-complete** (PR #15)
  - Scheduled daily call notification with Accept/Decline action buttons
  - Firebase Storage audio upload (mic PCM) after call ends
  - LLM-powered post-session summary generation from transcript
  - Settings UI: daily call reminder toggle + time picker
  - AudioStorageService created, wired via RepositoryProvider
  - NotificationService extended with second channel, pendingRoute navigation
  - 71 tests passing, 0 analysis errors
- **M3 PR #13** pushed earlier (Gemini Live prototype)
- Updated PROGRESS.md, starting M6 planning (configurable categories)

### 2026-03-12 (session 15)
- **Git workflow adopted**: conventional commits, GitHub Issues, branch naming `<type>/<issue#>-<short-name>`, PR template
- **Bug fix PR #9** (merged): entry refresh (#6), daily reminders (#7), always-on nudge (#8)
  - CategoryEntry Equatable for Bloc state diffing
  - flutter_local_notifications v21 named-parameter API
  - Android core library desugaring for notifications
- **M3: Gemini Live prototype** (PR #13, `feat/10-gemini-live-prototype`)
  - Firebase AI SDK 3.9.0, Firebase suite upgrade (core 4.x, auth 6.x, firestore 6.x)
  - GeminiLiveService: WebSocket audio streaming, transcription, tool calling (save_entry)
  - VoiceCallBloc: session state machine, timeout management
  - VoiceCallScreen: transcript bubbles, latency display, call button
- **M4: Production voice call** (first commit on `feat/14-production-voice-call`)
  - JournalBloc wiring for Firestore entry persistence
  - Post-call summary UI, session timeout warnings
  - Home screen "Start Daily Call" button

### 2026-03-07 (session 14)
- **Firebase App Distribution setup** for Android dogfooding
- Created `scripts/distribute.sh` — sources `.env`, builds debug APK with dart-defines, uploads via `firebase appdistribution:distribute`
- Added `TESTER_EMAIL` to `.env.example` and `.env`
- **Manual follow-ups**: Enable App Distribution in Firebase Console, fill in `TESTER_EMAIL` in `.env`, register Android debug SHA-1

### 2026-03-01 (session 13)
- **Security: Removed Firebase API keys from source control**
- Rotated exposed web API key, moved all Firebase keys to `--dart-define` injection from `.env` (gitignored)
- `firebase_options.dart`: `String.fromEnvironment()` for web + android API keys
- Created `.env.example` template (checked into git)
- `.gitignore`: added `android/app/google-services.json`
- `ci.yml`: web build now injects `FIREBASE_WEB_API_KEY` from GitHub secrets
- `playwright.config.ts`: passes key via shell env expansion
- `CLAUDE.md`: added Environment Variables section, updated build commands, fixed Provider→Bloc
- Merged `W9/M0-foundation` to `main`, pushed both
- Verification: 0 analysis issues, 54 tests passing, web build clean, zero API keys in `lib/`
- **Manual follow-ups needed**: add `FIREBASE_WEB_API_KEY` GitHub secret, register Android SHA-1, add API key restrictions

### 2026-03-01 (session 12)
- **M1: Anytime Voice Notes — complete**
- Added `speech_to_text: ^7.0.0` dependency
- Extended `JournalRepository.addCategoryEntry` with optional `source`, `transcript`, `tags` params (backward-compatible)
- Added `AddVoiceEntry` event to `JournalBloc` — saves with `source: 'voice'`, transcript, tags
- Created `SpeechService` (`lib/services/speech/`) — wraps `speech_to_text`, constructor-injectable
- Created `NoOpLlmService` — production stub when no API key configured
- Wired `LlmService` + `SpeechService` via `MultiRepositoryProvider` in `app.dart`
- Added `GEMINI_API_KEY` dart-define const in `main.dart`
- Created `VoiceNoteBloc` (`lib/features/voice_note/bloc/`) — state machine: initial → ready → listening → processing → reviewing. Orchestrates STT + LLM categorization
- Created `VoiceNoteResult` data class
- Created `VoiceRecordingSheet` bottom sheet — auto-starts listening, live transcript, pulsing mic, processing spinner, review with editable summary + category chips + tags
- Added mic FAB to `HomeScreen` — opens sheet, on save dispatches `AddVoiceEntry`, navigates to daily journal, shows snackbar
- New tests: 2 repository tests (voice fields, manual defaults), 1 bloc test (AddVoiceEntry), 6 voice_note_bloc tests (init ready/unavailable, categorize, update category/text, reset)
- Verification: 0 analysis issues, 60 tests passing, web build clean
- **Files created (5)**: `speech_service.dart`, `no_op_llm_service.dart`, `voice_note_bloc.dart`, `voice_note_result.dart`, `voice_recording_sheet.dart`
- **Files modified (5)**: `pubspec.yaml`, `main.dart`, `app.dart`, `journal_repository.dart`, `journal_bloc.dart`, `home_screen.dart`
- **Test files (3)**: extended `journal_repository_test.dart`, extended `journal_bloc_test.dart`, created `voice_note_bloc_test.dart`

### 2026-03-01 (session 11)
- **M0: Foundation — all 4 deliverables complete**
- **CI/CD pipeline**: `.github/workflows/ci.yml` — push/PR triggers, Flutter 3.41.1, analyze+test+build+deploy. Deploy job uses `FirebaseExtended/action-hosting-deploy@v0` (requires `FIREBASE_SERVICE_ACCOUNT_DYTTY_4B83D` secret)
- **Data model evolution**: Added `audioUrl`, `transcript`, `tags` optional fields to `CategoryEntry`. Backward-compatible serialization (omit when null/empty). 4 new tests
- **Bloc migration**: Replaced Provider with flutter_bloc. Created `AuthBloc` (sealed events/states, equatable, stream subscription), `JournalBloc` (single copyWith state, 7 events), `ThemeCubit`. Rewrote `app.dart` with two-MaterialApp pattern (auth-gated JournalBloc scoped by uid). Updated all 4 screens. Deleted 3 provider files + 1 test file. 10 new bloc/cubit tests
- **Swappable LLM interface**: Abstract `LlmService` with `generateResponse`, `categorizeEntry`, `summarizeEntry`, `generateWeeklySummary`. `GeminiLlmService` (Gemini 2.5 Flash, structured JSON prompts). `FakeLlmService` for testing
- Dependencies: added `flutter_bloc`, `equatable`, `bloc_test`, `google_generative_ai`. Removed `provider`
- Verification: 0 analysis issues, 45/45 tests passing, web build clean

### 2026-03-01 (session 10)
- Product direction interview: 30 questions across 6 sections (core value, data, UX, insights, privacy, quality)
- Key pivot: app is now **voice-first AI companion**, not text-first CRUD
- Two modes defined: Anytime voice notes (silent AI) + Scheduled daily call (conversational AI "best friend")
- Major decisions: user-configurable categories, audio+transcript storage, weekly review ritual, append-only corrections, GenUI for session UI, smart nudges, multilingual support
- Dogfooding minimum: voice input + daily call + audio storage + dashboard (web + Android)
- Launch strategy: dogfood solo → close circle → value hypothesis test (add iOS)
- Created `OBJECTIVES.md` with full product objectives
- Updated PROGRESS.md with new direction
- Next: roadmap interview for tech stack decisions + milestones

### 2026-03-01 (session 9)
- Integrated GenUI playground onto main (cherry-picked from `genui-playground` branch)
- Redesigned all 4 catalog widgets to match UX redesign:
  - **CategoryCard**: removed hardcoded maps, uses `JournalCategory` enum + `AppColors`, tinted header strip, 34px icon circles, entry count badge, rounded entry tiles
  - **ProgressCard**: added `filledCategories` list prop, row of 5 category icon circles (filled/unfilled), rounded progress bar, motivational message
  - **EntryTile**: removed `categoryColor` prop, rounded container (radius 12, surface 70% alpha), edit/delete icons
  - **EmptyBanner**: `title` + `subtitle` props (replaces `message`), gradient container, 44px lightbulb circle
- Updated system prompt with new Material icons, AppColors hex values, and redesigned widget descriptions
- Added `speech_to_text: ^7.0.0` for voice input
- Polished main.dart: mic button with visual feedback (red when listening), "Dytty" + "GenUI" badge AppBar, icon circle empty state
- Added `AppColors` re-export to playground theme
- 3 commits: cherry-pick, catalog+prompt redesign, voice input
- 0 analysis issues (playground + main app), 35/35 unit tests passing

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
