#!/usr/bin/env bats
# Proves scripts/maestro-test.sh propagates flow failure as a non-zero exit
# (regression guard against the `|| true` false-green that always exited 0).

setup() {
  load helpers
  setup_tmp
  SCRIPTS="$(scripts_dir)"
  PROJECT_DIR="$(cd "$SCRIPTS/.." && pwd)"
  OUT="$TEST_TMP/out"
  # --skip-build requires the APK to already exist; create a placeholder so the
  # prereq check passes and we reach the flow-run logic under test.
  APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
  APK_PREEXISTED=true
  if [ ! -f "$APK" ]; then APK_PREEXISTED=false; mkdir -p "$(dirname "$APK")"; echo fake > "$APK"; fi
  # Stub adb: report exactly one connected device; no-op for install/shell.
  make_fake adb '
case "$1" in
  devices) echo "List of devices attached"; echo "emulator-5554	device" ;;
  *) : ;;
esac
exit 0'
}

teardown() {
  # Remove only the placeholder APK we created (never a real build artifact).
  if [ "${APK_PREEXISTED:-true}" = false ] && [ -f "$APK" ]; then rm -f "$APK"; fi
}

# Fake maestro that ALWAYS fails, writing a junit xml with a failure to --output.
fake_maestro_failing() {
  make_fake maestro '
out=""
while [ $# -gt 0 ]; do case "$1" in --output) out="$2"; shift 2;; *) shift;; esac; done
[ -n "$out" ] && { mkdir -p "$(dirname "$out")"; echo "<testsuites><testsuite failures=\"1\" tests=\"1\"></testsuite></testsuites>" > "$out"; }
exit 1'
}

# Fake maestro that passes, writing a clean junit xml.
fake_maestro_passing() {
  make_fake maestro '
out=""
while [ $# -gt 0 ]; do case "$1" in --output) out="$2"; shift 2;; *) shift;; esac; done
[ -n "$out" ] && { mkdir -p "$(dirname "$out")"; echo "<testsuites><testsuite failures=\"0\" tests=\"1\"></testsuite></testsuites>" > "$out"; }
exit 0'
}

@test "maestro-test.sh exits non-zero when a flow fails" {
  fake_maestro_failing
  run bash "$SCRIPTS/maestro-test.sh" --flow auth --skip-build --output-dir "$OUT"
  # Provide the APK that --skip-build expects, by pre-creating it.
  [ "$status" -ne 0 ]
}

@test "maestro-test.sh exits zero when all flows pass" {
  fake_maestro_passing
  run bash "$SCRIPTS/maestro-test.sh" --flow auth --skip-build --output-dir "$OUT"
  [ "$status" -eq 0 ]
}
