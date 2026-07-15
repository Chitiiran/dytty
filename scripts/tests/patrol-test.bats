#!/usr/bin/env bats
# Proves scripts/patrol-test.sh propagates patrol failure as a non-zero exit
# (regression guard against the `|| true` false-green at line 80).

setup() {
  load helpers
  setup_tmp
  SCRIPTS="$(scripts_dir)"
  # Stub adb: report one connected device so the prereq check passes.
  make_fake adb '
case "$1" in
  devices) echo "List of devices attached"; echo "emulator-5554	device" ;;
  *) : ;;
esac
exit 0'
}

@test "patrol-test.sh exits non-zero when patrol fails" {
  make_fake patrol 'exit 1'
  run bash "$SCRIPTS/patrol-test.sh"
  [ "$status" -ne 0 ]
}

@test "patrol-test.sh exits zero when patrol passes" {
  make_fake patrol 'exit 0'
  run bash "$SCRIPTS/patrol-test.sh"
  [ "$status" -eq 0 ]
}
