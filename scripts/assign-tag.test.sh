#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

# Non-existent value option must be rejected with a helpful message (dry-run, no mutation).
OUT=$(bash "$ROOT/scripts/assign-tag.sh" --issue 218 --field Workstream --value "dev/does-not-exist" --dry-run --yes 2>&1 || true)
echo "$OUT"
echo "$OUT" | grep -qi "not found\|does not exist\|no option" && echo "PASS: unknown value rejected" || { echo "FAIL: unknown value not rejected"; fail=1; }

# Missing args rejected.
if bash "$ROOT/scripts/assign-tag.sh" --issue 218 --field Workstream 2>/dev/null; then
  echo "FAIL: accepted missing --value"; fail=1
else echo "PASS: rejects missing --value"; fi

# Valid dry-run resolves and prints intended assignment without mutating.
OUT2=$(bash "$ROOT/scripts/assign-tag.sh" --issue 218 --field Workstream --value "dev/state-management-bugs" --dry-run --yes 2>&1 || true)
echo "$OUT2"
echo "$OUT2" | grep -qi "dry-run" && echo "PASS: valid dry-run" || { echo "FAIL: valid dry-run"; fail=1; }

exit $fail
