#!/usr/bin/env bash
# #231 daily-call multi-item RECALL sweep: runs each multi-item / guard
# scenario through the acoustic orchestrator and prints the per-scenario
# recall metric (verify.py score_recall) + an aggregate split-rate.
#
# Single-utterance daily-call scenarios share the tool-call flow (start call,
# play one utterance, hold for AI + tool calls, end call -> reconcile, wait for
# Call Summary so reconcile logcat lands). Retry-once for over-air noise.
#
# Prereqs: APK from this branch installed, WAVs generated, phone at speaker,
# quiet room. Usage: bash scripts/daily-call-recall-sweep.sh
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="$PROJECT_DIR/tools/acoustic-harness"
SCRIPTS_JSON="$PROJECT_DIR/test/fixtures/audio/test-scripts.json"
WAVS="$PROJECT_DIR/test/fixtures/audio/generated"
FLOW="$PROJECT_DIR/.maestro/voice/daily-call-tool-call.yaml"
OUT_DIR="$PROJECT_DIR/.sweep-out"
export ACOUSTIC_TAG="${ACOUSTIC_TAG:-DYTTY}"
mkdir -p "$OUT_DIR"

# Multi-item + guard scenarios that declare expected_items.
SCENARIOS=(
  multi-item-fifa-mixed-sentiment
  multi-item-straying-three-topics
  multi-item-two-framings-promotion
  multi-item-run-on-five-plus
  multi-item-incomplete-trailing-thought
  single-item-good-day
  no-item-liveness-check
  self-correction-final-state
)

source "$PROJECT_DIR/scripts/lib/env.sh"
EMAIL="${DEVICE_TEST_EMAIL:-$(read_env_var DEVICE_TEST_EMAIL "$PROJECT_DIR/.env")}"

echo "=== #231 daily-call recall sweep — ${#SCENARIOS[@]} scenarios ==="
pass=0; fail=0
for s in "${SCENARIOS[@]}"; do
  echo ""
  echo "--- $s ---"
  out="$OUT_DIR/$s.json"
  if python "$HARNESS/orchestrate.py" \
       --scenario "$s" \
       --scripts "$SCRIPTS_JSON" \
       --wavs "$WAVS" \
       --flow "$FLOW" \
       --tag "$ACOUSTIC_TAG" \
       --timeout 90 \
       --retries 1 \
       ${EMAIL:+--env "DEVICE_TEST_EMAIL=$EMAIL"} \
       > "$out" 2>&1; then
    echo "  PASS"
    pass=$((pass+1))
  else
    echo "  FAIL (see $out)"
    fail=$((fail+1))
  fi
  # Surface the recall line if verify.py emitted one.
  grep -iE "multi-item recall|recall=|over_split|hallucination" "$out" | head -3 || true
done

echo ""
echo "=== sweep done: $pass passed, $fail failed (of ${#SCENARIOS[@]}) ==="
echo "Per-scenario output: $OUT_DIR/"

# Propagate failures (sibling voice-sweep.sh already does) — without this a
# fully-failed sweep exits 0 and a future CI wiring would be false-green.
[[ "$fail" -eq 0 ]]
