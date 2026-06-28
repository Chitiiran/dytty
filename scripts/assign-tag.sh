#!/usr/bin/env bash
# Assign a single-select tag to a ticket BY NAME. No option-set mutation —
# only the ticket's field value changes (always safe). Resolves issue# -> item
# id and value-name -> option id for you.
#
# Usage:
#   bash scripts/assign-tag.sh --issue 218 --field Workstream --value dev/state-management-bugs
# Flags: --dry-run, --yes
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/board-options.sh"

ISSUE="" FIELD="" VALUE="" DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE="$2"; shift 2 ;;
    --field) FIELD="$2"; shift 2 ;;
    --value) VALUE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) BO_ASSUME_YES=1; shift ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done
[[ -z "$ISSUE" ]] && { echo "ERROR: --issue required" >&2; exit 1; }
[[ -z "$FIELD" ]] && { echo "ERROR: --field required" >&2; exit 1; }
[[ -z "$VALUE" ]] && { echo "ERROR: --value required" >&2; exit 1; }

FIELD_ID="$(bo_field_id "$FIELD")"
ITEM_ID="$(bo_resolve_item_id "$ISSUE")"  # exits 1 if issue not on board

# Resolve the value name to an option id on this field.
OPTION_ID="$(bo_fetch_field "$FIELD" | VALUE="$VALUE" FIELD="$FIELD" node -e '
  let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
    const o=JSON.parse(d).find(x=>x.name===process.env.VALUE);
    if(!o){console.error("value \""+process.env.VALUE+"\" not found on field "+process.env.FIELD);process.exit(1);}
    console.log(o.id);
  });')"

echo "--- Assign #$ISSUE  $FIELD = '$VALUE'  (item=$ITEM_ID option=$OPTION_ID) ---"
if [[ "$DRY_RUN" == 1 ]]; then
  echo "(dry-run — no changes applied)"
  exit 0
fi
bo_confirm "Assign #$ISSUE -> $FIELD='$VALUE'?" || { echo "Aborted."; exit 0; }
bo_set_item_field "$ITEM_ID" "$FIELD_ID" "$OPTION_ID"
echo "Done. #$ISSUE $FIELD set to '$VALUE'."
