#!/usr/bin/env python3
"""
Run binary_classification_merged_dataset.ipynb with a given config (for agent loop).
Writes agent_run_config.json, executes the notebook, reads agent_result.json.
Usage:
  python train_binary_merged_agent.py --config agent_configs/01_no_weights_light.json
  python train_binary_merged_agent.py --config agent_configs/02_weights_none_aug.json
Exit: 0 if test accuracy >= TARGET_ACCURACY, else 1 (so agent can try next config).
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

# Goal for agent loop
TARGET_ACCURACY = 0.80
# Notebook execution timeout (seconds); training can take 30–60+ min
EXECUTE_TIMEOUT = 7200  # 2 hours

NOTEBOOK_DIR = Path(__file__).resolve().parent
NOTEBOOK_NAME = "binary_classification_merged_dataset.ipynb"
AGENT_CONFIG_FILE = NOTEBOOK_DIR / "agent_run_config.json"
AGENT_RESULT_FILE = NOTEBOOK_DIR / "results" / "binary_merged" / "agent_result.json"


def main():
    parser = argparse.ArgumentParser(description="Run binary merged training with agent config")
    parser.add_argument("--config", required=True, type=Path, help="Path to JSON config (e.g. agent_configs/01.json)")
    parser.add_argument("--target", type=float, default=TARGET_ACCURACY, help="Target accuracy (default 0.80)")
    parser.add_argument("--timeout", type=int, default=EXECUTE_TIMEOUT, help="Notebook execute timeout in seconds")
    args = parser.parse_args()

    config_path = args.config
    if not config_path.is_absolute():
        config_path = (NOTEBOOK_DIR / config_path).resolve()
    if not config_path.exists():
        print(f"Config not found: {config_path}", file=sys.stderr)
        return 2

    with open(config_path) as f:
        overrides = json.load(f)

    # Write so notebook can read it
    with open(AGENT_CONFIG_FILE, "w") as f:
        json.dump(overrides, f, indent=2)
    print(f"Wrote {AGENT_CONFIG_FILE} from {config_path}")
    print(f"Overrides: {overrides}")

    # Run notebook from its directory so paths and agent_result path are correct
    cmd = [
        sys.executable, "-m", "jupyter", "nbconvert",
        "--execute", NOTEBOOK_NAME,
        "--ExecutePreprocessor.timeout=" + str(args.timeout),
        "--to", "notebook",
        "--output", "agent_run",
    ]

    print(f"Running: {' '.join(cmd)} (cwd={NOTEBOOK_DIR})")
    result = subprocess.run(cmd, cwd=NOTEBOOK_DIR)
    if result.returncode != 0:
        print("Notebook execution failed.", file=sys.stderr)
        return result.returncode

    if not AGENT_RESULT_FILE.exists():
        print(f"Agent result not found: {AGENT_RESULT_FILE}", file=sys.stderr)
        return 3

    with open(AGENT_RESULT_FILE) as f:
        agent_result = json.load(f)

    accuracy = agent_result["accuracy"]
    print(f"Result: accuracy={accuracy:.2%} sensitivity={agent_result['sensitivity']:.2%} specificity={agent_result['specificity']:.2%}")
    print(f"Output: {agent_result['output_dir']}")

    if accuracy >= args.target:
        print(f"Target {args.target:.0%} reached.")
        return 0
    print(f"Target {args.target:.0%} not reached.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
