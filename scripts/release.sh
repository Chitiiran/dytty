#!/usr/bin/env bash
# Release branch creation for Dytty
#
# Usage:
#   bash scripts/release.sh 0.2.0          # Create release/0.2.0 from develop
#   bash scripts/release.sh 0.2.0 --dry-run  # Show what would happen
#
# What it does:
# 1. Verify on develop branch and clean working tree
# 2. Pull latest develop
# 3. Bump version in pubspec.yaml to the given version
# 4. Create release/X.Y.Z branch
# 5. Commit version bump
# 6. Print next steps (push, verify CI, merge)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-}"
DRY_RUN=false

if [[ -z "$VERSION" ]]; then
  echo "Usage: bash scripts/release.sh <version> [--dry-run]"
  echo "  Example: bash scripts/release.sh 0.2.0"
  exit 1
fi

if [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

cd "$PROJECT_DIR"

echo "=== Release: $VERSION ==="

# 1. Verify branch and working tree
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "develop" ]]; then
  echo "ERROR: Must be on 'develop' branch (currently on '$CURRENT_BRANCH')"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# 2. Pull latest
echo "Pulling latest develop..."
if [[ "$DRY_RUN" == false ]]; then
  git pull origin develop
else
  echo "  [dry-run] Would pull origin develop"
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
echo "  1. Push:  git push -u origin $BRANCH"
echo "  2. CI will run: analyze + test + Maestro full suite + App Distribution"
echo "  3. Dogfooding: distribute APK to testers (2-3 days)"
echo "  4. Fix P0/P1 bugs on this branch if any"
echo "  5. When all gates pass:"
echo "     a. Merge to main:   gh pr create --base main --title 'Release $VERSION'"
echo "     b. Back-merge:      git checkout develop && git merge $BRANCH"
echo "     c. Delete branch:   git branch -d $BRANCH && git push origin --delete $BRANCH"
