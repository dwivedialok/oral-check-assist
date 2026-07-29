#!/usr/bin/env bash
# Verify model asset naming/content before build/deploy.
# Canonical 5-class names: ensemble_model_1/2/3.onnx
# Canonical binary names:  binary_ensemble_mode_1/2/3.onnx

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$REPO_ROOT/assets"

required_files=(
  "ensemble_model_1.onnx"
  "ensemble_model_2.onnx"
  "ensemble_model_3.onnx"
  "binary_ensemble_mode_1.onnx"
  "binary_ensemble_mode_2.onnx"
  "binary_ensemble_mode_3.onnx"
)

legacy_fiveclass_files=(
  "ensemble_mode_1.onnx"
  "ensemble_mode_2.onnx"
  "ensemble_mode_3.onnx"
)

echo "=== verifying model assets in $ASSETS_DIR ==="

if [[ ! -d "$ASSETS_DIR" ]]; then
  echo "error: assets directory not found: $ASSETS_DIR" >&2
  exit 1
fi

missing=0
for f in "${required_files[@]}"; do
  if [[ ! -f "$ASSETS_DIR/$f" ]]; then
    echo "error: missing required model asset: assets/$f" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

legacy_found=0
for f in "${legacy_fiveclass_files[@]}"; do
  if [[ -f "$ASSETS_DIR/$f" ]]; then
    legacy_found=1
  fi
done

if [[ "$legacy_found" -eq 1 ]]; then
  echo "warning: legacy 5-class asset names detected (ensemble_mode_*.onnx)." >&2
  echo "         App uses ensemble_model_*.onnx; keeping both is confusing." >&2
  echo "         Consider removing legacy files after verification:" >&2
  echo "         rm assets/ensemble_mode_1.onnx assets/ensemble_mode_2.onnx assets/ensemble_mode_3.onnx" >&2

  # Check whether legacy files are byte-identical to canonical files.
  for i in 1 2 3; do
    legacy="$ASSETS_DIR/ensemble_mode_${i}.onnx"
    canonical="$ASSETS_DIR/ensemble_model_${i}.onnx"
    if [[ -f "$legacy" && -f "$canonical" ]]; then
      legacy_hash="$(shasum -a 256 "$legacy" | awk '{print $1}')"
      canonical_hash="$(shasum -a 256 "$canonical" | awk '{print $1}')"
      if [[ "$legacy_hash" != "$canonical_hash" ]]; then
        echo "warning: assets/ensemble_mode_${i}.onnx differs from assets/ensemble_model_${i}.onnx" >&2
      fi
    fi
  done
fi

echo "ok: required model assets are present."
