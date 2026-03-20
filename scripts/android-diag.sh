#!/usr/bin/env bash
# Android device diagnostic script for Dytty.
# Checks the full notification pipeline and common failure points.
#
# Usage:
#   bash scripts/android-diag.sh [device-serial]

set -euo pipefail

ADB="${ADB:-adb}"
PKG="com.dytty.dytty"
SERIAL="${1:-}"

if [[ -n "$SERIAL" ]]; then
  ADB="$ADB -s $SERIAL"
fi

echo "=== Dytty Android Diagnostics ==="
echo ""

# 1. Device connected?
echo "--- Device ---"
$ADB get-state 2>/dev/null || { echo "ERROR: No device connected"; exit 1; }
echo "Connected: $($ADB shell getprop ro.product.model) (Android $($ADB shell getprop ro.build.version.release))"
echo "Timezone: $($ADB shell getprop persist.sys.timezone)"
echo "Time: $($ADB shell date)"
echo ""

# 2. App installed?
echo "--- App ---"
APP_INFO=$($ADB shell dumpsys package "$PKG" 2>/dev/null | grep "versionName\|versionCode\|targetSdkVersion" | head -3)
if [[ -z "$APP_INFO" ]]; then
  echo "ERROR: $PKG is NOT installed"
  exit 1
fi
echo "$APP_INFO"
echo ""

# 3. Notification permission
echo "--- Notification Permission ---"
NOTIF_PERM=$($ADB shell dumpsys notification | grep "AppSettings: $PKG" || echo "NOT FOUND")
echo "$NOTIF_PERM"
echo ""

# 4. Notification channels
echo "--- Notification Channels ---"
CHANNELS=$($ADB shell dumpsys notification | grep -A 20 "NotificationChannels" | grep -i "dytty" || echo "No channels found for $PKG")
echo "$CHANNELS"
echo ""

# 5. Registered receivers
echo "--- Manifest Receivers ---"
RECEIVERS=$($ADB shell dumpsys package "$PKG" | grep -i "receiver\|ScheduledNotification\|BootReceiver" || echo "No receivers found")
echo "$RECEIVERS"
echo ""

# 6. Scheduled alarms
echo "--- Scheduled Alarms ---"
ALARMS=$($ADB shell dumpsys alarm | grep -B 1 -A 6 "dytty" || echo "No alarms scheduled")
echo "$ALARMS"
echo ""

# 7. Exact alarm permission
echo "--- Exact Alarm Permission ---"
EXACT=$($ADB shell cmd appops get "$PKG" SCHEDULE_EXACT_ALARM 2>/dev/null || echo "N/A")
echo "$EXACT"
echo ""

# 8. Battery optimization
echo "--- Battery Optimization ---"
BATTERY=$($ADB shell dumpsys deviceidle whitelist | grep -i "dytty" || echo "NOT whitelisted (battery optimization active)")
echo "$BATTERY"
echo ""

# 9. App standby bucket
echo "--- App Standby Bucket ---"
BUCKET=$($ADB shell am get-standby-bucket "$PKG" 2>/dev/null || echo "N/A")
echo "Bucket: $BUCKET"
echo ""

# 10. Recent crashes
echo "--- Recent Flutter Errors (last 50 lines) ---"
$ADB logcat -d | grep -i "flutter.*Error\|flutter.*Exception\|dytty.*lost permission\|dytty.*crash" | tail -10 || echo "None found"
echo ""

echo "=== Diagnostics Complete ==="
