#!/usr/bin/env bash
# Device E2E test runner for Dytty Android app
#
# Runs Maestro flows on a physical device against real Firebase.
# Used by Gate 1.5 (self-hosted CI) and for manual pre-demo testing.
#
# Usage:
#   bash scripts/device-test.sh                    # Run all flows
#   bash scripts/device-test.sh --tags smoke       # Run flows tagged 'smoke'
#   bash scripts/device-test.sh --skip-build       # Skip APK build (reuse existing)
#   bash scripts/device-test.sh --skip-cleanup     # Skip Firestore data cleanup
#
# Prerequisites:
#   - Physical Android device connected via USB (adb devices)
#   - Maestro CLI installed (maestro --version)
#   - Firebase CLI installed (firebase --version) -- for cleanup
#   - .env file with FIREBASE_ANDROID_API_KEY

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAESTRO_DIR="$PROJECT_DIR/.maestro"
HELPERS_DIR="$MAESTRO_DIR/helpers"
SCREENSHOT_DIR="$PROJECT_DIR/test-output/latest/device-e2e/device"
APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

# Parse arguments
TAGS=""
SKIP_BUILD=false
SKIP_CLEANUP=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --tags)
      TAGS="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --skip-cleanup)
      SKIP_CLEANUP=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Add adb and maestro to PATH if needed
export PATH="$PATH:$HOME/.maestro/bin"
if [[ -d "$LOCALAPPDATA/Android/Sdk/platform-tools" ]]; then
  export PATH="$PATH:$LOCALAPPDATA/Android/Sdk/platform-tools"
fi

# ── Load test email from .env if not set ──────────────
if [[ -z "${DEVICE_TEST_EMAIL:-}" && -f "$PROJECT_DIR/.env" ]]; then
  DEVICE_TEST_EMAIL=$(grep DEVICE_TEST_EMAIL "$PROJECT_DIR/.env" | cut -d= -f2 || true)
fi
if [[ -z "${DEVICE_TEST_EMAIL:-}" ]]; then
  echo "ERROR: DEVICE_TEST_EMAIL not set. Add to .env or export it."
  exit 1
fi
export DEVICE_TEST_EMAIL

# ── Cleanup trap ──────────────────────────────────────
# Always restore the original login helper, even on failure
cleanup() {
  echo ""
  echo "=== Restoring login helper ==="
  if [[ -f "$HELPERS_DIR/login.yaml.bak" ]]; then
    mv "$HELPERS_DIR/login.yaml.bak" "$HELPERS_DIR/login.yaml"
    echo "  Restored original login.yaml"
  fi
}
trap cleanup EXIT

# ── Prerequisites ─────────────────────────────────────
echo "=== Checking prerequisites ==="

if ! command -v maestro &>/dev/null; then
  echo "ERROR: Maestro CLI not found. Install: curl -fsSL https://get.maestro.mobile.dev | bash"
  exit 1
fi

if ! command -v adb &>/dev/null; then
  echo "ERROR: adb not found. Ensure Android SDK platform-tools is in PATH."
  exit 1
fi

# Check for physical device (not emulator)
DEVICE_LIST=$(adb devices | grep 'device$' | grep -v 'emulator' || true)
DEVICE_COUNT=$(echo "$DEVICE_LIST" | grep -c '.' || true)
if [[ "$DEVICE_COUNT" -eq 0 ]]; then
  echo "ERROR: No physical Android device connected. Plug in a phone with USB debugging enabled."
  exit 1
fi
DEVICE_SERIAL=$(echo "$DEVICE_LIST" | head -1 | awk '{print $1}')
echo "  Device: $DEVICE_SERIAL"
echo "  Maestro version: $(maestro --version 2>/dev/null | tail -1)"

# ── Build APK (real Firebase) ─────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
  echo ""
  echo "=== Building debug APK (real Firebase) ==="

  # Load API key from .env if present
  FIREBASE_KEY="${FIREBASE_ANDROID_API_KEY:-}"
  if [[ -z "$FIREBASE_KEY" && -f "$PROJECT_DIR/.env" ]]; then
    FIREBASE_KEY=$(grep FIREBASE_ANDROID_API_KEY "$PROJECT_DIR/.env" | cut -d= -f2 || true)
  fi

  cd "$PROJECT_DIR"
  flutter build apk --debug \
    --dart-define=FIREBASE_ANDROID_API_KEY="${FIREBASE_KEY:-dummy}"
  echo "  APK: $APK_PATH"
else
  echo "  Skipping build (--skip-build)"
  if [[ ! -f "$APK_PATH" ]]; then
    echo "ERROR: APK not found at $APK_PATH. Run without --skip-build first."
    exit 1
  fi
fi

# ── Install APK ───────────────────────────────────────
echo ""
echo "=== Installing APK on device ==="
adb -s "$DEVICE_SERIAL" install -r "$APK_PATH"

