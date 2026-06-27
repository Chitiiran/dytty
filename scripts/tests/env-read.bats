#!/usr/bin/env bats
# Tests read_env_var: anchored .env extraction that ignores comments and keeps '=' in values.

setup() {
  load helpers
  setup_tmp
  source "$(scripts_dir)/lib/env.sh"
  ENVF="$TEST_TMP/.env"
  cat > "$ENVF" <<'EOF'
# FIREBASE_ANDROID_API_KEY=commented-should-be-ignored
DEVICE_TEST_EMAIL=tester@example.com
FIREBASE_ANDROID_API_KEY=real-key-value
TOKEN=abc=def=ghi
EOF
}

@test "reads a plain value" {
  run read_env_var DEVICE_TEST_EMAIL "$ENVF"
  [ "$status" -eq 0 ]
  [ "$output" = "tester@example.com" ]
}

@test "ignores a commented line and returns the real assignment" {
  run read_env_var FIREBASE_ANDROID_API_KEY "$ENVF"
  [ "$status" -eq 0 ]
  [ "$output" = "real-key-value" ]
}

@test "keeps '=' characters in the value (-f2- semantics)" {
  run read_env_var TOKEN "$ENVF"
  [ "$status" -eq 0 ]
  [ "$output" = "abc=def=ghi" ]
}

@test "missing var yields empty output, non-fatal" {
  run read_env_var NOPE "$ENVF"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
