#!/usr/bin/env bash
set -euo pipefail

# Add a new workstream option to the GitHub Project board without breaking
# existing workstream assignments.
#
# updateProjectV2Field is a FULL REPLACE of the option set, and regenerates the
# id of any option whose id you omit — which unlinks every issue on it. The fix:
# route through scripts/lib/board-options.sh, which preserves every existing
# option's id. Nothing is unlinked, so no reassignment is needed.
#
# Usage:
#   bash scripts/add-workstream.sh <workstream-name> [--color COLOR]
#   bash scripts/add-workstream.sh dev/voice-ux --color PURPLE
#
# Colors: GRAY, BLUE, ORANGE, GREEN, PURPLE, RED, PINK, YELLOW

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/board-options.sh"

# --- Parse args ---
NEW_WORKSTREAM=""
COLOR="GREEN"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --color) COLOR="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: bash scripts/add-workstream.sh <workstream-name> [--color COLOR]"
      echo "Colors: GRAY, BLUE, ORANGE, GREEN, PURPLE, RED, PINK, YELLOW"
      exit 0
      ;;
    *)
      if [[ -z "$NEW_WORKSTREAM" ]]; then
        NEW_WORKSTREAM="$1"
      else
        echo "ERROR: Unexpected argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$NEW_WORKSTREAM" ]]; then
  echo "ERROR: Workstream name is required"
  echo "Usage: bash scripts/add-workstream.sh <workstream-name> [--color COLOR]"
  exit 1
fi

echo "=== Adding workstream: $NEW_WORKSTREAM (color: $COLOR) ==="
echo ""

# Fetch current options, append the new one. The transform preserves every
# existing option's id (and rejects a duplicate name / the reserved "(none)").
CURRENT="$(bo_fetch_field Workstream)"
DESIRED="$(echo "$CURRENT" | node "$SCRIPT_DIR/lib/board-options.mjs" add --name "$NEW_WORKSTREAM" --color "$COLOR")"

echo "  Current: $(echo "$CURRENT" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).map(o=>o.name).join(", ")));')"

# Apply. No reassignment needed — existing options keep their ids, so no issue
# is unlinked.
NEW_OPTS="$(bo_apply_options "$WORKSTREAM_FIELD_ID" "$DESIRED")"

NEW_WS_ID="$(echo "$NEW_OPTS" | NEW_WORKSTREAM="$NEW_WORKSTREAM" node -e '
  let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
    const o=JSON.parse(d).find(x=>x.name===process.env.NEW_WORKSTREAM);
    console.log(o?o.id:"NOT_FOUND");
  });')"

echo ""
echo "=== Summary ==="
echo "  New workstream: $NEW_WORKSTREAM (ID: $NEW_WS_ID)"
echo "  No issues reassigned (ids preserved — nothing was unlinked)."
echo ""
echo "To assign issues to this workstream:"
echo "  bash scripts/assign-tag.sh --issue <N> --field Workstream --value $NEW_WORKSTREAM"
