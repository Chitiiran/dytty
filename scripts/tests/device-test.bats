#!/usr/bin/env bats
# Proves scripts/device-test.sh excludes audio-dependent voice flows by default
# (Gate 1.5 ran them untagged on every PR — daily-call flows start a real Gemini
# Live call, so the AI spoke out of the runner phone's speaker; voice-note flows
# stall without orchestrated room audio). The acoustic nightly owns voice flows;
# device runs get them back only with an explicit --include-voice.

setup() {
  load helpers
  setup_tmp
  SCRIPTS="$(scripts_dir)"
  PROJECT_DIR="$(cd "$SCRIPTS/.." && pwd)"
  export DEVICE_TEST_EMAIL="stub@example.com"
  export DEVICE_TEST_UID="stub-uid"
  # --skip-build requires the APK to already exist; placeholder if absent.
  APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
  APK_PREEXISTED=true
  if [ ! -f "$APK" ]; then APK_PREEXISTED=false; mkdir -p "$(dirname "$APK")"; echo fake > "$APK"; fi
  # Stub adb: exactly one PHYSICAL device (must not match 'emulator').
  make_fake adb '
case "$1" in
  devices) echo "List of devices attached"; echo "R58M000TEST	device" ;;
  *) : ;;
esac
exit 0'
  # Stub maestro: record the flow file (last argument) into $DEVICE_FLOWLOG,
  # write a passing junit xml, exit 0.
  make_fake maestro '
out=""; last=""
for a in "$@"; do last="$a"; done
while [ $# -gt 0 ]; do case "$1" in --output) out="$2"; shift 2;; *) shift;; esac; done
[ -n "$out" ] && { mkdir -p "$(dirname "$out")"; echo "<testsuites><testsuite failures=\"0\" tests=\"1\"></testsuite></testsuites>" > "$out"; }
echo "$last" >> "$DEVICE_FLOWLOG"
exit 0'
}

teardown() {
  if [ "${APK_PREEXISTED:-true}" = false ] && [ -f "$APK" ]; then rm -f "$APK"; fi
}

@test "device-test.sh skips .maestro/voice flows by default" {
  export DEVICE_FLOWLOG="$TEST_TMP/flows-default.log"
  run bash "$SCRIPTS/device-test.sh" --skip-build --skip-cleanup
  [ "$status" -eq 0 ]
  # Non-voice flows ran...
  grep -q "journal" "$DEVICE_FLOWLOG"
  grep -q "auth" "$DEVICE_FLOWLOG"
  # ...but nothing from the voice directory did.
  ! grep -q "voice" "$DEVICE_FLOWLOG"
}

@test "device-test.sh runs voice flows when --include-voice is passed" {
  export DEVICE_FLOWLOG="$TEST_TMP/flows-voice.log"
  run bash "$SCRIPTS/device-test.sh" --skip-build --skip-cleanup --include-voice
  [ "$status" -eq 0 ]
  grep -q "voice" "$DEVICE_FLOWLOG"
}
