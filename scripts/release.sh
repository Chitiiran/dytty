#!/usr/bin/env bash
# Release branch creation for Dytty
#
# Usage:
#   bash scripts/release.sh 0.2.0          # Create release/0.2.0 from main
#   bash scripts/release.sh 0.2.0 --dry-run  # Show what would happen
#
# What it does:
# 1. Verify on main branch and clean working tree
# 2. Pull latest main
# 3. Bump version in pubspec.yaml to the given version
# 4. Create release/X.Y.Z branch
# 5. Commit version bump
# 6. Print next steps (push, verify CI, merge)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/version.sh"

if ! PARSED=$(parse_release_args "$@"); then
  echo "Usage: bash scripts/release.sh <version> [--dry-run]"
  echo "  Example: bash scripts/release.sh 0.2.0"
  exit 1
fi
IFS=$'\t' read -r VERSION DRY_RUN <<< "$PARSED"

cd "$PROJECT_DIR"

echo "=== Release: $VERSION ==="

# 1. Verify branch and working tree
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "ERROR: Must be on 'main' branch (currently on '$CURRENT_BRANCH')"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# 2. Pull latest
echo "Pulling latest main..."
if [[ "$DRY_RUN" == false ]]; then
  git pull origin main
else
  echo "  [dry-run] Would pull origin main"
fi

# 3. Create release branch
BRANCH="release/$VERSION"
echo "Creating branch: $BRANCH"
if [[ "$DRY_RUN" == false ]]; then
  git checkout -b "$BRANCH"
else
  echo "  [dry-run] Would create branch $BRANCH"
fi

# 4. Bump version in pubspec.yaml
echo "Bumping version to $VERSION..."
if [[ "$DRY_RUN" == false ]]; then
  # Extract current build number and increment
  CURRENT=$(grep '^version:' pubspec.yaml | sed 's/version: //')
  BUILD_NUM=$(echo "$CURRENT" | sed 's/.*+//')
  NEW_BUILD=$((BUILD_NUM + 1))
  NEW_VERSION="$VERSION+$NEW_BUILD"

  sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
  echo "  Version: $CURRENT -> $NEW_VERSION"

  git add pubspec.yaml
  git commit -m "chore: bump version to $NEW_VERSION for release

Preparing release candidate $VERSION.

Refs #45"
else
  echo "  [dry-run] Would update pubspec.yaml version to $VERSION+N"
fi

# 5. Print next steps
echo ""
echo "=== Release branch ready ==="
echo ""
echo "Next steps:"
echo "  1. Open a PR:  gh pr create --base main --head $BRANCH --title 'Release $VERSION'"
echo "  2. CI (ci.yml Gate 1) runs on the PR: analyze + test + 80% coverage + build web/APK + Maestro smoke"
echo "  3. Dogfooding: distribute APK to testers (bash scripts/distribute.sh ...) for 2-3 days"
echo "  4. Fix P0/P1 bugs on this branch if any"
echo "  5. On merge to main: Gate 3 (distribute-release) + deploy.yml publish + auto-tag the release"
echo "     Delete branch after merge:  git push origin --delete $BRANCH"
