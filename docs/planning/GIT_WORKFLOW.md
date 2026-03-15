# Git Workflow & Change Management

> Standard process for tracking changes in Dytty. Claude and contributors must follow this.

---

## 1. GitHub Issues = Source of Truth

Every non-trivial change starts as a **GitHub Issue**.

- **Bugs**: label `bug` + priority label (`P0-critical` to `P3-someday`)
- **Features**: label `feature` + priority label
- **Chores**: label `chore` (CI, deps, config)
- **Refactors**: label `refactor`

Assign a **Milestone** (M0-M7) when the issue belongs to a known roadmap item.

### Creating an issue (CLI)
```bash
gh issue create --title "Short description" \
  --body "Details, acceptance criteria" \
  --label "feature,P1-important" \
  --milestone "M3: Voice Call Prototypes"
```

### Priority levels
| Label | Meaning |
|-------|---------|
| `P0-critical` | Broken/blocking — fix immediately |
| `P1-important` | Affects daily use — fix during current milestone |
| `P2-nice-to-have` | Next milestone or when capacity allows |
| `P3-someday` | When time permits |

---

## 2. Branching

### Branch model: `develop` + `release/*` + `main`

```
main ──────────────────────────── (stable, every commit = release)
  ^                          ^
  |  merge after gates pass  |
  |                          |
release/0.2.0 ── fix ──    release/0.3.0
  ^                          ^
  |  branch when ready       |
  |                          |
develop ── feat ── feat ── feat ── (integration branch, all PRs land here)
  ^    ^    ^
  |    |    |
feat/ fix/ chore/              (feature branches, short-lived)
```

| Branch | Purpose | Protection | Merge target |
|--------|---------|------------|--------------|
| `main` | Production-ready. Every commit is a release. | PR required, all CI green | — |
| `develop` | Integration. All feature PRs target this. | PR required, CI green | `main` (via release branch) |
| `release/X.Y.Z` | Release candidate. Only bug fixes allowed. | PR required | `main` + back-merge to `develop` |
| `feat/*`, `fix/*` | Feature work. Short-lived. | None | `develop` |

One branch per issue.

### Naming convention
```
<type>/<issue#>-<short-description>

Examples:
  feat/14-voice-recording-sheet
  fix/17-auth-null-user
  chore/20-update-flutter-sdk
  refactor/22-bloc-state-cleanup
```

**Types:** `feat`, `fix`, `chore`, `refactor`, `docs`, `test`

### Creating a branch (CLI)
```bash
git checkout develop
git pull origin develop
git checkout -b feat/14-voice-recording-sheet
```

### Release branches
```bash
# Automated:
bash scripts/release.sh 0.2.0

# Manual:
git checkout develop && git pull origin develop
git checkout -b release/0.2.0
# bump version in pubspec.yaml, commit, push
```

See `docs/planning/RELEASE.md` for full release process.

---

## 3. Conventional Commits

Every commit message follows this format:

```
<type>(<scope>): <what changed>

<why it changed — motivation, context>

<key decisions — non-obvious choices made, alternatives considered>

Refs #<issue>
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | `feat`, `fix`, `chore`, `refactor`, `docs`, `test` |
| `scope` | Optional | Area of code: `auth`, `voice`, `dashboard`, `ci`, `bloc` |
| `what` | Yes | Short imperative summary (max ~50 chars) |
| `why` | Yes | Motivation — the problem or goal |
| `key decisions` | When applicable | Architectural choices, tradeoffs, alternatives rejected |
| `Refs/Fixes/Closes` | Yes | Link to GitHub issue |

### Magic keywords (in commit or PR body)
- `Fixes #14` — closes the issue when PR merges
- `Closes #14` — same as Fixes
- `Refs #14` — links without closing (use for WIP or partial work)

### Examples

```
feat(voice): add recording bottom sheet with STT

Users need a quick way to capture voice notes from the dashboard.
The mic FAB triggers a bottom sheet that handles recording states.

Decisions:
- Used VoiceNoteBloc over simple StatefulWidget for testability
- speech_to_text over google_speech for zero-cost platform APIs
- Bottom sheet over full screen to keep context visible

Refs #14
```

