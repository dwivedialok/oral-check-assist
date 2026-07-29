#!/usr/bin/env python3
"""
Evaluate end-to-end fusion policy on frozen test sets.

Compares GatedFusionPolicy vs current Dart decision matrix. Reports policy-level
sens@90spec, dangerous misses, unnecessary referrals, retake rate.

Usage:
  python evaluate_fusion_policy.py --binary_dir <path> --fiveclass_dir <path> [--config config.json] [--output fusion_policy_results.json]
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np

NOTEBOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(NOTEBOOK_DIR))

from fusion_policy import GatedFusionPolicy, current_dart_decision_matrix, get_referral_from_dart_risk
from frozen_test_sets import (
    get_t5_binary_paths_labels,
    get_tb_paths_labels,
    get_tc_paths_labels,
    get_tm_paths_labels_and_sources,
    get_tm_paths_labels_and_sources_v2,
)
from evaluate_on_frozen_sets import sensitivity_at_specificity


def run_policy_on_split(policy, paths, labels, use_dart=False):
    """
    Run policy on paths. If use_dart, use Dart decision matrix; else gated fusion.
    Returns (y_true, refer_binary, risk_scores, is_retake_mask). For Dart, is_retake_mask is all False.
    """
    y_true = []
    refer_list = []
    risk_scores = []
    is_retake = []
    for path, label in zip(paths, labels):
        riskB = policy._run_binary(path)
        five = policy._run_fiveclass(path)
        p_oca = five["p_oca"]
        p_opmd = five["p_opmd"]
        p_unknown = five["unknown_prob"]
        label_str = five["label"]
        if use_dart:
            risk_level = current_dart_decision_matrix(riskB, p_oca, p_opmd, p_unknown, label_str)
            refer = get_referral_from_dart_risk(risk_level)
            risk_scores.append(riskB)
            refer_list.append(1 if refer else 0)
            is_retake.append(False)
        else:
            out = policy.predict(path)
            if out["action"] == "retake":
                refer_list.append(0)
                risk_scores.append(np.nan)
                is_retake.append(True)
            else:
                refer_list.append(1 if out["action"] == "refer" else 0)
                risk_scores.append(out["risk_score"])
                is_retake.append(False)
        y_true.append(label)
    return np.array(y_true), np.array(refer_list), np.array(risk_scores), np.array(is_retake)


def policy_metrics(y_true, refer_pred, risk_scores, is_retake):
    """Compute sens, spec, sens@90spec, dangerous_misses, unnecessary_refers. Exclude retakes from metrics."""
    valid = ~is_retake & ~np.isnan(risk_scores)
    if valid.sum() == 0:
        return {"retake_count": int(is_retake.sum()), "retake_rate": float(is_retake.sum() / len(is_retake)) if len(is_retake) else 0}
    y = y_true[valid]
    ref = refer_pred[valid]
    risk = risk_scores[valid].astype(float)
    n_total = len(y_true)
    retake_count = int(is_retake.sum())
    n = int(len(y))
    n_cancer = int((y == 1).sum())
    n_non = int((y == 0).sum())
    sens = float(np.mean(ref[y == 1] == 1)) if n_cancer else 0.0
    spec = float(np.mean(ref[y == 0] == 0)) if n_non else 0.0
    sens_at_90 = sensitivity_at_specificity(y, risk, 0.90) if n >= 2 and np.unique(y).size >= 2 else 0.0
    dangerous_misses = int(np.sum((y == 1) & (ref == 0)))
    unnecessary_refers = int(np.sum((y == 0) & (ref == 1)))
    return {
        "n": n,
        "n_cancer": n_cancer,
        "n_non_cancer": n_non,
        "sensitivity": sens,
        "specificity": spec,
        "sens_at_90spec": sens_at_90,
        "dangerous_misses": dangerous_misses,
        "unnecessary_refers": unnecessary_refers,
        "retake_count": retake_count,
        "retake_rate": retake_count / n_total if n_total else 0.0,
    }


def main():
    parser = argparse.ArgumentParser(description="Evaluate fusion policy on frozen sets")
    parser.add_argument("--binary_dir", required=True, help="Binary ONNX ensemble dir")
    parser.add_argument("--fiveclass_dir", required=True, help="5-class ONNX ensemble dir")
    parser.add_argument("--frozen_dir", default=None, help="Frozen test sets dir")
    parser.add_argument("--config", default=None, help="JSON config for GatedFusionPolicy")
    parser.add_argument("--output", default="fusion_policy_results.json")
    args = parser.parse_args()

    frozen_dir = Path(args.frozen_dir) if args.frozen_dir else NOTEBOOK_DIR / "frozen_test_sets"
    config = {}
    if args.config:
        with open(args.config) as f:
            config = json.load(f)

    policy = GatedFusionPolicy(args.binary_dir, args.fiveclass_dir, config)

    t5_paths, t5_labels = get_t5_binary_paths_labels(frozen_dir)
    tb_paths, tb_labels = get_tb_paths_labels(frozen_dir)
    tc_paths, tc_labels = [], []
    if (frozen_dir / "TC.json").exists():
        try:
            tc_paths, tc_labels = get_tc_paths_labels(frozen_dir)
        except Exception:
            pass
    if (frozen_dir / "TC.json").exists():
        tm_paths, tm_labels, _ = get_tm_paths_labels_and_sources_v2(frozen_dir)
    else:
        tm_paths, tm_labels, _ = get_tm_paths_labels_and_sources(frozen_dir)

    results = {"gated_fusion": {}, "current_dart": {}, "config": config}

    def run_split(name, paths, labels):
        if not paths:
            return
        # Gated fusion
        y_true, ref, risk, is_retake = run_policy_on_split(policy, paths, labels, use_dart=False)
        results["gated_fusion"][name] = policy_metrics(y_true, ref, risk, is_retake)
        # Current Dart (no retakes)
        y_true_d, ref_d, risk_d, is_retake_d = run_policy_on_split(policy, paths, labels, use_dart=True)
        results["current_dart"][name] = policy_metrics(y_true_d, ref_d, risk_d, is_retake_d)

    print("Evaluating gated fusion and Dart policy on T5...")
    run_split("T5", t5_paths, t5_labels)
    print("TB...")
    run_split("TB", tb_paths, tb_labels)
    if tc_paths:
        print("TC...")
        run_split("TC", tc_paths, tc_labels)
    print("TM...")
    run_split("TM", tm_paths, tm_labels)

    results["binary_dir"] = str(args.binary_dir)
    results["fiveclass_dir"] = str(args.fiveclass_dir)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to {out_path}")
    print("\n--- Gated fusion (TM) ---")
    if "TM" in results["gated_fusion"]:
        m = results["gated_fusion"]["TM"]
        print(f"  sens={m.get('sensitivity',0):.2%}  spec={m.get('specificity',0):.2%}  sens@90spec={m.get('sens_at_90spec',0):.2%}  dangerous_misses={m.get('dangerous_misses',0)}  retake_rate={m.get('retake_rate',0):.2%}")
    print("--- Current Dart (TM) ---")
    if "TM" in results["current_dart"]:
        m = results["current_dart"]["TM"]
        print(f"  sens={m.get('sensitivity',0):.2%}  spec={m.get('specificity',0):.2%}  sens@90spec={m.get('sens_at_90spec',0):.2%}  dangerous_misses={m.get('dangerous_misses',0)}")


if __name__ == "__main__":
    main()
