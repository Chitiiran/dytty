#!/usr/bin/env bash
# Workflow verification script for Dytty GitHub Project board
#
# Run explicitly at each workflow stage to verify process compliance.
# All checks are ADVISORY (warnings, not blocking).
#
# Usage:
#   bash scripts/verify-workflow.sh --stage triage
#   bash scripts/verify-workflow.sh --stage batch --workstream dev/radial-menu
#   bash scripts/verify-workflow.sh --stage pr --workstream dev/radial-menu
#   bash scripts/verify-workflow.sh --stage post-merge --workstream dev/radial-menu
#   bash scripts/verify-workflow.sh --stage cleanup --workstream dev/radial-menu
#   bash scripts/verify-workflow.sh --stage session-start

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$PROJECT_DIR/kb/workflow/workstream-log.json"

# Board IDs + option helpers (PROJECT_*, WORKSTREAM_FIELD_ID, STATUS_FIELD_ID,
# STATUS_DONE_OPTION_ID, WORKSTREAM_NONE_OPTION_ID, ITEM_LIMIT, bo_* functions).
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/board-options.sh"

OBSERVATION_DAYS=7
PASS=0
WARN=0
FAIL=0

# ── Helpers ──────────────────────────────────────────

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

summary() {
  echo ""
  echo "=== Summary: $PASS passed, $WARN warnings, $FAIL failures ==="
  if [[ $FAIL -gt 0 ]]; then
    echo "  Action needed — review failures above."
  elif [[ $WARN -gt 0 ]]; then
    echo "  Advisory — review warnings above."
  else
    echo "  All checks passed."
  fi
}

ensure_log_file() {
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "[]" > "$LOG_FILE"
  fi
}

# ── Parse arguments ──────────────────────────────────

STAGE=""
WORKSTREAM=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --stage)
      STAGE="$2"
      shift 2
      ;;
    --workstream)
      WORKSTREAM="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --yes)
      BO_ASSUME_YES=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: bash scripts/verify-workflow.sh --stage <stage> [--workstream <name>] [--force] [--yes]"
      exit 1
      ;;
  esac
done

if [[ -z "$STAGE" ]]; then
  echo "ERROR: --stage is required"
  echo "Stages: triage, batch, pr, post-merge, cleanup, session-start"
  exit 1
fi

if [[ "$STAGE" != "triage" && "$STAGE" != "session-start" && -z "$WORKSTREAM" ]]; then
  echo "ERROR: --workstream is required for stage '$STAGE'"
  exit 1
fi

# ── Stage: session-start ─────────────────────────────

