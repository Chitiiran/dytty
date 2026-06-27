#!/usr/bin/env bash
# Verifies add-workstream preserves existing ids and is reassignment-free.
# Uses a live add+drop on a throwaway tag, asserting no other option's id changed.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/board-options.sh"
TAG="zz-addtest-tag"
fail=0

before=$(bo_fetch_field Workstream)
bash "$ROOT/scripts/add-workstream.sh" "$TAG" --color GRAY >/dev/null 2>&1
after=$(bo_fetch_field Workstream)

# Every pre-existing id must still be present after the add.
MISSING=$(before="$before" after="$after" node -e '
  const b=JSON.parse(process.env.before), a=JSON.parse(process.env.after);
  const aIds=new Set(a.map(o=>o.id));
  const lost=b.filter(o=>!aIds.has(o.id)).map(o=>o.name);
  console.log(lost.join(","));
')
[[ -z "$MISSING" ]] && echo "PASS: all prior ids preserved on add" || { echo "FAIL: lost ids for: $MISSING"; fail=1; }
echo "$after" | grep -q "$TAG" && echo "PASS: new tag added" || { echo "FAIL: tag not added"; fail=1; }

# Cleanup: drop the throwaway tag via the safe path.
DESIRED=$(bo_fetch_field Workstream | node "$ROOT/scripts/lib/board-options.mjs" drop --target "$TAG")
bo_apply_options "$WORKSTREAM_FIELD_ID" "$DESIRED" >/dev/null 2>&1
exit $fail
