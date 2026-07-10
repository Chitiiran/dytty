# Dytty - Daily Journaling App

Voice-first daily journaling app with 5 structured categories. Flutter + Firebase + Bloc.

## Session Rituals

**Start of session:**
1. Read `kb/PROGRESS.md` — top section only (above `## Log`).
2. Run `bash scripts/verify-workflow.sh --stage session-start` — checks observation periods and active workstreams.
3. Brief the user: active workstreams, observation alerts, top priorities. Keep it to a few sentences.

**Before merging a PR:** Update `kb/PROGRESS.md` — refresh "Latest on main", update test counts, log key decisions/tradeoffs. Decisions get buried in PR bodies; capture them before they're lost.

**End of session:** Update `kb/PROGRESS.md` — refresh top section, append dated entry to `## Log`.

**Weekly (owner ritual):** 20-minute retro in `kb/workflow/WEEKLY-RETRO.md` — five questions: what reached a device, what broke and why, which signal lied, what did I avoid, what do I kill. The session-start check nudges when it's 8+ days stale.

## Knowledge Base (`kb/`)

All project knowledge lives in `kb/` (gitignored, private IP). Navigate by the question you're trying to answer:

| Folder | Question it answers | Key files |
|--------|-------------------|-----------|
| `kb/decisions/` | "Why did we choose X?" | ADRs (001-009), RESEARCH-*.md |
| `kb/workflow/` | "How does work flow?" | GIT-WORKFLOW.md, CI-GATES.md, TESTING.md, RELEASE.md, FEEDBACK.md, DECISION-MAKING.md, COST-ESTIMATION.md |
| `kb/product/` | "What are we building?" | OBJECTIVES.md, ROADMAP.md |
| `kb/specs/` | "What will we build and how?" | SPEC-*.md (design), PLAN-*.md (implementation) |
| `kb/feedback/` | "What did users say?" | Raw feedback files, DOGFOODING_INTERVIEW.md |

Each folder (except `product/`) has templates. Use them.

## Work Pipeline

Every piece of work flows through this pipeline. Each stage produces an artifact that feeds the next:

```
research → decision → spec → plan → implementation
```

