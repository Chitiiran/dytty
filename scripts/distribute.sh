#!/usr/bin/env bash
# Builds a debug APK and uploads it to Firebase App Distribution.
# Auto-increments the build number so each upload is a distinct release.
# After upload, creates a git tag and GitHub Release for traceability.
#
# Usage:
#   bash scripts/distribute.sh "Release notes here"
#   bash scripts/distribute.sh "Release notes" --patch   # also bump patch version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
ENV_FILE="$PROJECT_ROOT/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env file not found at $ENV_FILE"
  echo "Copy .env.example to .env and fill in the values."
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

# Validate required variables
REQUIRED_VARS=(FIREBASE_ANDROID_API_KEY TESTER_EMAIL)
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: $var is not set in .env"
    exit 1
  fi
done

# Parse flags
BUMP_PATCH=false
RELEASE_NOTES=""
for arg in "$@"; do
  if [[ "$arg" == "--patch" ]]; then
    BUMP_PATCH=true
  elif [[ -z "$RELEASE_NOTES" ]]; then
    RELEASE_NOTES="$arg"
  fi
done
RELEASE_NOTES="${RELEASE_NOTES:-Local debug build}"

# Auto-increment version in pubspec.yaml
PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
CURRENT_VERSION=$(grep '^version:' "$PUBSPEC" | head -1)
MAJOR=$(echo "$CURRENT_VERSION" | sed 's/version: *\([0-9]*\)\..*/\1/')
MINOR=$(echo "$CURRENT_VERSION" | sed 's/version: *[0-9]*\.\([0-9]*\)\..*/\1/')
PATCH=$(echo "$CURRENT_VERSION" | sed 's/version: *[0-9]*\.[0-9]*\.\([0-9]*\)+.*/\1/')
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | sed 's/.*+//')

if [[ "$BUMP_PATCH" == true ]]; then
  NEW_PATCH=$((PATCH + 1))
else
  NEW_PATCH=$PATCH
fi
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
OLD_VERSION="${MAJOR}.${MINOR}.${PATCH}+${BUILD_NUMBER}"
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}+${NEW_BUILD_NUMBER}"
sed -i "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"
echo "Bumped version: ${OLD_VERSION} -> ${NEW_VERSION}"

APP_ID="1:828440302945:android:8a03bc6c01380939392120"
APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-debug.apk"

echo "Building debug APK..."
cd "$PROJECT_ROOT"
flutter build apk --debug \
  --dart-define=FIREBASE_ANDROID_API_KEY="$FIREBASE_ANDROID_API_KEY" \
  ${GEMINI_API_KEY:+--dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"}

echo ""
echo "Uploading to Firebase App Distribution..."
firebase appdistribution:distribute "$APK_PATH" \
  --app "$APP_ID" \
  --release-notes "$RELEASE_NOTES" \
  --testers "$TESTER_EMAIL"

echo ""
echo "Done! Build ${NEW_VERSION} sent to ${TESTER_EMAIL}."

# Tag the commit for traceability
TAG="v${NEW_VERSION}"
git add "$PUBSPEC"
git commit -m "chore: bump version to ${NEW_VERSION} for distribution"
git tag -a "$TAG" -m "Distribution ${NEW_VERSION}: ${RELEASE_NOTES}"
echo ""
echo "Tagged: $TAG"

# Create GitHub Release with APK (if gh CLI available)
if command -v gh &>/dev/null; then
  gh release create "$TAG" "$APK_PATH" \
    --title "$TAG" \
    --notes "$RELEASE_NOTES" \
    --prerelease
  echo "GitHub Release created: $TAG"
else
  echo "Warning: gh CLI not found, skipping GitHub Release creation."
  echo "Run manually: gh release create $TAG <apk-path> --title $TAG --notes '...'"
fi

echo ""
echo "Next: push tag to remote with 'git push origin main --tags'"
