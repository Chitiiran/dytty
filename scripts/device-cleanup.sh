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

# Determine test user UID.
# Prefer DEVICE_TEST_UID — it is the reliable path. The DEVICE_TEST_EMAIL ->
# auth:export lookup is a known-unreliable fallback (#206): on this setup
# auth:export often returns nothing, so cleanup silently no-ops between flows.
# Set DEVICE_TEST_UID to avoid that.
if [[ -n "${DEVICE_TEST_UID:-}" ]]; then
  TEST_UID="$DEVICE_TEST_UID"
elif [[ -n "${DEVICE_TEST_EMAIL:-}" ]]; then
  echo "WARNING: DEVICE_TEST_UID not set — falling back to auth:export email lookup," >&2
  echo "         which is unreliable (#206). Prefer setting DEVICE_TEST_UID." >&2
  echo "Looking up UID for $DEVICE_TEST_EMAIL..." >&2
  TEST_UID=$(firebase auth:export --project "$PROJECT_ID" 2>/dev/null \
    | grep "$DEVICE_TEST_EMAIL" \
    | head -1 \
    | cut -d',' -f1 || true)
  if [[ -z "$TEST_UID" ]]; then
    echo "ERROR: Could not find UID for $DEVICE_TEST_EMAIL (auth:export returned nothing — #206)." >&2
    echo "  Set DEVICE_TEST_UID directly to fix this." >&2
    exit 1
  fi
else
  echo "ERROR: Set DEVICE_TEST_UID (preferred) or DEVICE_TEST_EMAIL environment variable." >&2
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
