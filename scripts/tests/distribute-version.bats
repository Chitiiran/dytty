#!/usr/bin/env bats
# Tests the extracted pure version-bump helper used by distribute.sh.

setup() {
  load helpers
  source "$(scripts_dir)/lib/version.sh"
}

@test "bump build number on a valid version" {
  run parse_and_bump_version "version: 1.2.3+4" false
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3+4	1.2.3+5" ]
}

@test "bump-patch increments patch and build" {
  run parse_and_bump_version "version: 1.2.3+4" true
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3+4	1.2.4+5" ]
}

@test "rejects a version with no build number" {
  run parse_and_bump_version "version: 1.2.3" false
  [ "$status" -ne 0 ]
}

@test "rejects a non-semver version" {
  run parse_and_bump_version "version: abc" false
  [ "$status" -ne 0 ]
}

@test "handles a version line with no trailing space variations" {
  run parse_and_bump_version "version: 0.1.9+15" false
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.9+15	0.1.9+16" ]
}

@test "tolerates a trailing CR (CRLF pubspec) — gemini #240" {
  run parse_and_bump_version $'version: 0.1.9+15\r' false
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.9+15	0.1.9+16" ]
}

@test "leading-zero build number is base-10, not octal — gemini #240" {
  run parse_and_bump_version "version: 1.2.3+09" false
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3+09	1.2.3+10" ]
}

@test "validate_semver accepts X.Y.Z" {
  run validate_semver "0.2.0"
  [ "$status" -eq 0 ]
}

@test "validate_semver rejects X.Y" {
  run validate_semver "0.2"
  [ "$status" -ne 0 ]
}

@test "validate_semver rejects X.Y.Z+N (release version must not carry build)" {
  run validate_semver "0.2.0+3"
  [ "$status" -ne 0 ]
}
