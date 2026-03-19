#!/usr/bin/env bash
# Unified test runner — orchestrates Flutter, Playwright, and Maestro test layers
# into timestamped output directories under test-output/runs/.
#
# Usage:
#   bash scripts/test-run.sh              # Run all layers
#   bash scripts/test-run.sh --flutter    # Flutter only
#   bash scripts/test-run.sh --playwright # Playwright only
#   bash scripts/test-run.sh --maestro    # Maestro only
#   bash scripts/test-run.sh --keep 5     # Keep only last 5 runs
#   bash scripts/test-run.sh --no-screenshots  # Omit screenshots from report

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_BASE="$PROJECT_DIR/test-output"

# Defaults
RUN_FLUTTER=false
RUN_PLAYWRIGHT=false
RUN_MAESTRO=false
RUN_ALL=true
KEEP=10
NO_SCREENSHOTS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --flutter)    RUN_FLUTTER=true; RUN_ALL=false; shift ;;
    --playwright) RUN_PLAYWRIGHT=true; RUN_ALL=false; shift ;;
    --maestro)    RUN_MAESTRO=true; RUN_ALL=false; shift ;;
    --all)        RUN_ALL=true; shift ;;
    --keep)       KEEP="$2"; shift 2 ;;
    --no-screenshots) NO_SCREENSHOTS=true; shift ;;
    *)            echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ "$RUN_ALL" == true ]]; then
  RUN_FLUTTER=true
  RUN_PLAYWRIGHT=true
  RUN_MAESTRO=true
fi

# Add Android SDK tools to PATH if available
if [[ -d "$LOCALAPPDATA/Android/Sdk/platform-tools" ]]; then
  export PATH="$PATH:$LOCALAPPDATA/Android/Sdk/platform-tools"
fi

# Generate Windows-safe timestamp (no colons)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H%M%S")
RUN_DIR="$OUTPUT_BASE/runs/$TIMESTAMP"

echo "=== Test run: $TIMESTAMP ==="
echo "  Layers: flutter=$RUN_FLUTTER playwright=$RUN_PLAYWRIGHT maestro=$RUN_MAESTRO"

# Create run directory structure
mkdir -p "$RUN_DIR"
[[ "$RUN_FLUTTER" == true ]] && mkdir -p "$RUN_DIR/flutter"
[[ "$RUN_PLAYWRIGHT" == true ]] && mkdir -p "$RUN_DIR/playwright/screenshots"
[[ "$RUN_MAESTRO" == true ]] && mkdir -p "$RUN_DIR/device-e2e/maestro"

# Create/update latest symlink/junction (before tests, so Playwright config can reference it)
LATEST="$OUTPUT_BASE/latest"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  LATEST_WIN=$(cygpath -w "$LATEST")
  RUN_WIN=$(cygpath -w "$RUN_DIR")
  # Remove existing junction without following it (rm -rf would delete target contents)
  cmd //c "rmdir $LATEST_WIN" > /dev/null 2>&1 || rm -f "$LATEST" 2>/dev/null || true
  # Create junction via cmd (no inner quotes — paths have no spaces)
  cmd //c "mklink /J $LATEST_WIN $RUN_WIN" > /dev/null 2>&1 || \
    ln -sf "runs/$TIMESTAMP" "$LATEST" 2>/dev/null || true
else
  rm -f "$LATEST" 2>/dev/null || true
  ln -snf "runs/$TIMESTAMP" "$LATEST"
fi

FAILURES=0

# --- Flutter ---
if [[ "$RUN_FLUTTER" == true ]]; then
  echo ""
  echo "=== Flutter tests ==="
  cd "$PROJECT_DIR"
  # Record environment metadata
  FLUTTER_VER=$(flutter --version --machine 2>/dev/null | grep 'frameworkVersion' | grep -o '"[0-9][^"]*"' | tr -d '"' || echo "unknown")
  DART_VER=$(dart --version 2>&1 | grep -oP 'Dart SDK version: \K[^ ]+' || echo "unknown")
  echo "{\"platform\":\"$(uname -s)\",\"flutter\":\"$FLUTTER_VER\",\"dart\":\"$DART_VER\"}" > "$RUN_DIR/flutter/env.json"

  if flutter test --coverage --machine > "$RUN_DIR/flutter/results.json" 2>"$RUN_DIR/flutter/stderr.log"; then
    echo "  Flutter tests passed"
  else
    echo "  Flutter tests had failures"
    FAILURES=$((FAILURES + 1))
  fi
  # Copy coverage data
  if [[ -f "$PROJECT_DIR/coverage/lcov.info" ]]; then
    cp "$PROJECT_DIR/coverage/lcov.info" "$RUN_DIR/flutter/lcov.info"
    echo "  Coverage data copied"
  fi
