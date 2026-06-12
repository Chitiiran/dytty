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
LOCK="$PROJECT_DIR/.device.lock"
export ACOUSTIC_TAG="${ACOUSTIC_TAG:-DYTTY}"

EMAIL="${DEVICE_TEST_EMAIL:-$(grep '^DEVICE_TEST_EMAIL=' "$PROJECT_DIR/.env" | cut -d= -f2)}"
if [[ -z "$EMAIL" ]]; then
  echo "ERROR: DEVICE_TEST_EMAIL not set and not in .env" >&2
  exit 2
fi

# Minimal device lock (#191): refuse to start if another run holds the
# phone; stale locks (>30 min) are reclaimed.
if [[ -f "$LOCK" ]]; then
  if [[ -n "$(find "$LOCK" -mmin -30 2>/dev/null)" ]]; then
    echo "ERROR: device locked by another run ($(cat "$LOCK")). Remove $LOCK if stale." >&2
    exit 3
  fi
  echo "WARN: reclaiming stale lock ($(cat "$LOCK"))"
fi
echo "voice-sweep pid=$$ started=$(date -Iseconds)" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

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
    grep -E "FAILED|WATCHDOG|NOT played" <<< "$out" | head -3 || true
  fi
done
echo "TOTAL: ${SECONDS}s"
exit $overall
