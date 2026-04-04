#!/usr/bin/env bash
# Clear logcat and start background capture for voice test session.
# Called by Maestro runScript at the start of each voice test flow.
#
# Required:
#   ACOUSTIC_TAG - logcat tag (e.g., DYTTY) — used in PID file naming
set -euo pipefail

SESSION_LOG="${VOICE_TEST_LOG:-/tmp/acoustic-voice-session.log}"
PID_FILE="/tmp/acoustic-logcat-pid"

# Clear existing logcat
adb logcat -c
echo "Logcat cleared"

# Kill any existing logcat capture
if [ -f "$PID_FILE" ]; then
  kill "$(cat "$PID_FILE")" 2>/dev/null || true
  rm -f "$PID_FILE"
fi

# Start background logcat capture (Flutter tag, verbose)
adb logcat -v time flutter:V '*:S' > "$SESSION_LOG" 2>&1 &
echo $! > "$PID_FILE"
echo "Logcat capture started -> $SESSION_LOG (PID: $(cat "$PID_FILE"))"
