#!/usr/bin/env bash
# Capture Android logs when the app crashes on launch.
# Usage:
#   1. Connect device, then: ./capture_crash_log.sh
#   2. In another terminal: flutter run (or tap the app icon)
#   3. When the app crashes, stop this script (Ctrl+C). Check oral_crash_log.txt

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/oral_crash_log.txt"
echo "Log file: $LOG_FILE"
echo "Launch the app now (flutter run or tap icon). Press Ctrl+C when done."
adb logcat -c
adb logcat -v time "*:E" "flutter:V" "ActivityManager:I" "AndroidRuntime:E" 2>&1 | tee "$LOG_FILE"
