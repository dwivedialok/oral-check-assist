#!/usr/bin/env bash
# Run binary merged training with agent configs until accuracy >= 80% or configs exhausted.
# Uses venv: ml/training/venv_multihead_tflite
# Run from repo root: ./ml/training/notebooks/run_agent.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_PYTHON="${SCRIPT_DIR}/../venv_multihead_tflite/bin/python"
AGENT_SCRIPT="${SCRIPT_DIR}/train_binary_merged_agent.py"
CONFIGS=(
  "agent_configs/01_no_weights_light_aug.json"
  "agent_configs/02_weights_none_aug.json"
  "agent_configs/03_no_weights_full_aug.json"
  "agent_configs/04_weights_light_20ep.json"
)

cd "$SCRIPT_DIR"

for config in "${CONFIGS[@]}"; do
  echo "=============================================="
  echo "Running config: $config"
  echo "=============================================="
  if "$VENV_PYTHON" "$AGENT_SCRIPT" --config "$config"; then
    echo "Target 80% reached. Done."
    exit 0
  fi
done

echo "All configs tried; target not reached."
exit 1
