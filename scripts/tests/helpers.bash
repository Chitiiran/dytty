# Shared helpers for shell-script bats tests.
# Source from a .bats file with:  load helpers

# Create an isolated tmp workdir + fake-bin dir on PATH for each test.
# Sets: TEST_TMP (work dir), FAKEBIN (dir prepended to PATH for stubs).
setup_tmp() {
  TEST_TMP="$BATS_TEST_TMPDIR/work"
  FAKEBIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$TEST_TMP" "$FAKEBIN"
  export PATH="$FAKEBIN:$PATH"
}

# Write an executable fake binary onto PATH.
#   make_fake <name> <body...>
# The body is the script after the shebang.
make_fake() {
  local name="$1"; shift
  {
    echo '#!/usr/bin/env bash'
    printf '%s\n' "$@"
  } > "$FAKEBIN/$name"
  chmod +x "$FAKEBIN/$name"
}

# Absolute path to the scripts/ dir (parent of tests/), for invoking scripts under test.
scripts_dir() {
  cd "$BATS_TEST_DIRNAME/.." && pwd
}
