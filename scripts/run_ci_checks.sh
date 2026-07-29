#!/usr/bin/env bash
# Mirror .github/workflows/ci.yml so local runs match GitHub Actions.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Verify model assets"
bash scripts/verify_model_assets.sh

echo "==> flutter pub get"
flutter pub get

echo "==> dart format check"
dart format --output=none --set-exit-if-changed .

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "✅ All CI checks passed."
