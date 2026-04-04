#!/usr/bin/env bash
# Clear logcat and start background capture for voice test session.
# Called by Maestro runScript at the start of each voice test flow.
set -euo pipefail

SESSION_LOG="${VOICE_TEST_LOG:-/tmp/dytty-voice-session.log}"

# Clear existing logcat
adb logcat -c
echo "Logcat cleared"

# Kill any existing logcat capture
if [ -f /tmp/dytty-logcat-pid ]; then
  kill "$(cat /tmp/dytty-logcat-pid)" 2>/dev/null || true
  rm -f /tmp/dytty-logcat-pid
fi

# Start background logcat capture (Flutter tag, verbose)
adb logcat -v time flutter:V '*:S' > "$SESSION_LOG" 2>&1 &
echo $! > /tmp/dytty-logcat-pid
echo "Logcat capture started -> $SESSION_LOG (PID: $(cat /tmp/dytty-logcat-pid))"
