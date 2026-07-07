# Scripts Index

One line per script: what it does, how to run it. Windows note: use `python`,
never `python3` (broken MS Store stub on the dev box).

## Test runners

| Script | Purpose |
|---|---|
| `test-run.sh` | Unified multi-layer runner (unit/widget → playwright → maestro), timestamped output under `test-output/` |
| `maestro-test.sh` | Maestro E2E on the Android **emulator** (`--tags smoke`, `--flow <name>`, `--skip-build`) |
| `device-test.sh` | Maestro E2E on the **physical phone** vs real Firebase (`--tags smoke`, `--skip-build`, `--skip-cleanup`, `--include-voice` — voice flows are excluded by default: they need orchestrated room audio and the daily-call ones play AI speech aloud) |
| `patrol-test.sh` | Patrol integration tests (`--flow auth`, `--skip-build`) |
| `voice-sweep.sh` | Nightly acoustic voice-note sweep (calibration gate + device lock); used by voice-nightly.yml |
| `daily-call-recall-sweep.sh` | #231 recall-metric data collection over 8 daily-call scenarios (manual) |
| `device-cleanup.sh` | Deletes the test user's `dailyEntries` from Firestore (needs `DEVICE_TEST_UID`) |

## Release & distribution

| Script | Purpose |
|---|---|
| `release.sh <X.Y.Z> [--dry-run]` | Cut `release/X.Y.Z` from main + validated version bump |
| `distribute.sh "notes"` | Build debug APK, upload to Firebase App Distribution, tag (local, ad-hoc) |

## Board / workflow

| Script | Purpose |
|---|---|
| `verify-workflow.sh --stage <s>` | Advisory pipeline checks (session-start, triage, batch, pr, post-merge). **Never run `--stage cleanup`** until the #236 defusal lands |
| `add-workstream.sh <name> --color <C>` | Safe board workstream-option add (id-preserving) |
| `edit-tag.sh` / `assign-tag.sh` | Safe tag rename/recolor/assign (id-preserving) |
| `pr-threads.sh <pr#>` | Read-only list of unresolved review threads |

## Diagnostics & tooling

| Script | Purpose |
|---|---|
| `android-diag.sh` | Notification-pipeline device diagnostics (8-link chain) |
| `inject-audio.py` | WAV → emulator virtual mic via gRPC (`pip install grpcio grpcio-tools`) |
| `lib/env.sh` | `read_env_var KEY FILE` — anchored, CR-stripping .env reader (use this, never raw grep) |
| `lib/version.sh` | Validated pubspec version parse/bump helpers |
| `lib/board-options.sh` | Board option mutations that preserve option ids |

## Script tests

- Bash: `scripts/tests/*.bats` via the vendored runner —
  `scripts/tests/bats/bin/bats scripts/tests/*.bats`
- Python: `python -m pytest scripts/test_inject_audio.py scripts/tests/test_observation.py`
- Not wired into CI yet (audit recommendation: a <1 min `scripts-test` job).
