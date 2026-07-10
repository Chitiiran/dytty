#!/usr/bin/env bats
# retro_age_days: date math for the weekly-retro session-start nudge.
# Delegates to scripts/lib/observation.py (finally wiring the tested-but-
# unwired date lib — audit finding B3) and must be safe on checkouts where
# kb/ doesn't exist (kb is local-only/gitignored).

setup() {
  load helpers
  setup_tmp
  SCRIPTS="$(scripts_dir)"
  source "$SCRIPTS/lib/retro-check.sh"
}

@test "missing file -> -1 (kb/ absent on this checkout)" {
  run retro_age_days "$BATS_TEST_TMPDIR/nope.md" "$SCRIPTS/lib"
  [ "$status" -eq 0 ]
  [ "$output" = "-1" ]
}

@test "file with no dated entry -> -1" {
  f="$BATS_TEST_TMPDIR/retro.md"
  printf '# Weekly Retro\n\nno entries yet\n' > "$f"
  run retro_age_days "$f" "$SCRIPTS/lib"
  [ "$output" = "-1" ]
}

@test "uses the LAST dated entry heading" {
  f="$BATS_TEST_TMPDIR/retro.md"
  today=$(date -u +%Y-%m-%d)
  printf '### 2020-01-01\nold\n\n### %s\nnew\n' "$today" > "$f"
  run retro_age_days "$f" "$SCRIPTS/lib"
  [ "$output" = "0" ]
}

@test "old entry reports its age in days" {
  f="$BATS_TEST_TMPDIR/retro.md"
  printf '### 2020-01-01\nancient\n' > "$f"
  run retro_age_days "$f" "$SCRIPTS/lib"
  [ "$output" -gt 2000 ]
}

@test "malformed date -> -1 (observation.py safe sentinel)" {
  f="$BATS_TEST_TMPDIR/retro.md"
  printf '### 2026-02-30\nbad\n' > "$f"
  run retro_age_days "$f" "$SCRIPTS/lib"
  [ "$output" = "-1" ]
}