fi

# --- Playwright & Maestro (parallel after web build completes) ---
PW_PID=""
MAESTRO_PID=""

# Pre-build web app if Playwright is enabled, so the build lock is released
# before Maestro tries to install/launch the Android app.
if [[ "$RUN_PLAYWRIGHT" == true ]]; then
  echo ""
  echo "=== Building web app for Playwright ==="
  cd "$PROJECT_DIR"
  FIREBASE_WEB_API_KEY=$(grep -oP 'FIREBASE_WEB_API_KEY=\K.*' .env 2>/dev/null || echo "")
  export FIREBASE_WEB_API_KEY
  flutter build web --no-tree-shake-icons \
    --dart-define=USE_EMULATORS=true \
    --dart-define=FIREBASE_WEB_API_KEY="${FIREBASE_WEB_API_KEY:-}" 2>&1 | tail -3
fi

# Now launch both E2E layers in parallel
if [[ "$RUN_PLAYWRIGHT" == true ]]; then
  (
    echo ""
    echo "=== Playwright tests ==="
    cd "$PROJECT_DIR"
    if npx playwright test 2>&1; then
      echo "  Playwright tests passed"
    else
      echo "  Playwright tests had failures"
      exit 1
    fi
    # Extract browser info from results
    if [[ -f "$RUN_DIR/playwright/results.json" ]]; then
      BROWSER=$(node -e "const r=require('./$RUN_DIR/playwright/results.json'); console.log(r.config?.projects?.[0]?.name || 'chromium')" 2>/dev/null || echo "chromium")
      echo "{\"browser\":\"$BROWSER\",\"platform\":\"$(uname -s)\"}" > "$RUN_DIR/playwright/env.json"
    fi
  ) &
  PW_PID=$!
fi

if [[ "$RUN_MAESTRO" == true ]]; then
  (
    echo ""
    echo "=== Maestro tests ==="
    cd "$PROJECT_DIR"
    # Record device info
    DEVICE_NAME=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r' || echo "unknown")
    DEVICE_SDK=$(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r' || echo "unknown")
    DEVICE_SERIAL=$(adb get-serialno 2>/dev/null | tr -d '\r' || echo "unknown")
    echo "{\"device\":\"$DEVICE_NAME\",\"sdk\":\"$DEVICE_SDK\",\"serial\":\"$DEVICE_SERIAL\",\"platform\":\"android\"}" > "$RUN_DIR/device-e2e/maestro/env.json"

    if bash scripts/maestro-test.sh --output-dir "$RUN_DIR/device-e2e/maestro" --skip-build 2>&1; then
      echo "  Maestro tests completed"
    else
      echo "  Maestro tests had failures"
      exit 1
    fi
  ) &
  MAESTRO_PID=$!
fi

# Wait for E2E layers to finish
if [[ -n "$PW_PID" ]]; then
  if ! wait "$PW_PID"; then
    FAILURES=$((FAILURES + 1))
  fi
fi
if [[ -n "$MAESTRO_PID" ]]; then
  if ! wait "$MAESTRO_PID"; then
    FAILURES=$((FAILURES + 1))
  fi
fi

# --- Generate report ---
echo ""
echo "=== Generating report ==="
cd "$PROJECT_DIR"
REPORT_ARGS="--run-dir $RUN_DIR"
if [[ "$NO_SCREENSHOTS" == true ]]; then
  REPORT_ARGS="$REPORT_ARGS --no-screenshots"
fi
dart run tool/test_report.dart $REPORT_ARGS

# --- Prune old runs ---
if [[ -d "$OUTPUT_BASE/runs" ]]; then
  RUN_COUNT=$(ls -1d "$OUTPUT_BASE/runs"/*/ 2>/dev/null | wc -l)
  if [[ "$RUN_COUNT" -gt "$KEEP" ]]; then
    PRUNE_COUNT=$((RUN_COUNT - KEEP))
    echo ""
    echo "=== Pruning $PRUNE_COUNT old run(s) (keeping $KEEP) ==="
    ls -1d "$OUTPUT_BASE/runs"/*/ | head -n "$PRUNE_COUNT" | while read -r dir; do
      echo "  Removing: $(basename "$dir")"
      rm -rf "$dir"
    done
  fi
fi

# --- Summary ---
echo ""
echo "=== Done ==="
echo "  Run directory: $RUN_DIR"
echo "  Report: $RUN_DIR/report.html"
echo "  Latest: $LATEST"
if [[ "$FAILURES" -gt 0 ]]; then
  echo "  WARNING: $FAILURES layer(s) had failures"
  exit 1
fi
