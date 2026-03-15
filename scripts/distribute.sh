#!/usr/bin/env bash
# Builds a debug APK and uploads it to Firebase App Distribution.
# Auto-increments the build number so each upload is a distinct release.
# Usage: bash scripts/distribute.sh "Release notes here"

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

# Auto-increment patch version and build number in pubspec.yaml
PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
CURRENT_VERSION=$(grep '^version:' "$PUBSPEC" | head -1)
MAJOR=$(echo "$CURRENT_VERSION" | sed 's/version: *\([0-9]*\)\..*/\1/')
MINOR=$(echo "$CURRENT_VERSION" | sed 's/version: *[0-9]*\.\([0-9]*\)\..*/\1/')
PATCH=$(echo "$CURRENT_VERSION" | sed 's/version: *[0-9]*\.[0-9]*\.\([0-9]*\)+.*/\1/')
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | sed 's/.*+//')
NEW_PATCH=$((PATCH + 1))
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
OLD_VERSION="${MAJOR}.${MINOR}.${PATCH}+${BUILD_NUMBER}"
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}+${NEW_BUILD_NUMBER}"
sed -i "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"
echo "Bumped version: ${OLD_VERSION} -> ${NEW_VERSION}"

RELEASE_NOTES="${1:-Local debug build}"
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
