#!/usr/bin/env bash
set -euo pipefail

# Add a new workstream option to the GitHub Project board without breaking
# existing workstream assignments.
#
# The GitHub GraphQL updateProjectV2Field mutation replaces ALL option IDs,
# which silently unlinks issues from their workstreams. This script:
# 1. Snapshots all current workstream assignments
# 2. Adds the new option
# 3. Reassigns all issues using the new IDs
#
# Usage:
#   bash scripts/add-workstream.sh <workstream-name> [--color COLOR]
#   bash scripts/add-workstream.sh dev/voice-ux --color PURPLE
#
# Colors: GRAY, BLUE, ORANGE, GREEN, PURPLE, RED, PINK, YELLOW

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Constants ---
PROJECT_NUMBER=1
PROJECT_OWNER="Chitiiran"
PROJECT_ID="PVT_kwHOAKyMRs4BTnrv"
WORKSTREAM_FIELD_ID="PVTSSF_lAHOAKyMRs4BTnrvzhA2cOQ"

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

# --- Step 1: Get current workstream options (with colors via GraphQL) ---
echo "--- Step 1: Fetching current workstream options ---"
CURRENT_OPTIONS=$(gh api graphql -f query="
query {
  node(id: \"$PROJECT_ID\") {
    ... on ProjectV2 {
      field(name: \"Workstream\") {
        ... on ProjectV2SingleSelectField {
          options {
            id
            name
            color
          }
        }
      }
    }
  }
}" | node -e "
    let d='';
    process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{
      const field=JSON.parse(d).data.node.field;
      if(field) console.log(JSON.stringify(field.options));
      else { console.error('Workstream field not found'); process.exit(1); }
    });
  ")

echo "  Current options: $(echo "$CURRENT_OPTIONS" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    const opts=JSON.parse(d);
    console.log(opts.map(o=>o.name+' ('+o.color+')').join(', '));
  });
")"

# Check if workstream already exists
ALREADY_EXISTS=$(echo "$CURRENT_OPTIONS" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    const opts=JSON.parse(d);
    console.log(opts.some(o=>o.name==='$NEW_WORKSTREAM'));
  });
")

if [[ "$ALREADY_EXISTS" == "true" ]]; then
  echo "  ERROR: Workstream '$NEW_WORKSTREAM' already exists"
  exit 1
fi

# --- Step 2: Snapshot current assignments ---
echo ""
echo "--- Step 2: Snapshotting current workstream assignments ---"
ITEMS_JSON=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 200 --format json)

# Build map: itemId -> workstreamName (only items with a workstream set)
ASSIGNMENTS=$(echo "$ITEMS_JSON" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    const data=JSON.parse(d);
    const assigned=data.items.filter(i=>{
      const ws=i.workstream||'';
      return ws && ws!=='(none)';
    }).map(i=>({
      id:i.id,
      number:i.content&&i.content.number?i.content.number:0,
      workstream:i.workstream
    }));
    console.log(JSON.stringify(assigned));
  });
")

ASSIGNMENT_COUNT=$(echo "$ASSIGNMENTS" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>console.log(JSON.parse(d).length));
")
echo "  Found $ASSIGNMENT_COUNT items with workstream assignments"

# --- Step 3: Build new options list and run mutation ---
echo ""
echo "--- Step 3: Adding new workstream option via GraphQL ---"

# Build the singleSelectOptions array for the mutation (preserving existing colors)
OPTIONS_GQL=$(echo "$CURRENT_OPTIONS" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    const opts=JSON.parse(d);
    // Preserve each option's existing color from the API
    const lines=opts.map(o=>{
      return '{name: \"'+o.name+'\", description: \"\", color: '+o.color+'}';
    });
    // Add the new option
    lines.push('{name: \"$NEW_WORKSTREAM\", description: \"\", color: $COLOR}');
    console.log(lines.join('\n      '));
  });
")

MUTATION_RESULT=$(gh api graphql -f query="
mutation {
  updateProjectV2Field(input: {
    fieldId: \"$WORKSTREAM_FIELD_ID\"
    name: \"Workstream\"
    singleSelectOptions: [
      $OPTIONS_GQL
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        options {
          id
          name
        }
      }
    }
  }
}")

# Extract new option IDs
NEW_OPTIONS=$(echo "$MUTATION_RESULT" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    const opts=JSON.parse(d).data.updateProjectV2Field.projectV2Field.options;
    console.log(JSON.stringify(opts));
  });
")

echo "  New options:"
echo "$NEW_OPTIONS" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    JSON.parse(d).forEach(o=>console.log('    '+o.name+' -> '+o.id));
  });
"

# --- Step 4: Reassign all items ---
echo ""
echo "--- Step 4: Reassigning $ASSIGNMENT_COUNT items ---"

# Build name->newId map, then reassign each item
REASSIGN_COMMANDS=$(node -e "
  const assignments=$ASSIGNMENTS;
  const newOptions=$NEW_OPTIONS;
  const nameToId={};
  newOptions.forEach(o=>nameToId[o.name]=o.id);
  assignments.forEach(a=>{
    const newId=nameToId[a.workstream];
    if(newId){
      console.log(a.id+'|'+newId+'|#'+a.number+'|'+a.workstream);
    } else {
      console.error('WARNING: No matching option for workstream: '+a.workstream+' (issue #'+a.number+')');
    }
  });
")

REASSIGN_COUNT=0
FAIL_COUNT=0

while IFS='|' read -r ITEM_ID OPTION_ID ISSUE_NUM WS_NAME; do
  if gh project item-edit \
    --project-id "$PROJECT_ID" \
    --id "$ITEM_ID" \
    --field-id "$WORKSTREAM_FIELD_ID" \
    --single-select-option-id "$OPTION_ID" 2>/dev/null; then
    echo "  PASS: $ISSUE_NUM -> $WS_NAME"
    REASSIGN_COUNT=$((REASSIGN_COUNT + 1))
  else
    echo "  FAIL: $ISSUE_NUM -> $WS_NAME"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done <<< "$REASSIGN_COMMANDS"

# --- Step 5: Report new workstream option ID ---
NEW_WS_ID=$(echo "$NEW_OPTIONS" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    const opt=JSON.parse(d).find(o=>o.name==='$NEW_WORKSTREAM');
    console.log(opt?opt.id:'NOT_FOUND');
  });
")

echo ""
echo "=== Summary ==="
echo "  New workstream: $NEW_WORKSTREAM (ID: $NEW_WS_ID)"
echo "  Reassigned: $REASSIGN_COUNT items"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "  FAILED: $FAIL_COUNT items"
fi
echo ""
echo "To assign issues to this workstream:"
echo "  gh project item-edit --project-id $PROJECT_ID --id <ITEM_ID> --field-id $WORKSTREAM_FIELD_ID --single-select-option-id $NEW_WS_ID"
