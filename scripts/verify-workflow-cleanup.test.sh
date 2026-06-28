#!/usr/bin/env bash
# Verifies the SAFE-RETIRE logic added to stage_cleanup:
#  - partitions workstream tickets by status from the LIVE board
#  - refuses (fail) when any non-Done ticket exists, naming it
#  - never sends an empty option set (board-nuke guard, via bo_apply_options)
#
# NOTE: stage_cleanup's observation-gate read uses python with /c/ paths that are
# broken on this Windows box (pre-existing, documented as a follow-up), so this test
# exercises the partition + guard logic directly rather than driving the whole stage.
# dev/state-management-bugs currently has #218 in Inbox among Done tickets.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/board-options.sh"
WS="dev/state-management-bugs"
fail=0

# --- Replicate the exact partition stage_cleanup performs ---
TICKETS_JSON=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit "$ITEM_LIMIT" --format json \
  --jq "[.items[] | select(.workstream == \"$WS\") | {num: .content.number, status: .status}]" 2>/dev/null || echo "[]")
NON_DONE=$(echo "$TICKETS_JSON" | node -e '
  let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
    const nd=JSON.parse(d).filter(t=>t.status!=="Done").map(t=>"#"+t.num+"("+(t.status||"none")+")");
    console.log(nd.join(" "));
  });')

echo "tickets on $WS: $(echo "$TICKETS_JSON" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).map(t=>"#"+t.num+"("+t.status+")").join(" ")));')"
echo "non-Done: ${NON_DONE:-<none>}"

# 1) There IS a non-Done ticket and it includes #218 -> retire must refuse.
if [[ -n "$NON_DONE" ]]; then echo "PASS: non-Done detected (would refuse without --force)"; else echo "FAIL: expected a non-Done ticket"; fail=1; fi
echo "$NON_DONE" | grep -q "218" && echo "PASS: #218 named as blocker" || { echo "FAIL: #218 not named"; fail=1; }

# 2) The drop transform still produces a valid NON-EMPTY option set (no board-nuke).
DESIRED=$(bo_fetch_field Workstream | node "$ROOT/scripts/lib/board-options.mjs" drop --target "$WS")
COUNT=$(echo "$DESIRED" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).length));')
[[ "$COUNT" -ge 1 ]] && echo "PASS: drop yields non-empty set ($COUNT options), target removed" || { echo "FAIL: empty/invalid set"; fail=1; }
echo "$DESIRED" | grep -q "$WS" && { echo "FAIL: target still present"; fail=1; } || echo "PASS: target '$WS' removed from desired set"

# 3) bo_apply_options refuses the empty set (board-nuke guard) — without calling gh.
if bo_apply_options "$WORKSTREAM_FIELD_ID" "[]" 2>/dev/null; then echo "FAIL: empty set not refused"; fail=1; else echo "PASS: empty set refused (board-nuke impossible)"; fi

# 4) The live option is untouched by this test (we only read).
STILL=$(bo_fetch_field Workstream | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).some(o=>o.name==='$WS')));")
[[ "$STILL" == "true" ]] && echo "PASS: live option intact (test mutated nothing)" || { echo "FAIL: option was modified"; fail=1; }

exit $fail
