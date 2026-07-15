#!/usr/bin/env bats
# Smoke test: verifies the vendored bats runner + helpers work.

setup() {
  load helpers
  setup_tmp
}

@test "setup_tmp creates an isolated workdir and fake-bin on PATH" {
  [ -d "$TEST_TMP" ]
  [ -d "$FAKEBIN" ]
  case ":$PATH:" in *":$FAKEBIN:"*) : ;; *) false ;; esac
}

@test "make_fake puts an executable stub on PATH" {
  make_fake mytool 'echo hello-from-fake; exit 0'
  run mytool
  [ "$status" -eq 0 ]
  [ "$output" = "hello-from-fake" ]
}

@test "a failing fake propagates non-zero status" {
  make_fake failtool 'exit 3'
  run failtool
  [ "$status" -eq 3 ]
}
