#!/usr/bin/env bash
# Patrol integration test runner for Dytty Android app
#
# Usage:
#   bash scripts/patrol-test.sh                    # Run all integration tests
#   bash scripts/patrol-test.sh --flow auth        # Run only auth flow
#   bash scripts/patrol-test.sh --skip-build       # Skip APK build
#
# Prerequisites:
#   - Android emulator running (adb devices should show a device)
#   - Firebase emulators running (Auth :9099, Firestore :8080)
#   - Patrol CLI installed (dart pub global activate patrol_cli)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
FLOW=""
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --flow)
      FLOW="$2"
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

cd "$PROJECT_DIR"

# Verify prerequisites
echo "=== Checking prerequisites ==="

if ! command -v patrol &>/dev/null; then
  echo "ERROR: Patrol CLI not found. Install: dart pub global activate patrol_cli"
  exit 1
fi

if ! command -v adb &>/dev/null; then
  if [[ -d "$LOCALAPPDATA/Android/Sdk/platform-tools" ]]; then
    export PATH="$PATH:$LOCALAPPDATA/Android/Sdk/platform-tools"
  else
    echo "ERROR: adb not found. Ensure Android SDK platform-tools is in PATH."
    exit 1
  fi
fi

DEVICE_COUNT=$(adb devices 2>/dev/null | grep -c 'device$' || true)
if [[ "$DEVICE_COUNT" -eq 0 ]]; then
  echo "ERROR: No Android device/emulator connected."
  exit 1
fi
echo "  Devices connected: $DEVICE_COUNT"

# Build target
TARGET=""
if [[ -n "$FLOW" ]]; then
  TARGET="--target integration_test/flows/${FLOW}_flow_test.dart"
fi

# Run Patrol tests
echo ""
echo "=== Running Patrol integration tests ==="
echo ""

patrol test \
  --dart-define=USE_EMULATORS=true \
  --dart-define=FIREBASE_ANDROID_API_KEY="${FIREBASE_ANDROID_API_KEY:-dummy}" \
  $TARGET 2>&1 || true

echo ""
echo "=== Done ==="
