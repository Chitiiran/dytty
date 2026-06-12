#!/usr/bin/env bash
# Voice E2E sweep: calibration gate, then every voice-note flow through
# the acoustic harness orchestrator with retry-once.
#
# Logic lives in the unit-tested harness (tools/acoustic-harness); this
# script is the shared entry point for the nightly job and humans.
#
# Usage: bash scripts/voice-sweep.sh [--skip-calibration]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="${ACOUSTIC_HARNESS_HOME:-$PROJECT_DIR/tools/acoustic-harness}"
SCRIPTS_JSON="$PROJECT_DIR/test/fixtures/audio/test-scripts.json"
WAVS="$PROJECT_DIR/test/fixtures/audio/generated"
LOCK_DIR="$PROJECT_DIR/.device.lock.d"
export ACOUSTIC_TAG="${ACOUSTIC_TAG:-DYTTY}"

# -f2- (not -f2): values may contain '='. || true: missing file/key must
# reach the friendly error below, not die on set -e at the assignment.
EMAIL="${DEVICE_TEST_EMAIL:-$(grep '^DEVICE_TEST_EMAIL=' "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2- || true)}"
if [[ -z "$EMAIL" ]]; then
  echo "ERROR: DEVICE_TEST_EMAIL not set and not in .env" >&2
  exit 2
fi

# Device lock (#191): mkdir is atomic — no check-then-write race.
# Staleness from the epoch timestamp inside the lock (find -mmin is
# unreliable when PATH resolves Windows' find.exe).
acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$(date +%s) pid=$$" > "$LOCK_DIR/owner"
    return 0
  fi
  local held_at now
  held_at=$(cut -d' ' -f1 "$LOCK_DIR/owner" 2>/dev/null || echo 0)
  now=$(date +%s)
  if (( now - held_at < 1800 )); then
    echo "ERROR: device locked ($(cat "$LOCK_DIR/owner" 2>/dev/null)). Remove $LOCK_DIR if stale." >&2
    exit 3
  fi
  echo "WARN: reclaiming stale lock ($(cat "$LOCK_DIR/owner" 2>/dev/null))"
  echo "$(date +%s) pid=$$" > "$LOCK_DIR/owner"
}
acquire_lock
trap 'rm -rf "$LOCK_DIR"' EXIT

if [[ "${1:-}" != "--skip-calibration" ]]; then
  python "$HARNESS/calibrate.py" \
    --tone "$PROJECT_DIR/test/fixtures/audio/test-tone-1khz.wav" --runs 2
fi

# WAVs are gitignored; generate if missing (cached by content hash).
python "$HARNESS/generate.py" --scripts "$SCRIPTS_JSON" --output "$WAVS"

FLOWS=(
  voice-note-basic
  voice-note-category-select
  voice-note-discard
  voice-note-edit-transcript
  voice-note-edited-badge
  voice-note-no-tags
  voice-note-re-summarize
  voice-note-save-disabled
)

overall=0
SECONDS=0
for f in "${FLOWS[@]}"; do
  t0=$SECONDS
  # All flows share one spoken input (voice-note-basic scenario) by
  # design — they diverge AFTER the transcript arrives.
  if out=$(python "$HARNESS/orchestrate.py" \
      --scenario voice-note-basic \
      --scripts "$SCRIPTS_JSON" --wavs "$WAVS" \
      --flow "$PROJECT_DIR/.maestro/voice/$f.yaml" \
      --tag "$ACOUSTIC_TAG" --timeout 90 --retries 1 \
      --env DEVICE_TEST_EMAIL="$EMAIL" 2>&1); then
    status=PASS
  else
    status=FAIL
    overall=1
  fi
  retries=$(grep -c RETRY <<< "$out" || true)
  echo "$f: $status $((SECONDS - t0))s retries=$retries"
  if [[ "$status" == FAIL ]]; then
    grep -iE "fail|watchdog|not played" <<< "$out" | head -4 || true
  fi
done
echo "TOTAL: ${SECONDS}s"
exit $overall
