#!/usr/bin/env python3
"""
Orchestrator: run full evaluation (binary + 5-class metrics + agreement) and produce eval_report/.

Produces results/<run_id>/eval_report/ containing:
  - binary_metrics.json
  - fiveclass_metrics.json
  - agreement_all_splits.json
  - thresholds.json (threshold policy and operating points)

Usage:
  python run_full_evaluation.py [--run_id <id>] [--binary_dir <path>] [--fiveclass_dir <path>]
  If --binary_dir/--fiveclass_dir omitted, uses model_registry canonical paths.
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

NOTEBOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(NOTEBOOK_DIR))

from model_registry import (
    BINARY_PROGRESSIVE_K5_ONNX_DIR,
    FIVECLASS_PROGRESSIVE_K5_ONNX_DIR,
    RESULTS_DIR,
)


def main():
    parser = argparse.ArgumentParser(description="Run full evaluation and write eval_report/")
    parser.add_argument("--run_id", default=None, help="Run ID; default: eval_YYYYMMDD_HHMMSS")
    parser.add_argument("--binary_dir", default=None, help="Binary ONNX ensemble dir (default: registry)")
    parser.add_argument("--fiveclass_dir", default=None, help="5-class ONNX ensemble dir (default: registry)")
    parser.add_argument("--frozen_dir", default=None, help="Frozen test sets directory")
    parser.add_argument("--python", default=None, help="Python interpreter (default: sys.executable)")
    args = parser.parse_args()

    run_id = args.run_id or f"eval_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    binary_dir = Path(args.binary_dir) if args.binary_dir else BINARY_PROGRESSIVE_K5_ONNX_DIR
    fiveclass_dir = Path(args.fiveclass_dir) if args.fiveclass_dir else FIVECLASS_PROGRESSIVE_K5_ONNX_DIR
    frozen_dir = args.frozen_dir or str(NOTEBOOK_DIR / "frozen_test_sets")
    python = args.python or sys.executable

    eval_report_dir = RESULTS_DIR / run_id / "eval_report"
    eval_report_dir.mkdir(parents=True, exist_ok=True)

    if not binary_dir.exists():
        print(f"Error: binary_dir not found: {binary_dir}", file=sys.stderr)
        sys.exit(1)
    if not fiveclass_dir.exists():
        print(f"Error: fiveclass_dir not found: {fiveclass_dir}", file=sys.stderr)
        sys.exit(1)

    cmd_base = [python, str(NOTEBOOK_DIR / "evaluate_on_frozen_sets.py"), "--frozen_dir", frozen_dir]
    # Binary evaluation
    cmd_bin = cmd_base + [
        "--model", str(binary_dir),
        "--model_type", "binary_onnx_ensemble",
        "--output", str(eval_report_dir / "binary_legacy.json"),
        "--eval_report_dir", str(eval_report_dir),
        "--run_id", run_id,
    ]
    print("Running binary evaluation...")
    r = subprocess.run(cmd_bin, cwd=str(NOTEBOOK_DIR))
    if r.returncode != 0:
        print("Binary evaluation failed.", file=sys.stderr)
        sys.exit(r.returncode)

    # 5-class evaluation
    cmd_5 = cmd_base + [
        "--model", str(fiveclass_dir),
        "--model_type", "5class_onnx_ensemble",
        "--output", str(eval_report_dir / "fiveclass_legacy.json"),
        "--eval_report_dir", str(eval_report_dir),
        "--run_id", run_id,
    ]
    print("Running 5-class evaluation...")
    r = subprocess.run(cmd_5, cwd=str(NOTEBOOK_DIR))
    if r.returncode != 0:
        print("5-class evaluation failed.", file=sys.stderr)
        sys.exit(r.returncode)

    # Agreement analysis
    cmd_agr = [
        python, str(NOTEBOOK_DIR / "agreement_analysis.py"),
        "--binary_dir", str(binary_dir),
        "--fiveclass_dir", str(fiveclass_dir),
        "--frozen_dir", frozen_dir,
        "--eval_report_dir", str(eval_report_dir),
    ]
    print("Running agreement analysis...")
    r = subprocess.run(cmd_agr, cwd=str(NOTEBOOK_DIR))
    if r.returncode != 0:
        print("Agreement analysis failed.", file=sys.stderr)
        sys.exit(r.returncode)

    # thresholds.json: document threshold policy and operating points
    thresholds = {
        "run_id": run_id,
        "binary_dir": str(binary_dir),
        "fiveclass_dir": str(fiveclass_dir),
        "policy": {
            "binary_referral": "refer if p(cancer) >= threshold; low≈0.31 (sens~86% @ 80% spec), high≈0.54 (sens~83% @ 85% spec)",
            "fiveclass_cancer_prob": "p_5(cancer) = p(OCA) + p(OPMD) after softmax",
            "target_specificity": 0.90,
            "sens_at_90spec": "reported in binary_metrics.json and fiveclass_metrics.json per split",
        },
        "operating_points": {},
    }
    # Fill operating points from binary_metrics if present
    binary_metrics_path = eval_report_dir / "binary_metrics.json"
    if binary_metrics_path.exists():
        with open(binary_metrics_path) as f:
            bm = json.load(f)
        for split in ("T5", "TB", "TC", "TM"):
            if split in bm and "sens_at_90spec" in bm[split]:
                thresholds["operating_points"][f"binary_{split}"] = {
                    "sens_at_90spec": bm[split]["sens_at_90spec"],
                    "auroc": bm[split].get("auroc"),
                    "brier": bm[split].get("brier"),
                    "ece": bm[split].get("ece"),
                }
    with open(eval_report_dir / "thresholds.json", "w") as f:
        json.dump(thresholds, f, indent=2)
    print(f"Written {eval_report_dir / 'thresholds.json'}")

    print("\n" + "=" * 60)
    print(f"Full evaluation complete: {eval_report_dir}")
    print("=" * 60)
    print("  binary_metrics.json")
    print("  fiveclass_metrics.json")
    print("  agreement_all_splits.json")
    print("  thresholds.json")


if __name__ == "__main__":
    main()