stage_session_start() {
  echo "=== Verifying: Session Start ==="
  ensure_log_file

  # Check for workstreams past observation period
  echo ""
  echo "--- Observation period check ---"
  local NOW_EPOCH
  NOW_EPOCH=$(date +%s)
  local FOUND_EXPIRED=false

  # Parse log file for uncleared entries
  local ENTRIES
  ENTRIES=$(cat "$LOG_FILE" | python -c "
import json, sys
data = json.load(sys.stdin)
for e in data:
    if not e.get('cleanedUp', False) and e.get('mergeDate'):
        print(f\"{e['workstream']}\t{e['mergeDate']}\t{e.get('prNumber','?')}\")
" 2>/dev/null || true)

  if [[ -n "$ENTRIES" ]]; then
    while IFS=$'\t' read -r ws mdate pr; do
      local MERGE_EPOCH
      MERGE_EPOCH=$(date -d "$mdate" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$mdate" +%s 2>/dev/null || echo 0)
      local DAYS_AGO=$(( (NOW_EPOCH - MERGE_EPOCH) / 86400 ))
      if [[ $DAYS_AGO -ge $OBSERVATION_DAYS ]]; then
        warn "Workstream '$ws' (PR #$pr) merged $DAYS_AGO days ago — ready for cleanup. Run: bash scripts/verify-workflow.sh --stage cleanup --workstream $ws"
        FOUND_EXPIRED=true
      else
        local DAYS_LEFT=$(( OBSERVATION_DAYS - DAYS_AGO ))
        pass "Workstream '$ws' (PR #$pr) in observation — $DAYS_LEFT days remaining"
      fi
    done <<< "$ENTRIES"
  fi

  if [[ "$FOUND_EXPIRED" == false && -z "$ENTRIES" ]]; then
    pass "No workstreams in observation"
  fi

  # Show active workstreams (In Progress)
  echo ""
  echo "--- Active workstreams ---"
  local IN_PROGRESS
  IN_PROGRESS=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json --jq '.items[] | select(.status == "In Progress") | "\(.content.number)\t\(.workstream // "NONE")"' 2>/dev/null || true)

  if [[ -n "$IN_PROGRESS" ]]; then
    # Group by workstream
    echo "$IN_PROGRESS" | awk -F'\t' '{ws[$2] = ws[$2] " #" $1} END {for (w in ws) print "  " w ":" ws[w]}'
  else
    pass "No items In Progress"
  fi

  summary
}

# ── Stage: triage ────────────────────────────────────

stage_triage() {
  echo "=== Verifying: Triage (Ready items have required fields) ==="

  # Get Ready items with all fields
  local RAW
  RAW=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json 2>/dev/null)

  local ITEMS
  ITEMS=$(echo "$RAW" | python -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('items', []):
    if item.get('status') == 'Ready':
        num = item.get('content', {}).get('number', '?')
        title = item.get('title', '?')
        labels = ','.join(item.get('labels', []))
        category = item.get('category', '')
        effort = item.get('effort', '')
        print(f'{num}\t{title}\t{labels}\t{category}\t{effort}')
" 2>/dev/null || true)

  if [[ -z "$ITEMS" ]]; then
    pass "No items in Ready to verify"
    summary
    return
  fi

  while IFS=$'\t' read -r NUM TITLE LABELS CATEGORY EFFORT; do
    local ISSUES_FOUND=false

    # Check priority label
    if ! echo "$LABELS" | grep -qE "P[0-3]"; then
      warn "#$NUM '$TITLE' — missing priority label"
      ISSUES_FOUND=true
    fi

    # Check category
    if [[ -z "$CATEGORY" ]]; then
      warn "#$NUM '$TITLE' — missing category"
      ISSUES_FOUND=true
    fi

    # Check effort
    if [[ -z "$EFFORT" ]]; then
      warn "#$NUM '$TITLE' — missing effort estimate"
      ISSUES_FOUND=true
    fi

    if [[ "$ISSUES_FOUND" == false ]]; then
      pass "#$NUM '$TITLE'"
    fi
  done <<< "$ITEMS"

  summary
}

# ── Stage: batch ─────────────────────────────────────

stage_batch() {
  echo "=== Verifying: Batch Selection ($WORKSTREAM) ==="

  # Check dev/* branch exists remotely
  echo ""
  echo "--- Branch check ---"
  if git ls-remote --heads origin "$WORKSTREAM" 2>/dev/null | grep -q "$WORKSTREAM"; then
    pass "Branch '$WORKSTREAM' exists on remote"
  else
    fail "Branch '$WORKSTREAM' does not exist on remote"
  fi

  # Check workstream option exists in project
  echo ""
  echo "--- Workstream option check ---"
  local WS_OPTIONS
  WS_OPTIONS=$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json --jq ".fields[] | select(.name == \"Workstream\") | .options[] | select(.name == \"$WORKSTREAM\") | .name" 2>/dev/null || true)

  if [[ -n "$WS_OPTIONS" ]]; then
    pass "Workstream option '$WORKSTREAM' exists in project"
  else
    fail "Workstream option '$WORKSTREAM' not found in project"
  fi

  # Check issues assigned to this workstream
  echo ""
  echo "--- Issue assignment check ---"
  local WS_ITEMS
  WS_ITEMS=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json --jq ".items[] | select(.workstream == \"$WORKSTREAM\") | .content.number" 2>/dev/null || true)

  if [[ -z "$WS_ITEMS" ]]; then
    fail "No issues assigned to workstream '$WORKSTREAM'"
  else
    local COUNT
    COUNT=$(echo "$WS_ITEMS" | wc -l | tr -d ' ')
    if [[ $COUNT -le 5 ]]; then
      pass "$COUNT issues assigned (limit: 5)"
    else
      warn "$COUNT issues assigned — exceeds recommended limit of 5"
    fi

    # Check all are In Progress
    local NOT_IN_PROGRESS
    NOT_IN_PROGRESS=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json --jq ".items[] | select(.workstream == \"$WORKSTREAM\" and .status != \"In Progress\") | \"#\(.content.number) is \(.status)\"" 2>/dev/null || true)

    if [[ -n "$NOT_IN_PROGRESS" ]]; then
      echo "$NOT_IN_PROGRESS" | while read -r line; do
        warn "$line — expected In Progress"
      done
    else
      pass "All workstream issues are In Progress"
    fi

    # Check for product-decision label without ADR reference
    echo "$WS_ITEMS" | while read -r num; do
      local LABELS
      LABELS=$(gh issue view "$num" --json labels --jq '.labels[].name' 2>/dev/null | tr '\n' ',')
      if echo "$LABELS" | grep -q "product-decision"; then
        local BODY
        BODY=$(gh issue view "$num" --json body --jq '.body' 2>/dev/null)
        if echo "$BODY" | grep -qiE "ADR|kb/decisions/"; then
          pass "#$num has product-decision label with ADR reference"
        else
          fail "#$num has product-decision label but no ADR reference — blocks In Progress"
        fi
      fi
    done
  fi

  summary
}

