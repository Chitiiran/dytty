#!/usr/bin/env bash
# Clean up test user data from Firestore after device E2E tests.
#
# Usage:
#   bash scripts/device-cleanup.sh
#
# Requires:
#   - Firebase CLI installed and authenticated (firebase login)
#   - DEVICE_TEST_UID environment variable set, OR
#     DEVICE_TEST_EMAIL set (slower -- looks up UID by email)

set -euo pipefail

PROJECT_ID="dytty-4b83d"

# Determine test user UID
if [[ -n "${DEVICE_TEST_UID:-}" ]]; then
  TEST_UID="$DEVICE_TEST_UID"
elif [[ -n "${DEVICE_TEST_EMAIL:-}" ]]; then
  echo "Looking up UID for $DEVICE_TEST_EMAIL..."
  TEST_UID=$(firebase auth:export --project "$PROJECT_ID" 2>/dev/null \
    | grep "$DEVICE_TEST_EMAIL" \
    | head -1 \
    | cut -d',' -f1 || true)
  if [[ -z "$TEST_UID" ]]; then
    echo "ERROR: Could not find UID for $DEVICE_TEST_EMAIL"
    echo "  Set DEVICE_TEST_UID manually if auth:export is unavailable."
    exit 1
  fi
else
  echo "ERROR: Set DEVICE_TEST_EMAIL or DEVICE_TEST_UID environment variable."
  exit 1
fi

echo "Cleaning up data for test user: $TEST_UID"

# Delete daily entries subcollection
firebase firestore:delete \
  "users/$TEST_UID/dailyEntries" \
  --project "$PROJECT_ID" \
  --recursive \
  --force \
  2>/dev/null || echo "  No dailyEntries to delete (or already clean)"

echo "Cleanup complete."