# ── Swap login helper ─────────────────────────────────
echo ""
echo "=== Swapping login helper for device (real Google Sign-In) ==="
cp "$HELPERS_DIR/login.yaml" "$HELPERS_DIR/login.yaml.bak"
cp "$HELPERS_DIR/login-device.yaml" "$HELPERS_DIR/login.yaml"
echo "  login.yaml -> login-device.yaml (real Google Sign-In)"

# ── Pre-run cleanup: clear test data so flows start from zero ──
if [[ "$SKIP_CLEANUP" == false ]] && command -v firebase &>/dev/null; then
  echo ""
  echo "=== Pre-run: cleaning test data from Firestore ==="
  bash "$SCRIPT_DIR/device-cleanup.sh" 2>/dev/null || echo "  WARNING: Pre-run cleanup failed (non-fatal)"
fi

# ── Create output directory ───────────────────────────
mkdir -p "$SCREENSHOT_DIR"

# ── Write env.json metadata ──────────────────────────
DEVICE_MODEL=$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
DEVICE_SDK=$(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
cat > "$SCREENSHOT_DIR/env.json" <<ENVJSON
{
  "runner": "physical",
  "device": "${DEVICE_MODEL:-unknown}",
  "serial": "${DEVICE_SERIAL}",
  "sdk": "${DEVICE_SDK:-unknown}",
  "platform": "android"
}
ENVJSON

# ── Run Maestro flows ─────────────────────────────────
echo ""
echo "=== Running Maestro flows on device ==="
echo "  Screenshots: $SCREENSHOT_DIR"
echo ""

MAESTRO_BASE="maestro test"
MAESTRO_BASE="$MAESTRO_BASE --debug-output $SCREENSHOT_DIR"
MAESTRO_BASE="$MAESTRO_BASE --format junit"

if [[ -n "$TAGS" ]]; then
  MAESTRO_BASE="$MAESTRO_BASE --include-tags=$TAGS"
fi

FLOW_RESULTS_DIR="$SCREENSHOT_DIR/flow-results"
mkdir -p "$FLOW_RESULTS_DIR"
FLOW_INDEX=0
TEST_FAILED=false

for dir in "$MAESTRO_DIR"/*/; do
  dirname=$(basename "$dir")
  [[ "$dirname" == "helpers" || "$dirname" == "screenshots" ]] && continue

  shopt -s nullglob
  yamls=("$dir"*.yaml)
  shopt -u nullglob
  [[ ${#yamls[@]} -eq 0 ]] && continue

  echo "--- Running $dirname flows ---"
  for flow in "${yamls[@]}"; do
    flowname=$(basename "$flow")
    echo "  > $flowname"
    # Clean test data between flows so each starts from zero
    if [[ "$SKIP_CLEANUP" == false ]] && command -v firebase &>/dev/null; then
      bash "$SCRIPT_DIR/device-cleanup.sh" 2>/dev/null || true
    fi
    if ! $MAESTRO_BASE --output "$FLOW_RESULTS_DIR/$FLOW_INDEX.xml" "$flow" 2>&1; then
      TEST_FAILED=true
    fi
    FLOW_INDEX=$((FLOW_INDEX + 1))
  done
  echo ""
done

# ── Merge results ─────────────────────────────────────
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<testsuites>'
  for xml in "$FLOW_RESULTS_DIR"/*.xml; do
    [[ -f "$xml" ]] || continue
    sed -n '/<testsuite /,/<\/testsuite>/p' "$xml" 2>/dev/null
  done
  echo '</testsuites>'
} > "$SCREENSHOT_DIR/results.xml"

# ── Cleanup test data ─────────────────────────────────
if [[ "$SKIP_CLEANUP" == false ]]; then
  echo ""
  echo "=== Cleaning up test data from Firestore ==="
  if command -v firebase &>/dev/null; then
    bash "$SCRIPT_DIR/device-cleanup.sh" || echo "  WARNING: Cleanup failed (non-fatal)"
  else
    echo "  SKIP: Firebase CLI not installed. Test data not cleaned."
  fi
fi

# ── Summary ───────────────────────────────────────────
echo ""
echo "=== Done ==="
echo "  Screenshots: $SCREENSHOT_DIR"
echo "  JUnit results: $SCREENSHOT_DIR/results.xml"

SCREENSHOT_COUNT=$(find "$SCREENSHOT_DIR" -name "*.png" 2>/dev/null | wc -l)
echo "  Screenshots captured: $SCREENSHOT_COUNT"

if [[ "$TEST_FAILED" == true ]]; then
  echo ""
  echo "  RESULT: SOME TESTS FAILED -- check results.xml and screenshots"
  exit 1
else
  echo ""
  echo "  RESULT: ALL TESTS PASSED"
fi