# ── Stage: pr ────────────────────────────────────────

stage_pr() {
  echo "=== Verifying: PR Ready ($WORKSTREAM) ==="

  # Find PR targeting this branch
  echo ""
  echo "--- PR check ---"
  local PR_INFO
  PR_INFO=$(gh pr list --base "$WORKSTREAM" --state open --json number,title,body --jq '.[0]' 2>/dev/null || true)

  if [[ -z "$PR_INFO" || "$PR_INFO" == "null" ]]; then
    # Also check if the workstream IS the PR branch targeting dev/release or main
    PR_INFO=$(gh pr list --head "$WORKSTREAM" --state open --json number,title,body --jq '.[0]' 2>/dev/null || true)
  fi

  if [[ -z "$PR_INFO" || "$PR_INFO" == "null" ]]; then
    fail "No open PR found for workstream '$WORKSTREAM'"
    summary
    return
  fi

  local PR_NUM
  PR_NUM=$(echo "$PR_INFO" | python -c "import json,sys; print(json.load(sys.stdin)['number'])")
  pass "PR #$PR_NUM found"

  # Get issues in workstream
  local WS_ISSUES
  WS_ISSUES=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json --jq ".items[] | select(.workstream == \"$WORKSTREAM\") | .content.number" 2>/dev/null || true)

  # Check PR body references each issue
  echo ""
  echo "--- Issue reference check ---"
  local PR_BODY
  PR_BODY=$(echo "$PR_INFO" | python -c "import json,sys; print(json.load(sys.stdin)['body'])")

  if [[ -n "$WS_ISSUES" ]]; then
    echo "$WS_ISSUES" | while read -r num; do
      if echo "$PR_BODY" | grep -qE "(Fixes|Closes|Refs) #$num"; then
        pass "#$num referenced in PR body"
      else
        warn "#$num NOT referenced in PR body — will not auto-close on merge"
      fi
    done
  fi

  # Check all workstream issues are In Review
  echo ""
  echo "--- Status check ---"
  local NOT_IN_REVIEW
  NOT_IN_REVIEW=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json --jq ".items[] | select(.workstream == \"$WORKSTREAM\" and .status != \"In Review\") | \"#\(.content.number) is \(.status)\"" 2>/dev/null || true)

  if [[ -n "$NOT_IN_REVIEW" ]]; then
    echo "$NOT_IN_REVIEW" | while read -r line; do
      warn "$line — expected In Review"
    done
  else
    pass "All workstream issues are In Review"
  fi

  # Check CI status on PR
  echo ""
  echo "--- CI check ---"
  local CI_STATUS
  CI_STATUS=$(gh pr checks "$PR_NUM" --json name,state --jq '.[] | "\(.name): \(.state)"' 2>/dev/null || true)

  if [[ -n "$CI_STATUS" ]]; then
    echo "$CI_STATUS" | while read -r check; do
      if echo "$check" | grep -q "SUCCESS"; then
        pass "$check"
      elif echo "$check" | grep -q "PENDING"; then
        warn "$check"
      else
        fail "$check"
      fi
    done
  else
    warn "Could not retrieve CI status for PR #$PR_NUM"
  fi

  summary
}