```
fix(auth): handle null user on cold start

AuthBloc emitted authenticated before Firebase restored the session,
causing a null user crash on cold start.

Decisions:
- Added authStateChanges listener instead of checking currentUser
  synchronously, since Firebase hydrates auth state asynchronously

Fixes #17
```

```
chore(ci): add Firebase deploy secret to workflow

CI/CD deploy job was failing because the service account key
was missing from GitHub secrets.

Refs #5
```

### Commit frequency
Commit at logical checkpoints — each commit should be a coherent unit of work.
Multiple commits per branch is normal and encouraged.

---

## 4. Pull Requests

Every feature branch merges via a **Pull Request** to `develop`.
Release branches merge to `main` after all quality gates pass.

### PR title
Short, imperative. Same style as commit subject:
```
feat(voice): add recording bottom sheet (#14)
```

### PR body
The repo has a PR template (`.github/pull_request_template.md`). Fill it in:

1. **Summary**: What changed and why. Include `Fixes #<issue>` to auto-close.
2. **Key Decisions**: Non-obvious choices (same as commit decisions, but aggregated).
3. **Test Plan**: How it was verified.
4. **Screenshots**: For UI changes only.

### Creating a PR (CLI)
```bash
git push -u origin feat/14-voice-recording-sheet

gh pr create \
  --title "feat(voice): add recording bottom sheet (#14)" \
  --body "$(cat <<'EOF'
## Summary
Add voice recording bottom sheet triggered by mic FAB on dashboard.

Fixes #14

## Key Decisions
- VoiceNoteBloc for testability over StatefulWidget
- speech_to_text (free platform API) over google_speech

## Test Plan
- [ ] Manual: tap mic, speak, verify transcript appears
- [ ] Unit: VoiceNoteBloc state transitions
- [ ] CI passes

## Screenshots
[screenshot here]
EOF
)"
```

### Merge strategy
- **Squash merge** for feature branches (clean history on main)
- PR must pass CI before merge

---

## 5. Milestones

Milestones map to the roadmap (M0-M7). They group related issues.

| Milestone | Status |
|-----------|--------|
| M0: Foundation | Closed |
| M1: Anytime Voice Notes | Closed |
| M2: Dashboard + Daily Experience | Closed |
| M3: Voice Call Prototypes | Open |
| M4: Daily Call | Open |
| M5: Weekly Review | Open |
| M6: Configurable Categories + Polish | Open |
| M7: Launch Prep | Open |

View milestone progress on GitHub: **Issues > Milestones** tab.

---

## 6. Workflow Summary

```
1. Create/find GitHub Issue (#14)
2. Branch from develop:  git checkout -b feat/14-voice-recording-sheet
3. Code + commit (conventional commits, reference #14)
4. Push:    git push -u origin feat/14-voice-recording-sheet
5. PR:      gh pr create --base develop (use template, include Fixes #14)
6. CI passes → squash merge to develop
7. Issue #14 auto-closes
8. When ready for release: bash scripts/release.sh X.Y.Z
9. Release branch → dogfooding → merge to main
```

---

## 7. Claude-Specific Instructions

When Claude is asked to implement a feature or fix a bug:

1. **Check for existing issue** — search with `gh issue list` before creating a new one
2. **Create issue if none exists** — with appropriate labels and milestone
3. **Create branch** from `develop` using the naming convention
4. **Commit with full context** — type, scope, what, why, key decisions, issue ref
5. **Always ask before pushing** — never push to remote without user confirmation
6. **Always ask before creating PRs** — present the PR title and summary first
7. **Update PROGRESS.md** at end of session as usual
8. **Do not close issues manually** — let `Fixes #N` in the PR handle it

### Finding issues and milestones (CLI reference)
```bash
gh issue list                          # all open issues
gh issue list --label "bug"            # filter by label
gh issue list --milestone "M3: Voice Call Prototypes"  # filter by milestone
gh issue view 14                       # view issue details
gh pr list                             # open PRs
gh pr view 15                          # view PR details
```
