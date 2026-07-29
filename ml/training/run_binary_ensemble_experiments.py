#!/usr/bin/env python3
"""Run binary ensemble notebook experiments without manual edits."""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
NOTEBOOK = REPO_ROOT / "ml" / "training" / "notebooks" / "binary_ensemble_training.ipynb"
OUTPUT_DIR = REPO_ROOT / "ml" / "training" / "results" / "binary_ensemble_experiments"
CONFIG_DIR = OUTPUT_DIR / "configs"
RUNS_DIR = OUTPUT_DIR / "runs"


def build_experiments():
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base_name = f"exp_{timestamp}"

    return [
        {
            "name": f"{base_name}_baseline",
            "config": {},
        },
        {
            "name": f"{base_name}_cancer_weight",
            "config": {"cancer_weight_multiplier": 1.3},
        },
        {
            "name": f"{base_name}_strong_aug",
            "config": {"augmentation": "strong"},
        },
        {
            "name": f"{base_name}_cosine_scheduler",
            "config": {"scheduler": "cosine"},
        },
        {
            "name": f"{base_name}_threshold_035",
            "config": {"binary_threshold": 0.35},
        },
    ]


def write_config(name: str, config: dict) -> Path:
    config_path = CONFIG_DIR / f"{name}.json"
    payload = {"run_name": name, **config}
    config_path.write_text(json.dumps(payload, indent=2))
    return config_path


def run_notebook(name: str, config_path: Path) -> None:
    output_notebook = RUNS_DIR / f"{name}.ipynb"
    env = os.environ.copy()
    env["BINARY_EXPERIMENT_CONFIG"] = str(config_path)
    env["BINARY_EXPERIMENT_NAME"] = name

    cmd = [
        "jupyter",
        "nbconvert",
        "--to",
        "notebook",
        "--execute",
        str(NOTEBOOK),
        "--output",
        str(output_notebook),
    ]
    print(f"🚀 Running {name}")
    subprocess.run(cmd, check=True, env=env)


def main() -> None:
    if not NOTEBOOK.exists():
        raise SystemExit(f"Notebook not found: {NOTEBOOK}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    RUNS_DIR.mkdir(parents=True, exist_ok=True)

    experiments = build_experiments()
    for exp in experiments:
        config_path = write_config(exp["name"], exp["config"])
        run_notebook(exp["name"], config_path)

    print("✅ All experiments completed.")


if __name__ == "__main__":
    main()
