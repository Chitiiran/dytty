#!/usr/bin/env bash
# Shared GitHub Project board option helpers — the ONLY place that mutates
# single-select option sets. Source this; do not execute.
#   source "$(dirname "$0")/lib/board-options.sh"
#
# Safety: bo_apply_options refuses an empty desired array (the historical
# board-nuke). board-options.mjs guarantees ids are preserved.

# --- Shared board IDs (verified live 2026-06-27) ---
PROJECT_NUMBER=1
PROJECT_OWNER="Chitiiran"
PROJECT_ID="PVT_kwHOAKyMRs4BTnrv"
WORKSTREAM_FIELD_ID="PVTSSF_lAHOAKyMRs4BTnrvzhA2cOQ"
CATEGORY_FIELD_ID="PVTSSF_lAHOAKyMRs4BTnrvzhA1cz8"
STATUS_FIELD_ID="PVTSSF_lAHOAKyMRs4BTnrvzhA1cwg"
EFFORT_FIELD_ID="PVTSSF_lAHOAKyMRs4BTnrvzhA1c0A"
STATUS_DONE_OPTION_ID="98236657"
WORKSTREAM_NONE_OPTION_ID="83dce863"
ITEM_LIMIT=250

_BO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BO_MJS="$_BO_LIB_DIR/board-options.mjs"

# Map a field display name to its node id (echoes the id; exit 1 if unknown).
bo_field_id() {
  case "$1" in
    Workstream) echo "$WORKSTREAM_FIELD_ID" ;;
    Category)   echo "$CATEGORY_FIELD_ID" ;;
    Status)     echo "$STATUS_FIELD_ID" ;;
    Effort)     echo "$EFFORT_FIELD_ID" ;;
    *) echo "board-options: unknown field '$1'" >&2; return 1 ;;
  esac
}

# bo_fetch_field <field_name> -> echoes options JSON; sets BO_FIELD_ID.
bo_fetch_field() {
  local field="$1"
  BO_FIELD_ID="$(bo_field_id "$field")" || return 1
  local resp
  resp=$(gh api graphql -f query="
    query {
      node(id: \"$PROJECT_ID\") {
        ... on ProjectV2 {
          field(name: \"$field\") {
            ... on ProjectV2SingleSelectField { options { id name color description } }
          }
        }
      }
    }") || { echo "board-options: GraphQL fetch failed for '$field'" >&2; return 1; }
  echo "$resp" | node -e "
    let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
      const f=JSON.parse(d).data.node.field;
      if(!f){console.error('field not found');process.exit(1);}
      console.log(JSON.stringify(f.options));
    });"
}

# bo_apply_options <field_id> <desired_json> -> runs mutation; echoes new options.
# REFUSES an empty / non-array desired set (board-nuke guard).
bo_apply_options() {
  local field_id="$1" desired="$2"
  local count
  count=$(node -e "
    let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
      try{const a=JSON.parse(d);console.log(Array.isArray(a)?a.length:-1);}
      catch{console.log(-1);}
    });" <<< "$desired")
  if [[ "$count" -le 0 ]]; then
    echo "board-options: REFUSING to apply empty/invalid option set (count=$count) — this would unlink every issue" >&2
    return 1
  fi
  # Build the GraphQL option literals from desired JSON (id optional).
  local gql
  gql=$(node -e "
    let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
      const opts=JSON.parse(d);
      const lines=opts.map(o=>{
        const idPart = o.id ? ('id: \"'+o.id+'\", ') : '';
        const desc = (o.description||'').replace(/\"/g,'\\\\\"');
        return '{'+idPart+'name: \"'+o.name+'\", color: '+o.color+', description: \"'+desc+'\"}';
      });
      console.log(lines.join('\n        '));
    });" <<< "$desired")
  local resp
  resp=$(gh api graphql -f query="
    mutation {
      updateProjectV2Field(input: {
        fieldId: \"$field_id\"
        singleSelectOptions: [
          $gql
        ]
      }) {
        projectV2Field {
          ... on ProjectV2SingleSelectField { options { id name color } }
        }
      }
    }") || { echo "board-options: mutation failed" >&2; return 1; }
  echo "$resp" | node -e "
    let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
      console.log(JSON.stringify(JSON.parse(d).data.updateProjectV2Field.projectV2Field.options));
    });"
}

# bo_set_item_field <item_id> <field_id> <option_id> -> item-edit (op Y; always safe).
bo_set_item_field() {
  gh project item-edit --project-id "$PROJECT_ID" --id "$1" --field-id "$2" \
    --single-select-option-id "$3" >/dev/null
}

# bo_resolve_item_id <issue_number> -> echoes board item id; exit 1 if absent.
bo_resolve_item_id() {
  local num="$1" id
  id=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit "$ITEM_LIMIT" --format json \
    --jq ".items[] | select(.content.number == $num) | .id" 2>/dev/null | head -1)
  if [[ -z "$id" ]]; then
    echo "board-options: issue #$num is not on the project board" >&2
    return 1
  fi
  echo "$id"
}

# bo_confirm <prompt> -> 0 if confirmed. BO_ASSUME_YES=1 auto-confirms.
bo_confirm() {
  if [[ "${BO_ASSUME_YES:-0}" == "1" ]]; then return 0; fi
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}
