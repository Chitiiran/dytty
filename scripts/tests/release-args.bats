#!/usr/bin/env bats
# Tests release.sh argument parsing: order-independent --dry-run + semver validation.

setup() {
  load helpers
  source "$(scripts_dir)/lib/version.sh"
}

@test "version only -> dry-run false" {
  run parse_release_args 1.0.0
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0	false" ]
}

@test "version then --dry-run" {
  run parse_release_args 1.0.0 --dry-run
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0	true" ]
}

@test "--dry-run then version (order-independent)" {
  run parse_release_args --dry-run 1.0.0
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0	true" ]
}

@test "missing version is rejected" {
  run parse_release_args --dry-run
  [ "$status" -ne 0 ]
}

@test "non-semver version is rejected" {
  run parse_release_args abc
  [ "$status" -ne 0 ]
}

@test "unknown flag is rejected" {
  run parse_release_args 1.0.0 --bogus
  [ "$status" -ne 0 ]
}

@test "version with build suffix is rejected (release takes X.Y.Z)" {
  run parse_release_args 1.0.0+3
  [ "$status" -ne 0 ]
}
