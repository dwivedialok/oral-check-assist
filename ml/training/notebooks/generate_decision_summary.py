#!/usr/bin/env python3
"""
Generate decision summary table and decision.json from eval_report.

Reads binary_metrics.json and fiveclass_metrics.json from an eval_report directory,
produces a markdown table and machine-readable decision.json locking the model choice.

Usage:
  python generate_decision_summary.py --eval_report_dir results/<run_id>/eval_report [--output_dir <dir>]
  python generate_decision_summary.py --run_id <run_id>
"""

import argparse
import json
import sys
from pathlib import Path

NOTEBOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(NOTEBOOK_DIR))

from model_registry import (
    BINARY_PROGRESSIVE_K5_ONNX_DIR,
    FIVECLASS_PROGRESSIVE_K5_ONNX_DIR,
    RESULTS_DIR,
)


def main():
    parser = argparse.ArgumentParser(description="Generate decision summary from eval_report")
    parser.add_argument("--eval_report_dir", default=None, help="Path to eval_report directory")
    parser.add_argument("--run_id", default=None, help="Run ID; eval_report_dir = results/<run_id>/eval_report")
    parser.add_argument("--output_dir", default=None, help="Write decision.md and decision.json here (default: eval_report_dir)")
    parser.add_argument("--target_specificity", type=float, default=0.90)
    args = parser.parse_args()

    if args.eval_report_dir:
        eval_report_dir = Path(args.eval_report_dir)
    elif args.run_id:
        eval_report_dir = RESULTS_DIR / args.run_id / "eval_report"
    else:
        # Default: use latest canonical run
        eval_report_dir = RESULTS_DIR / "phase0_test1" / "eval_report"
        if not eval_report_dir.exists():
            eval_report_dir = RESULTS_DIR / "eval_report"
        if not eval_report_dir.exists():
            print("Error: specify --eval_report_dir or --run_id, or ensure results/phase0_test1/eval_report exists", file=sys.stderr)
            sys.exit(1)

    if not eval_report_dir.exists():
        print(f"Error: eval_report_dir not found: {eval_report_dir}", file=sys.stderr)
        sys.exit(1)

    binary_path = eval_report_dir / "binary_metrics.json"
    fiveclass_path = eval_report_dir / "fiveclass_metrics.json"
    if not binary_path.exists():
        print(f"Error: {binary_path} not found. Run run_full_evaluation.py first.", file=sys.stderr)
        sys.exit(1)
    if not fiveclass_path.exists():
        print(f"Error: {fiveclass_path} not found. Run run_full_evaluation.py first.", file=sys.stderr)
        sys.exit(1)

    with open(binary_path) as f:
        binary_metrics = json.load(f)
    with open(fiveclass_path) as f:
        fiveclass_metrics = json.load(f)

    output_dir = Path(args.output_dir) if args.output_dir else eval_report_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    splits = ["T5", "TB", "TC", "TM"]
    # Build table rows
    rows = []
    for split in splits:
        b = binary_metrics.get(split, {})
        f = fiveclass_metrics.get(split, {})
        if not b and not f:
            continue
        n = b.get("n") or f.get("n", 0)
        bin_auroc = b.get("auroc")
        bin_s90 = b.get("sens_at_90spec")
        five_auroc = f.get("auroc")  # 5-class binary view
        five_s90 = f.get("sens_at_90spec")
        bin_ece = b.get("ece")
        bin_brier = b.get("brier")
        five_ece = f.get("ece")
        five_brier = f.get("brier")
        row = {
            "split": split,
            "n": n,
            "binary_auroc": bin_auroc,
            "binary_sens_at_90spec": bin_s90,
            "fiveclass_auroc": five_auroc,
            "fiveclass_sens_at_90spec": five_s90,
            "binary_ece": bin_ece,
            "binary_brier": bin_brier,
            "fiveclass_ece": five_ece,
            "fiveclass_brier": five_brier,
        }
        rows.append(row)

    # decision.json
    decision = {
        "binary_model": "progressive_K5",
        "binary_onnx_dir": str(BINARY_PROGRESSIVE_K5_ONNX_DIR),
        "fiveclass_model": "progressive_K5",
        "fiveclass_onnx_dir": str(FIVECLASS_PROGRESSIVE_K5_ONNX_DIR),
        "deployment_constraint": "sens@90spec",
        "target_specificity": args.target_specificity,
        "locked": True,
        "eval_report_dir": str(eval_report_dir),
        "per_split": {r["split"]: {k: v for k, v in r.items() if k != "split"} for r in rows},
    }
    decision_path = output_dir / "decision.json"
    with open(decision_path, "w") as f:
        json.dump(decision, f, indent=2)
    print(f"Written {decision_path}")

    # Markdown table
    md_lines = [
        "# Decision summary",
        "",
        "| Split | N | Binary AUROC | Binary S@90Sp | 5-class AUROC | 5-class S@90Sp | Binary ECE | Binary Brier | 5-class ECE | 5-class Brier |",
        "| ----- | --- | ------------ | ------------- | ------------- | -------------- | ---------- | ------------ | ----------- | ------------- |",
    ]
    def fmt_rate(x):
        if x is None:
            return "—"
        if isinstance(x, float):
            return f"{x:.2%}"
        return str(x)

    def fmt_metric(x):
        if x is None:
            return "—"
        if isinstance(x, float):
            return f"{x:.4f}"
        return str(x)

    for r in rows:
        md_lines.append(
            f"| {r['split']} | {r['n']} | {fmt_metric(r.get('binary_auroc'))} | {fmt_rate(r.get('binary_sens_at_90spec'))} | {fmt_metric(r.get('fiveclass_auroc'))} | {fmt_rate(r.get('fiveclass_sens_at_90spec'))} | {fmt_metric(r.get('binary_ece'))} | {fmt_metric(r.get('binary_brier'))} | {fmt_metric(r.get('fiveclass_ece'))} | {fmt_metric(r.get('fiveclass_brier'))} |"
        )
    md_lines.extend(["", "**Locked models:**", f"- Binary: `{BINARY_PROGRESSIVE_K5_ONNX_DIR}`", f"- 5-class: `{FIVECLASS_PROGRESSIVE_K5_ONNX_DIR}`", ""])
    md_path = output_dir / "decision.md"
    with open(md_path, "w") as f:
        f.write("\n".join(md_lines))
    print(f"Written {md_path}")

    print("\n" + "\n".join(md_lines[2:-4]))


if __name__ == "__main__":
    main()
