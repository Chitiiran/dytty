#!/usr/bin/env bash
# Smoke test for board-options.sh pure-ish guards (no gh calls exercised here).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/board-options.sh"

fail=0

# bo_apply_options must refuse an empty desired array WITHOUT calling gh.
if bo_apply_options "DUMMY_FIELD" "[]" 2>/dev/null; then
  echo "FAIL: bo_apply_options accepted empty array"; fail=1
else
  echo "PASS: bo_apply_options refused empty array"
fi

# It must also refuse whitespace-only / non-array.
if bo_apply_options "DUMMY_FIELD" "" 2>/dev/null; then
  echo "FAIL: bo_apply_options accepted empty string"; fail=1
else
  echo "PASS: bo_apply_options refused empty string"
fi

# Constants must be exported.
[[ "$PROJECT_ID" == "PVT_kwHOAKyMRs4BTnrv" ]] && echo "PASS: PROJECT_ID set" || { echo "FAIL: PROJECT_ID"; fail=1; }
[[ "$STATUS_DONE_OPTION_ID" == "98236657" ]] && echo "PASS: STATUS_DONE id" || { echo "FAIL: STATUS_DONE id"; fail=1; }

exit $fail