| Stage | Artifact | Location | Superpowers skill |
|-------|----------|----------|-------------------|
| Research | RESEARCH-*.md | `kb/decisions/` | `/brainstorm` (explore phase) |
| Decision | ADR (NNN-*.md) | `kb/decisions/` | `/brainstorm` (decision phase) |
| Spec | SPEC-{issue#}-{name}.md | `kb/specs/` | `/brainstorm` (design output) |
| Plan | PLAN-{issue#}-{name}.md | `kb/specs/` | `writing-plans` |
| Implementation | Code + tests | Worktree on feature branch | `TDD`, `executing-plans`, `subagent-driven-development` |

Each artifact links to its predecessor. Not every task needs all stages — a simple bug fix skips research/decision and may skip spec. Use judgement.

## Superpowers Plugin

**Artifact locations** — all knowledge artifacts are saved to `kb/` (gitignored, never committed):
- **Specs:** `kb/specs/SPEC-{issue#}-{short-name}.md`
- **Plans:** `kb/specs/PLAN-{issue#}-{short-name}.md`
- **Research:** `kb/decisions/RESEARCH-{topic}.md`
- **Decisions:** `kb/decisions/{NNN}-{short-name}.md`
- **Brainstorm mockups:** `.superpowers/brainstorm/` (ephemeral, gitignored)
- **Worktrees:** `.worktrees/`
- `kb/` is gitignored. Do not `git add` or `git commit` anything in `kb/`.

**Skill invocation order** — always invoke applicable skills before starting work:

| When | Skill | What it does |
|------|-------|-------------|
| Design/creative work | `/brainstorm` | Explores intent, proposes approaches, produces spec |
| Multi-step implementation | `writing-plans` | Decomposes spec into tasks, produces plan |
| Feature or bugfix | `TDD` | Tests first, then implement |
| Bug or test failure | `systematic-debugging` | Diagnose before fixing |
| Before commit/PR | `verification-before-completion` | Verify claims with evidence |
| After completing task | `requesting-code-review` | Review against plan and standards |
| Ready to integrate | `finishing-a-development-branch` | PR creation, merge options |
| 2+ independent tasks | `dispatching-parallel-agents` | Parallel agent coordination |

**Process skills first** (brainstorming, debugging), **then implementation skills** (TDD, plans). Follow rigid skills exactly.

## Branch Model

```
main (stable, always releasable)
├── dev/* (integration branches — agents land work here)
│   ├── dev/bugs-*
│   ├── dev/feat-*
│   └── dev/chore-*
├── dev/release (composed from selected dev/* for testing)
├── release/X.Y.Z (store-cut branch — version bump + tag; see kb/workflow/RELEASE.md)
└── feature branches (agent work: fix/*, feat/*, chore/*)
```

Full details: `kb/workflow/GIT-WORKFLOW.md`

**Key rules:**
- `main` is always stable. Never push directly.
- Agent work targets `dev/*` branches, not `main`.
- Agent chooses branch base per-task: `dev/*` if touching recent changes, `main` if independent.
- You create `dev/*` branches, agents target them.
- Gate 1 CI **runs** on `dev/*` PRs (should be green) but is **advisory — not a required check** on dev/* (the `dev branches` ruleset enforces only PR-required + conversation-resolution; Gate 1 is required only on `main`).
- Compose `dev/release` from selected `dev/*` branches before promoting to `main`.
- Fix forward, never revert on `dev/*`.

## CI/CD Gates

| Gate | Trigger | Time | Runner | What runs |
|------|---------|------|--------|-----------|
| Gate 1 | PR to dev/* or main | ~3-5 min | Cloud | format, analyze, unit/widget tests, coverage (80%), web build, debug APK. Required check on `main` only; advisory on dev/*. Job name: `Analyze, Test & Build` |
| Gate 1.5 | PR (advisory) | ~8-12 min | Self-hosted + phone | Maestro on physical device, real Firebase, real Google Sign-In |
| Gate 2 | Push to dev/release | ~5-7 min | Cloud | Gate 1 + distribute debug APK to `developers` group. Planned: Playwright, Patrol |
| Gate 3 | Push to main | ~8-10 min | Cloud | Gate 1 + release APK + distribute to `private-testers` group (alias, not display name — #247). Planned: Playwright, Patrol, Goldens (#48) |

## Testing

TDD is mandatory. Full strategy: `kb/workflow/TESTING.md`

**5-layer pyramid:** Unit → Widget → Golden → Integration (Patrol) → E2E (Maestro/Playwright)

**Coverage rule:** Every bug fix includes a test that reproduces the bug. Every feature includes tests for acceptance criteria. E2E required for cross-screen UI state changes.

## Commands

### Build & Run
- `flutter pub get` — install dependencies
- `flutter analyze` — static analysis
- `flutter run -d chrome --dart-define=FIREBASE_WEB_API_KEY=<key>` — run in Chrome
- `firebase emulators:start` — start Firebase emulators (Auth :9099, Firestore :8080, UI :4000)

### Testing
- `bash scripts/test-run.sh` — unified runner (all layers, timestamped output)
- `flutter test` — unit + widget + golden tests
- `npx playwright test` — web E2E
- `bash scripts/maestro-test.sh` — Android E2E on emulator (use `--tags smoke` for quick, `--flow <name>` for specific)
- `bash scripts/device-test.sh` — Android E2E on physical phone against real Firebase (use `--tags smoke`, `--skip-build`, `--skip-cleanup`)
- `bash scripts/patrol-test.sh` — Patrol integration tests

### Project Board
- `bash scripts/add-workstream.sh <name> --color <COLOR>` — add workstream option safely (never use raw GraphQL)
- `gh project item-list 1 --owner Chitiiran --limit 250 --format json` — fetch all project items (always use `--limit 250`)

### Release & Distribution
- `bash scripts/release.sh <version>` — create release branch with version bump
- `bash scripts/distribute.sh "Release notes"` — build, upload to Firebase App Distribution, tag

## Tech Stack
- Flutter 3.41.1 / Dart 3.11.0
- Firebase Auth (Google Sign-In), Cloud Firestore, Firebase Storage
- State management: Bloc (`AuthBloc`, `JournalBloc`, `ThemeCubit`, `VoiceNoteBloc`)
- LLM (split): `gemini-3.1-flash-live-preview` (live daily call — 2.5-native-audio had a tool-call socket-close bug, see gemini_live_service.dart) + `gemini-2.5-flash` (reconcile/categorize), via `firebase_ai ^3.12.2` (swappable `LlmService` interface).
- E2E: Playwright (web), Maestro (Android), Patrol (integration)

## Architecture
Clean architecture, features-based:
- `lib/core/` — constants (categories enum), theme
- `lib/data/` — models (DailyEntry, CategoryEntry), repositories (Firestore CRUD)
- `lib/features/` — UI screens: auth, daily_journal, settings
- `lib/services/` — auth service, LLM service, speech service

## Firestore Schema
```
users/{uid}/
  profile: { displayName, email, createdAt }
  dailyEntries/{date-string}/
    createdAt, updatedAt
    categoryEntries/{autoId}/
      category, text, source, createdAt
```

## Environment Variables
API keys in `.env` (gitignored), injected via `--dart-define`. See `.env.example`.

## Known Environment Issues
- **Windows `python3` is a broken MS Store stub** on this box — use `python` (the working interpreter). Scripts using `python3` shebangs may no-op silently. For `scripts/inject-audio.py`: `pip install grpcio grpcio-tools`.

## Worktrees
- Directory: `.worktrees/` (gitignored)
- Plans/specs stay on main (in `kb/`). Implementation in worktrees on feature branches.
- Agents: always use worktree's absolute path. Never write to project root.
- Post-merge: clean up worktree + local branch. Windows: `rm -rf` if `git worktree remove` fails.
- Session start: if 5+ worktrees exist, offer cleanup.

### Post-Implementation Chain (mandatory, never skip)

After `executing-plans` or `subagent-driven-development` completes ALL tasks:
1. `verification-before-completion` — run tests, verify claims with evidence
2. `finishing-a-development-branch` — handles PR creation (never create PR manually)
3. `requesting-code-review` — auto-chains after PR, never ask "want me to review?"
4. Update `kb/PROGRESS.md` — log entry with decisions/tradeoffs

Each step invokes the next. Do not stop between steps or ask the user.

### Blocker Protocol

When any workflow step fails (e.g., can't push branch, CI blocks, permission denied):
- **STOP.** Do not skip the step or make autonomous workarounds.
- **Report** the exact error to the user.
- **Ask** for direction before proceeding.
- Never retarget PRs, skip dev/* branches, or bypass workflow steps without explicit user approval.

## Conventions
- Files: `snake_case` (daily_journal_screen.dart)
- Classes: `PascalCase`
- Functions/variables: `camelCase`
- Constants: `UPPER_SNAKE_CASE`
- 2-space indentation, `dart format`
