#!/usr/bin/env bash
# Verify voice test results from logcat session log.
# Called by Maestro runScript at the end of voice test flows.
#
# Environment variables (set by Maestro env:):
#   SCENARIO  - Scenario name from test-scripts.json
#
# Required:
#   ACOUSTIC_HARNESS_HOME - path to acoustic-test-harness repo
#   ACOUSTIC_TAG          - logcat tag (e.g., DYTTY)
set -euo pipefail

if [ -z "${ACOUSTIC_HARNESS_HOME:-}" ]; then
  echo "ERROR: ACOUSTIC_HARNESS_HOME not set" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION_LOG="${VOICE_TEST_LOG:-/tmp/dytty-voice-session.log}"
SCRIPTS_JSON="$PROJECT_DIR/test/fixtures/audio/test-scripts.json"

# Stop logcat capture
if [ -f /tmp/dytty-logcat-pid ]; then
  kill "$(cat /tmp/dytty-logcat-pid)" 2>/dev/null || true
  rm -f /tmp/dytty-logcat-pid
fi

# Small delay to let logcat flush
sleep 1

python "$ACOUSTIC_HARNESS_HOME/verify.py" \
  --log "$SESSION_LOG" \
  --scenario "${SCENARIO}" \
  --scripts "$SCRIPTS_JSON"
