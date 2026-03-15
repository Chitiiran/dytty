#!/usr/bin/env bash
# Maestro E2E test runner for Dytty Android app
#
# Usage:
#   bash scripts/maestro-test.sh                    # Run all flows
#   bash scripts/maestro-test.sh --flow auth        # Run only auth/ flows
#   bash scripts/maestro-test.sh --tags smoke       # Run flows tagged 'smoke'
#   bash scripts/maestro-test.sh --skip-build       # Skip APK build (reuse existing)
#
# Prerequisites:
#   - Android emulator running (adb devices should show a device)
#   - Firebase emulators running (Auth :9099, Firestore :8080)
#   - Maestro CLI installed (maestro --version)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAESTRO_DIR="$PROJECT_DIR/.maestro"
SCREENSHOT_DIR="$PROJECT_DIR/.maestro/screenshots/latest"
APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

# Parse arguments
FLOW=""
TAGS=""
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --flow)
      FLOW="$2"
      shift 2
      ;;
    --tags)
      TAGS="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
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

# Verify prerequisites
echo "=== Checking prerequisites ==="

if ! command -v maestro &>/dev/null; then
  echo "ERROR: Maestro CLI not found. Install: curl -fsSL https://get.maestro.mobile.dev | bash"
  exit 1
fi

if ! command -v adb &>/dev/null; then
  echo "ERROR: adb not found. Ensure Android SDK platform-tools is in PATH."
  exit 1
fi

DEVICE_COUNT=$(adb devices | grep -c 'device$' || true)
if [[ "$DEVICE_COUNT" -eq 0 ]]; then
  echo "ERROR: No Android device/emulator connected. Start one with: emulator -avd <avd_name>"
  exit 1
fi
echo "  Devices connected: $DEVICE_COUNT"
echo "  Maestro version: $(maestro --version 2>/dev/null | tail -1)"

# Build APK
if [[ "$SKIP_BUILD" == false ]]; then
  echo ""
  echo "=== Building debug APK with emulator config ==="
  cd "$PROJECT_DIR"
  flutter build apk --debug \
    --dart-define=USE_EMULATORS=true \
    --dart-define=FIREBASE_ANDROID_API_KEY="${FIREBASE_ANDROID_API_KEY:-dummy}"
  echo "  APK: $APK_PATH"
else
  echo "  Skipping build (--skip-build)"
  if [[ ! -f "$APK_PATH" ]]; then
    echo "ERROR: APK not found at $APK_PATH. Run without --skip-build first."
    exit 1
  fi
fi

# Install APK
echo ""
echo "=== Installing APK on emulator ==="
adb install -r "$APK_PATH"

# Disable stylus handwriting prompt (blocks text input on some emulators)
adb shell settings put secure stylus_handwriting_enabled 0 2>/dev/null
adb shell settings put secure show_stylus_handwriting_onboarding 0 2>/dev/null

# Create screenshot output directory
mkdir -p "$SCREENSHOT_DIR"

# Build maestro command
MAESTRO_CMD="maestro test"
MAESTRO_CMD="$MAESTRO_CMD --debug-output $SCREENSHOT_DIR"
MAESTRO_CMD="$MAESTRO_CMD --format junit"
MAESTRO_CMD="$MAESTRO_CMD --output $SCREENSHOT_DIR/results.xml"

if [[ -n "$TAGS" ]]; then
  MAESTRO_CMD="$MAESTRO_CMD --include-tags=$TAGS"
fi

# Determine what to test
echo ""
echo "=== Running Maestro flows ==="
echo "  Screenshots: $SCREENSHOT_DIR"
echo ""

if [[ -n "$FLOW" ]]; then
  # Run a specific subdirectory or file
  TARGET="$MAESTRO_DIR/$FLOW"
  if [[ -f "$TARGET" ]]; then
    echo "  Target: $TARGET"
    $MAESTRO_CMD "$TARGET" 2>&1 || true
  elif [[ -d "$TARGET" ]]; then
    echo "  Target: $TARGET"
    $MAESTRO_CMD "$TARGET" 2>&1 || true
  else
    echo "ERROR: $TARGET not found"
    exit 1
  fi
else
  # Run each flow file individually and sequentially to avoid parallel interference
  # (flows share a single emulator, so clearState in one flow can wipe another's data)
  TOTAL_PASS=0
  TOTAL_FAIL=0
  for dir in "$MAESTRO_DIR"/*/; do
    dirname=$(basename "$dir")
    # Skip helpers and screenshots directories
    [[ "$dirname" == "helpers" || "$dirname" == "screenshots" ]] && continue

    shopt -s nullglob
    yamls=("$dir"*.yaml)
    shopt -u nullglob
    [[ ${#yamls[@]} -eq 0 ]] && continue

    echo "--- Running $dirname flows ---"
    for flow in "${yamls[@]}"; do
      flowname=$(basename "$flow")
      echo "  > $flowname"
      $MAESTRO_CMD "$flow" 2>&1 || true
    done
    echo ""
  done
fi

# Summary
echo ""
echo "=== Done ==="
echo "  Screenshots saved to: $SCREENSHOT_DIR"
echo "  JUnit results: $SCREENSHOT_DIR/results.xml"

# Count screenshots
SCREENSHOT_COUNT=$(find "$SCREENSHOT_DIR" -name "*.png" 2>/dev/null | wc -l)
echo "  Screenshots captured: $SCREENSHOT_COUNT"

if [[ -f "$SCREENSHOT_DIR/results.xml" ]]; then
  PASSED=$(grep -c 'failures="0"' "$SCREENSHOT_DIR/results.xml" 2>/dev/null || echo "0")
  echo "  Test results: see $SCREENSHOT_DIR/results.xml"
fi
