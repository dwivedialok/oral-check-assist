#!/usr/bin/env bash
# Mirror .github/workflows/ci.yml so local runs match GitHub Actions.
# Expected Flutter: 3.35.5 (pinned in CI). Check with: flutter --version
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXPECTED_FLUTTER="3.35.5"
ACTUAL_FLUTTER="$(flutter --version 2>/dev/null | head -1 | sed -n 's/.*Flutter \([0-9.]*\).*/\1/p' || true)"
if [[ -n "$ACTUAL_FLUTTER" && "$ACTUAL_FLUTTER" != "$EXPECTED_FLUTTER" ]]; then
  echo "⚠️  Local Flutter is $ACTUAL_FLUTTER; CI pins $EXPECTED_FLUTTER."
  echo "    Results may differ. Consider aligning local SDK with the CI pin."
fi

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
