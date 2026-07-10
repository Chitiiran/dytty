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

@test "read_pubspec_version returns the version value" {
  f="$BATS_TEST_TMPDIR/pubspec.yaml"
  printf 'name: x\nversion: 1.2.3+7\n' > "$f"
  run bash -c "source '$(scripts_dir)/lib/version.sh'; read_pubspec_version '$f'"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3+7" ]
}

@test "read_pubspec_version strips CR from CRLF pubspec" {
  f="$BATS_TEST_TMPDIR/pubspec.yaml"
  printf 'version: 1.2.3+7\r\n' > "$f"
  run bash -c "source '$(scripts_dir)/lib/version.sh'; read_pubspec_version '$f'"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3+7" ]
}

@test "read_pubspec_version rejects a version without build suffix" {
  f="$BATS_TEST_TMPDIR/pubspec.yaml"
  printf 'version: 1.2.3\n' > "$f"
  run bash -c "source '$(scripts_dir)/lib/version.sh'; read_pubspec_version '$f'"
  [ "$status" -ne 0 ]
}

@test "read_pubspec_version fails on a pubspec with no version line" {
  f="$BATS_TEST_TMPDIR/pubspec.yaml"
  printf 'name: x\n' > "$f"
  run bash -c "source '$(scripts_dir)/lib/version.sh'; read_pubspec_version '$f'"
  [ "$status" -ne 0 ]
}
