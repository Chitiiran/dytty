#!/usr/bin/env bash
# Rename/recolor a single-select option on the project board, preserving its
# id so NO issue is unlinked. Works on Status/Category/Effort/Workstream.
#
# Usage:
#   bash scripts/edit-tag.sh --field Workstream --target dev/old --new-name dev/new --color PURPLE
#   bash scripts/edit-tag.sh --field Category --target core-bugs --color RED
# Flags: --dry-run (preview, no mutation), --yes (skip confirm)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/board-options.sh"
LOG_FILE="$SCRIPT_DIR/../kb/workflow/workstream-log.json"

FIELD="" TARGET="" NEW_NAME="" COLOR="" DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --field) FIELD="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --new-name) NEW_NAME="$2"; shift 2 ;;
    --color) COLOR="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) BO_ASSUME_YES=1; shift ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$FIELD" ]] && { echo "ERROR: --field required" >&2; exit 1; }
[[ -z "$TARGET" ]] && { echo "ERROR: --target required" >&2; exit 1; }
[[ -z "$NEW_NAME" && -z "$COLOR" ]] && { echo "ERROR: need --new-name and/or --color" >&2; exit 1; }
FIELD_ID="$(bo_field_id "$FIELD")"  # validates field, exits 1 if unknown

CURRENT="$(bo_fetch_field "$FIELD")"
MJS_ARGS=(edit --target "$TARGET")
[[ -n "$NEW_NAME" ]] && MJS_ARGS+=(--new-name "$NEW_NAME")
[[ -n "$COLOR" ]] && MJS_ARGS+=(--color "$COLOR")
DESIRED="$(echo "$CURRENT" | node "$SCRIPT_DIR/lib/board-options.mjs" "${MJS_ARGS[@]}")"

echo "--- $FIELD: '$TARGET' -> name='${NEW_NAME:-$TARGET}' color='${COLOR:-unchanged}' ---"
echo "BEFORE: $(echo "$CURRENT" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).map(o=>o.name).join(" | ")));')"
echo "AFTER : $(echo "$DESIRED" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).map(o=>o.name).join(" | ")));')"

if [[ "$DRY_RUN" == 1 ]]; then
  echo "(dry-run — no changes applied)"
  exit 0
fi

bo_confirm "Apply this edit? (ids preserved, 0 issues reassigned)" || { echo "Aborted."; exit 0; }
bo_apply_options "$FIELD_ID" "$DESIRED" >/dev/null
echo "Applied. Issues assigned to '$TARGET' now read '${NEW_NAME:-$TARGET}'."

# Workstream rename: keep the log name in sync; warn about the git branch.
if [[ "$FIELD" == "Workstream" && -n "$NEW_NAME" && -f "$LOG_FILE" ]]; then
  TARGET="$TARGET" NEW_NAME="$NEW_NAME" LOG_FILE="$LOG_FILE" node -e '
    const fs=require("fs"); const p=process.env.LOG_FILE;
    const data=JSON.parse(fs.readFileSync(p,"utf8"));
    let changed=false;
    for(const e of data){ if(e.workstream===process.env.TARGET){ e.workstream=process.env.NEW_NAME; if(e.branch===process.env.TARGET) e.branch=process.env.NEW_NAME; changed=true; } }
    if(changed) fs.writeFileSync(p, JSON.stringify(data,null,2)+"\n");
    console.log(changed?"  (workstream-log.json updated)":"  (no log entry to update)");
  '
  echo "  NOTE: the git branch '$TARGET' is NOT renamed — rename it separately if you want them to match."
fi
