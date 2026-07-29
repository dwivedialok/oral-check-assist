#!/usr/bin/env bash
# Fresh install: clean project + device, then build and install on connected Android.
# Run from repo root: bash scripts/fresh_install.sh

set -e
PACKAGE="com.threeamwave.oral.check.assist"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== 1. Uninstall app from connected device (current + old package IDs) ==="
adb uninstall "$PACKAGE" 2>/dev/null || true
adb uninstall "com.3amwave.oral.check.assist" 2>/dev/null || true
adb uninstall "com.example.oral_cavity_classifier_app" 2>/dev/null || true

echo "=== 2. Flutter clean ==="
flutter clean

echo "=== 3. Remove Android build caches ==="
rm -rf android/.gradle android/app/build android/build
rm -rf build .dart_tool

echo "=== 4. Get dependencies ==="
flutter pub get

echo "=== 5. Build and run on device (use only Android device if multiple) ==="
flutter run
