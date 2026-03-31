# Dytty - Daily Journaling App

Voice-first daily journaling app with 5 structured categories. Flutter + Firebase + Bloc.

## Session Rituals

**Start of session:**
1. Read `kb/PROGRESS.md` — top section only (above `## Log`).
2. Run `gh issue list --limit 200` — GitHub Issues is the single source of truth.
3. Brief the user: current state, blockers, top-priority next items. Keep it to a few sentences.

**Before merging a PR:** Update `kb/PROGRESS.md` — refresh "Latest on main", update test counts, log key decisions/tradeoffs. Decisions get buried in PR bodies; capture them before they're lost.

**End of session:** Update `kb/PROGRESS.md` — refresh top section, append dated entry to `## Log`.

## Knowledge Base (`kb/`)

All project knowledge lives in `kb/` (gitignored, private IP). Navigate by the question you're trying to answer:

| Folder | Question it answers | Key files |
|--------|-------------------|-----------|
| `kb/decisions/` | "Why did we choose X?" | ADRs (001-009), RESEARCH-*.md |
| `kb/workflow/` | "How does work flow?" | GIT-WORKFLOW.md, CI-GATES.md, TESTING.md, RELEASE.md, FEEDBACK.md, DECISION-MAKING.md |
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
└── feature branches (agent work: fix/*, feat/*, chore/*)
```

Full details: `kb/workflow/GIT-WORKFLOW.md`

**Key rules:**
- `main` is always stable. Never push directly.
- Agent work targets `dev/*` branches, not `main`.
- Agent chooses branch base per-task: `dev/*` if touching recent changes, `main` if independent.
- You create `dev/*` branches, agents target them.
- PRs to `dev/*` require passing Gate 1 CI before merge.
- Compose `dev/release` from selected `dev/*` branches before promoting to `main`.
- Fix forward, never revert on `dev/*`.

## CI/CD Gates

3-tier gates — full details in `kb/workflow/CI-GATES.md`:

| Gate | Trigger | Time | Runner | What runs |
|------|---------|------|--------|-----------|
| Gate 1 | PR to dev/* | ~3-5 min | Cloud | format, analyze, unit/widget tests, coverage, web build. Patrol optional |
| Gate 1.5 | PR (any) | ~8-12 min | Self-hosted + phone | Maestro on physical device, real Firebase, real Google Sign-In. Advisory. → `device-e2e/device/` |
| Gate 2 | dev/release | ~10-15 min | Cloud | Gate 1 + debug APK, Playwright, Maestro smoke (emulator), Patrol. → `device-e2e/emulator/`. Auto-distributes on pass |
| Gate 3 | PR to main | ~15-20 min | Cloud | Gate 2 + release APK, full Maestro, goldens. Auto-deploys on merge |

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

### Release & Distribution
- `bash scripts/release.sh <version>` — create release branch with version bump
- `bash scripts/distribute.sh "Release notes"` — build, upload to Firebase App Distribution, tag

## Tech Stack
- Flutter 3.41.1 / Dart 3.11.0
- Firebase Auth (Google Sign-In), Cloud Firestore, Firebase Storage
- State management: Bloc (`AuthBloc`, `JournalBloc`, `ThemeCubit`, `VoiceNoteBloc`)
- LLM: Gemini 2.5 Flash via `firebase_ai` (swappable `LlmService` interface)
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
