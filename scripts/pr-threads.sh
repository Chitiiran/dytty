#!/usr/bin/env bash
# Read-only lister of unresolved review threads on a PR.
# STRICTLY READ-ONLY: queries GraphQL only; never resolves/replies/mutates anything.
#
# Usage: bash scripts/pr-threads.sh <pr#>
#
# Sourceable: `source pr-threads.sh` exposes format_threads() (for tests) without
# running the gh query. Parsing uses python (jq is not installed on this box; the
# rest of the repo parses gh JSON with python too).

set -euo pipefail

REPO_OWNER="${PR_THREADS_OWNER:-Chitiiran}"
REPO_NAME="${PR_THREADS_REPO:-dytty}"

# format_threads <graphql-json>  — prints unresolved threads (author + first body line)
# and a summary count. Pure: takes JSON on argv via stdin to python, no network.
format_threads() {
  local json="$1"
  printf '%s' "$json" | python -c '
import json, sys
data = json.load(sys.stdin) or {}
if data.get("errors"):
    print("GraphQL errors:", data["errors"], file=sys.stderr)
    sys.exit(1)
pr = (((data.get("data") or {}).get("repository") or {}).get("pullRequest")) or {}
rt = pr.get("reviewThreads") or {}
nodes = rt.get("nodes") or []
total = rt.get("totalCount", len(nodes))
unresolved = [n for n in nodes if not n.get("isResolved", False)]
print(f"Review threads: {total} total, {len(unresolved)} unresolved")
if not unresolved:
    print("  All threads resolved.")
    sys.exit(0)
for n in unresolved:
    state = "outdated" if n.get("isOutdated") else "current"
    comments = (n.get("comments") or {}).get("nodes") or []
    author = (comments[0].get("author") or {}).get("login", "?") if comments else "?"
    body = (comments[0].get("body") or "") if comments else ""
    first = body.split("\n")[0]
    print(f"  [{state}] {author}: {first}")
'
}

# Only run the live query when executed directly (not when sourced by tests).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  PR="${1:-}"
  if [[ -z "$PR" || ! "$PR" =~ ^[0-9]+$ ]]; then
    echo "Error: PR number must be a positive integer" >&2
    echo "Usage: bash scripts/pr-threads.sh <pr#>" >&2
    exit 1
  fi
  JSON=$(gh api graphql -f query="
    {repository(owner:\"$REPO_OWNER\",name:\"$REPO_NAME\"){
      pullRequest(number:$PR){
        reviewThreads(first:50){
          totalCount
          nodes{ isResolved isOutdated comments(first:1){nodes{author{login} body}} }
        }
      }
    }}")
  format_threads "$JSON"
fi
