#!/usr/bin/env bash
# Verify voice test results from logcat session log.
# Called by Maestro runScript at the end of voice test flows.
#
# Environment variables (set by Maestro env:):
#   SCENARIO  - Scenario name from test-scripts.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_LOG="${VOICE_TEST_LOG:-/tmp/dytty-voice-session.log}"

# Stop logcat capture
if [ -f /tmp/dytty-logcat-pid ]; then
  kill "$(cat /tmp/dytty-logcat-pid)" 2>/dev/null || true
  rm -f /tmp/dytty-logcat-pid
fi

# Small delay to let logcat flush
sleep 1

python "$SCRIPT_DIR/verify.py" \
  --log "$SESSION_LOG" \
  --scenario "${SCENARIO}"
