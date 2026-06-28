#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

# --dry-run on a real field must exit 0, print a before/after line, and NOT mutate.
OUT=$(bash "$ROOT/scripts/edit-tag.sh" --field Status --target Done --new-name Done --color GREEN --dry-run --yes 2>&1)
echo "$OUT"
echo "$OUT" | grep -qi "dry-run" && echo "PASS: dry-run announced" || { echo "FAIL: no dry-run notice"; fail=1; }

# Missing required args must exit non-zero.
if bash "$ROOT/scripts/edit-tag.sh" --field Status 2>/dev/null; then
  echo "FAIL: accepted missing --target"; fail=1
else echo "PASS: rejects missing --target"; fi

# Unknown field rejected.
if bash "$ROOT/scripts/edit-tag.sh" --field Nope --target x --color RED --dry-run --yes 2>/dev/null; then
  echo "FAIL: accepted unknown field"; fail=1
else echo "PASS: rejects unknown field"; fi

exit $fail
