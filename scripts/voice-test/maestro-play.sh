#!/usr/bin/env bash
# Play a WAV file and wait for a logcat signal.
# Called by Maestro runScript during voice test flows.
#
# Environment variables (set by Maestro env:):
#   WAV       - WAV filename in test/fixtures/audio/generated/
#   WAIT_FOR  - Signal string to watch for in [DYTTY] logcat lines
#   TIMEOUT   - Timeout in seconds (default: 10)
#   DELAY     - Pre-play delay in seconds (default: 1.0)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WAV_PATH="$PROJECT_DIR/test/fixtures/audio/generated/${WAV}"
SESSION_LOG="${VOICE_TEST_LOG:-/tmp/dytty-voice-session.log}"

python "$SCRIPT_DIR/play.py" \
  --wav "$WAV_PATH" \
  --wait-for "${WAIT_FOR}" \
  --timeout "${TIMEOUT:-10}" \
  --delay "${DELAY:-1.0}" \
  --log "$SESSION_LOG"
