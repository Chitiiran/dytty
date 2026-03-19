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

# --- Playwright ---
if [[ "$RUN_PLAYWRIGHT" == true ]]; then
  echo ""
  echo "=== Playwright tests ==="
  cd "$PROJECT_DIR"
  if npx playwright test 2>&1; then
    echo "  Playwright tests passed"
  else
    echo "  Playwright tests had failures"
    FAILURES=$((FAILURES + 1))
  fi
fi

# --- Maestro ---
if [[ "$RUN_MAESTRO" == true ]]; then
  echo ""
  echo "=== Maestro tests ==="
  cd "$PROJECT_DIR"
  if bash scripts/maestro-test.sh --output-dir "$RUN_DIR/device-e2e/maestro" --skip-build 2>&1; then
    echo "  Maestro tests completed"
  else
    echo "  Maestro tests had failures"
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
