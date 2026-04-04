#!/usr/bin/env bash
# Play a WAV file, optionally waiting for a logcat signal.
# Called by Maestro runScript during voice test flows.
#
# Environment variables (set by Maestro env:):
#   WAV        - WAV filename in test/fixtures/audio/generated/
#   WAIT_FOR   - Signal string to watch for in tagged logcat lines (ignored in play-only)
#   TIMEOUT    - Timeout in seconds (default: 10)
#   DELAY      - Pre-play delay in seconds (default: 0)
#   PLAY_ONLY  - Set to "true" to skip logcat monitoring (for on-device STT)
#
# Required:
#   ACOUSTIC_HARNESS_HOME - path to acoustic-test-harness repo
#   ACOUSTIC_TAG          - logcat tag (not required when PLAY_ONLY=true)
set -euo pipefail

if [ -z "${ACOUSTIC_HARNESS_HOME:-}" ]; then
  echo "ERROR: ACOUSTIC_HARNESS_HOME not set" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WAV_PATH="$PROJECT_DIR/test/fixtures/audio/generated/${WAV}"
SESSION_LOG="${VOICE_TEST_LOG:-/tmp/acoustic-voice-session.log}"

if [ "${PLAY_ONLY:-}" = "true" ]; then
  python "$ACOUSTIC_HARNESS_HOME/play.py" \
    --wav "$WAV_PATH" \
    --play-only \
    --delay "${DELAY:-0}"
else
  python "$ACOUSTIC_HARNESS_HOME/play.py" \
    --wav "$WAV_PATH" \
    --wait-for "${WAIT_FOR}" \
    --timeout "${TIMEOUT:-10}" \
    --delay "${DELAY:-0}" \
    --log "$SESSION_LOG"
fi