# ── Stage: post-merge ────────────────────────────────

stage_post_merge() {
  echo "=== Verifying: Post-Merge ($WORKSTREAM) ==="
  ensure_log_file

  # Check all referenced issues are closed
  echo ""
  echo "--- Issue closure check ---"
  local WS_ISSUES
  WS_ISSUES=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json --jq ".items[] | select(.workstream == \"$WORKSTREAM\") | .content.number" 2>/dev/null || true)

  if [[ -n "$WS_ISSUES" ]]; then
    echo "$WS_ISSUES" | while read -r num; do
      local STATE
      STATE=$(gh issue view "$num" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
      if [[ "$STATE" == "CLOSED" ]]; then
        pass "#$num is closed"
      else
        warn "#$num is $STATE — expected CLOSED. Was it dropped from the PR?"
      fi
    done
  fi

  # Check dev/* branch is deleted
  echo ""
  echo "--- Branch cleanup check ---"
  if git ls-remote --heads origin "$WORKSTREAM" 2>/dev/null | grep -q "$WORKSTREAM"; then
    warn "Branch '$WORKSTREAM' still exists on remote — delete it"
  else
    pass "Branch '$WORKSTREAM' deleted from remote"
  fi

  # Check worktrees cleaned
  echo ""
  echo "--- Worktree check ---"
  local STALE_WORKTREES
  STALE_WORKTREES=$(git worktree list --porcelain 2>/dev/null | grep "branch refs/heads" | grep -v "main\|dev/release" || true)
  if [[ -n "$STALE_WORKTREES" ]]; then
    warn "Worktrees still exist — review: git worktree list"
  else
    pass "No stale worktrees"
  fi

  # Check log entry exists
  echo ""
  echo "--- Log entry check ---"
  local LOG_ENTRY
  LOG_ENTRY=$(python -c "
import json
with open('$LOG_FILE') as f:
    data = json.load(f)
found = [e for e in data if e.get('workstream') == '$WORKSTREAM' and not e.get('cleanedUp', False)]
if found:
    print(f\"Merge date: {found[0].get('mergeDate', '?')}, PR: #{found[0].get('prNumber', '?')}\")
" 2>/dev/null || true)

  if [[ -n "$LOG_ENTRY" ]]; then
    pass "Log entry found — $LOG_ENTRY"
  else
    warn "No log entry for '$WORKSTREAM' — run post-merge logging"
  fi

  # Check issues moved to Done on board
  echo ""
  echo "--- Board status check ---"
  local NOT_DONE
  NOT_DONE=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json --jq ".items[] | select(.workstream == \"$WORKSTREAM\" and .status != \"Done\") | \"#\(.content.number) is \(.status)\"" 2>/dev/null || true)

  if [[ -n "$NOT_DONE" ]]; then
    echo "$NOT_DONE" | while read -r line; do
      warn "$line — expected Done"
    done
  else
    pass "All workstream issues are Done on board"
  fi

  summary
}

# ── Stage: cleanup ───────────────────────────────────

stage_cleanup() {
  echo "=== Cleanup: $WORKSTREAM ==="
  ensure_log_file

  # Check observation period elapsed
  # KNOWN-BROKEN on Windows (follow-up): this python `open('$LOG_FILE')` cannot open
  # the MSYS `/c/...` path that $LOG_FILE expands to (Windows python needs `C:\...`),
  # so it returns empty and the stage aborts below. session-start avoids this by
  # piping the file via stdin (`cat "$LOG_FILE" | python -c ...sys.stdin...`). Fix:
  # convert these stage_cleanup `open()` reads to the same stdin-pipe (or to node
  # reading the path as an argv arg, which MSYS converts). Tracked separately.
  local MERGE_DATE
  MERGE_DATE=$(python -c "
import json
with open('$LOG_FILE') as f:
    data = json.load(f)
found = [e for e in data if e.get('workstream') == '$WORKSTREAM' and not e.get('cleanedUp', False)]
if found:
    print(found[0].get('mergeDate', ''))
" 2>/dev/null || true)

  if [[ -z "$MERGE_DATE" ]]; then
    fail "No log entry found for '$WORKSTREAM' — cannot determine observation period"
    summary
    return
  fi

  local NOW_EPOCH MERGE_EPOCH DAYS_AGO
  NOW_EPOCH=$(date +%s)
  MERGE_EPOCH=$(date -d "$MERGE_DATE" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$MERGE_DATE" +%s 2>/dev/null || echo 0)
  DAYS_AGO=$(( (NOW_EPOCH - MERGE_EPOCH) / 86400 ))

  if [[ $DAYS_AGO -lt $OBSERVATION_DAYS ]]; then
    local DAYS_LEFT=$(( OBSERVATION_DAYS - DAYS_AGO ))
    warn "Observation period not elapsed — $DAYS_LEFT days remaining (merged $DAYS_AGO days ago)"
    summary
    return
  fi

  pass "Observation period elapsed ($DAYS_AGO days since merge)"

  echo ""
  echo "--- Safe retire of workstream option ---"

  # 1) Read tickets on this workstream from the LIVE board (never the log).
  local TICKETS_JSON
  TICKETS_JSON=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit "$ITEM_LIMIT" --format json \
    --jq "[.items[] | select(.workstream == \"$WORKSTREAM\") | {num: .content.number, status: .status}]" 2>/dev/null || echo "[]")

  # 2) Partition by status. Non-Done tickets block (or, with --force, stay on the tag).
  local NON_DONE
  NON_DONE=$(echo "$TICKETS_JSON" | node -e '
    let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
      const nd=JSON.parse(d).filter(t=>t.status!=="Done").map(t=>"#"+t.num+"("+(t.status||"none")+")");
      console.log(nd.join(" "));
    });')

  if [[ -n "$NON_DONE" ]]; then
    if [[ "${FORCE:-0}" != "1" ]]; then
      fail "Refusing: workstream has non-Done tickets: $NON_DONE"
      echo "  Reassign or close them first (e.g. bash scripts/assign-tag.sh --issue <N> --field Workstream --value <other>),"
      echo "  or re-run with --force to drop the tag and leave these tickets on it."
      summary
      return
    fi
    warn "Proceeding with --force; these non-Done tickets stay on the (about-to-be-removed) tag: $NON_DONE"
  fi

  # 3) Remove the option via the id-preserving transform (Done tickets keep
  #    Status=Done; they simply lose the now-meaningless ephemeral Workstream value).
  local DESIRED
  DESIRED=$(bo_fetch_field Workstream | node "$SCRIPT_DIR/lib/board-options.mjs" drop --target "$WORKSTREAM") \
    || { fail "Could not compute option set (is '$WORKSTREAM' still present?)"; summary; return; }

  local DONE_COUNT
  DONE_COUNT=$(echo "$TICKETS_JSON" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).filter(t=>t.status==="Done").length));')
  echo "  Will remove option '$WORKSTREAM' ($DONE_COUNT Done tickets stay Done)."
  if ! bo_confirm "Retire workstream tag '$WORKSTREAM'?"; then
    warn "Aborted by user — option NOT removed."
    summary
    return
  fi

  if bo_apply_options "$WORKSTREAM_FIELD_ID" "$DESIRED" >/dev/null; then
    pass "Workstream option '$WORKSTREAM' retired safely (survivor ids preserved)"
  else
    fail "Failed to retire option — board unchanged"
    summary
    return
  fi

  # Mark log entry as cleaned up
  python -c "
import json
with open('$LOG_FILE', 'r') as f:
    data = json.load(f)
for e in data:
    if e.get('workstream') == '$WORKSTREAM' and not e.get('cleanedUp', False):
        e['cleanedUp'] = True
        e['cleanupDate'] = '$(date +%Y-%m-%d)'
with open('$LOG_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null && pass "Log entry marked as cleaned up" || warn "Failed to update log file"

  summary
}

# ── Dispatch ─────────────────────────────────────────

case "$STAGE" in
  session-start)
    stage_session_start
    ;;
  triage)
    stage_triage
    ;;
  batch)
    stage_batch
    ;;
  pr)
    stage_pr
    ;;
  post-merge)
    stage_post_merge
    ;;
  cleanup)
    stage_cleanup
    ;;
  *)
    echo "ERROR: Unknown stage '$STAGE'"
    echo "Stages: session-start, triage, batch, pr, post-merge, cleanup"
    exit 1
    ;;
esac
