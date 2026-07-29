#!/usr/bin/env python3
"""
Agreement analysis between binary and 5-class ONNX ensembles on frozen test sets.

Computes argmax agreement, probability-level agreement (p_bin(cancer) vs p_5(cancer)=p(OPMD)+p(OCA)),
agreement after aligning thresholds by specificity/referral rate, and confusion matrices
on T5, TB, TC, TM.

Usage:
  python agreement_analysis.py --binary_dir <path> --fiveclass_dir <path> [--output agreement_all_splits.json]
  python agreement_analysis.py --binary_dir <path> --fiveclass_dir <path> --eval_report_dir <dir>
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np

try:
    import onnxruntime as ort
except ImportError:
    ort = None

NOTEBOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(NOTEBOOK_DIR))

from frozen_test_sets import (
    get_t5_binary_paths_labels,
    get_tb_paths_labels,
    get_tc_paths_labels,
    get_tm_paths_labels_and_sources,
    get_tm_paths_labels_and_sources_v2,
    load_frozen_sets,
)

# Reuse preprocessing and ensemble logic from evaluate_on_frozen_sets
from evaluate_on_frozen_sets import (
    CANCER_CLASS_INDICES,
    ENSEMBLE_WEIGHTS,
    load_and_preprocess_image_onnx_ensemble,
)


def load_onnx_ensemble_sessions(model_dir, model_names):
    model_dir = Path(model_dir)
    sessions = []
    input_name = None
    for name in model_names:
        p = model_dir / name
        if not p.exists():
            raise FileNotFoundError(f"Expected {p}")
        sess = ort.InferenceSession(str(p))
        sessions.append(sess)
        if input_name is None:
            input_name = sess.get_inputs()[0].name
    return sessions, input_name


def run_binary_ensemble(sessions, input_name, paths, batch_size=32, image_size=(224, 224)):
    preds, probs = [], []
    for i in range(0, len(paths), batch_size):
        batch_paths = paths[i : i + batch_size]
        batch_arrays = [load_and_preprocess_image_onnx_ensemble(p, image_size) for p in batch_paths]
        batch_input = np.concatenate(batch_arrays, axis=0)
        all_out = []
        for sess, w in zip(sessions, ENSEMBLE_WEIGHTS):
            out = sess.run(None, {input_name: batch_input})[0]
            all_out.append(out * w)
        ensemble_logits = np.sum(all_out, axis=0)
        exp_logits = np.exp(ensemble_logits - np.max(ensemble_logits, axis=1, keepdims=True))
        prob_cancer = (exp_logits[:, 1] / exp_logits.sum(axis=1)).astype(np.float64)
        pred_binary = np.argmax(ensemble_logits, axis=1)
        preds.extend(pred_binary.tolist())
        probs.extend(prob_cancer.tolist())
    return np.array(preds), np.array(probs)


def run_fiveclass_ensemble(sessions, input_name, paths, batch_size=32, image_size=(224, 224)):
    """Returns (pred_binary_argmax, prob_cancer_5) where prob_cancer_5 = p(OCA)+p(OPMD)."""
    preds_argmax, probs_cancer = [], []
    for i in range(0, len(paths), batch_size):
        batch_paths = paths[i : i + batch_size]
        batch_arrays = [load_and_preprocess_image_onnx_ensemble(p, image_size) for p in batch_paths]
        batch_input = np.concatenate(batch_arrays, axis=0)
        all_out = []
        for sess, w in zip(sessions, ENSEMBLE_WEIGHTS):
            out = sess.run(None, {input_name: batch_input})[0]
            all_out.append(out * w)
        ensemble_logits = np.sum(all_out, axis=0)
        exp_logits = np.exp(ensemble_logits - np.max(ensemble_logits, axis=1, keepdims=True))
        class_probs = exp_logits / exp_logits.sum(axis=1, keepdims=True)
        prob_cancer_5 = (class_probs[:, 2] + class_probs[:, 3]).astype(np.float64)
        class_idx = np.argmax(ensemble_logits, axis=1)
        pred_binary = np.array([1 if c in CANCER_CLASS_INDICES else 0 for c in class_idx])
        preds_argmax.extend(pred_binary.tolist())
        probs_cancer.extend(prob_cancer_5.tolist())
    return np.array(preds_argmax), np.array(probs_cancer)


def agreement_metrics(y_true, pred_bin, pred_5, prob_bin, prob_5, threshold_bin=0.5, threshold_5=0.5):
    """Argmax agreement and probability-level agreement; optional threshold alignment."""
    n = len(y_true)
    if n == 0:
        return {}
    agree_argmax = np.mean(pred_bin == pred_5)
    # Align thresholds: referral = (prob >= threshold)
    ref_bin = (prob_bin >= threshold_bin).astype(int)
    ref_5 = (prob_5 >= threshold_5).astype(int)
    agree_at_threshold = float(np.mean(ref_bin == ref_5))
    # Correlation of probabilities
    if n > 1:
        corr = float(np.corrcoef(prob_bin, prob_5)[0, 1]) if np.std(prob_bin) > 0 and np.std(prob_5) > 0 else 0.0
    else:
        corr = 0.0
    # Confusion: rows = 5-class mapped to binary, cols = binary
    # (5 says non-cancer, bin says non-cancer), (5 says non-cancer, bin says cancer), etc.
    tn = np.sum((pred_5 == 0) & (pred_bin == 0))
    fp = np.sum((pred_5 == 0) & (pred_bin == 1))
    fn = np.sum((pred_5 == 1) & (pred_bin == 0))
    tp = np.sum((pred_5 == 1) & (pred_bin == 1))
    return {
        "n": int(n),
        "argmax_agreement": float(agree_argmax),
        "agreement_at_threshold": agree_at_threshold,
        "threshold_bin": threshold_bin,
        "threshold_5": threshold_5,
        "prob_correlation": corr,
        "confusion_5_vs_bin": {"tn": int(tn), "fp": int(fp), "fn": int(fn), "tp": int(tp)},
    }


def main():
    parser = argparse.ArgumentParser(description="Agreement analysis: binary vs 5-class ONNX ensembles")
    parser.add_argument("--binary_dir", required=True, help="Directory containing binary ensemble_model_1/2/3.onnx")
    parser.add_argument("--fiveclass_dir", required=True, help="Directory containing 5-class ensemble_model_1/2/3.onnx")
    parser.add_argument("--frozen_dir", default=None, help="Frozen test sets directory")
    parser.add_argument("--output", default=None, help="Output JSON path")
    parser.add_argument("--eval_report_dir", default=None, help="If set, write agreement_all_splits.json here")
    parser.add_argument("--batch_size", type=int, default=32)
    parser.add_argument("--image_size", type=int, nargs=2, default=[224, 224])
    args = parser.parse_args()

    if ort is None:
        print("Error: onnxruntime is required. pip install onnxruntime", file=sys.stderr)
        sys.exit(1)

    frozen_dir = Path(args.frozen_dir) if args.frozen_dir else NOTEBOOK_DIR / "frozen_test_sets"
    image_size = tuple(args.image_size)
    model_names = ["ensemble_model_1.onnx", "ensemble_model_2.onnx", "ensemble_model_3.onnx"]

    binary_dir = Path(args.binary_dir)
    fiveclass_dir = Path(args.fiveclass_dir)
    if not binary_dir.exists() or not fiveclass_dir.exists():
        print("Error: binary_dir or fiveclass_dir not found", file=sys.stderr)
        sys.exit(1)

    bin_sessions, bin_input = load_onnx_ensemble_sessions(binary_dir, model_names)
    five_sessions, five_input = load_onnx_ensemble_sessions(fiveclass_dir, model_names)

    t5_paths, t5_labels = get_t5_binary_paths_labels(frozen_dir)
    tb_paths, tb_labels = get_tb_paths_labels(frozen_dir)
    tc_paths, tc_labels = [], []
    if (frozen_dir / "TC.json").exists():
        try:
            tc_paths, tc_labels = get_tc_paths_labels(frozen_dir)
        except Exception:
            pass
    if (frozen_dir / "TC.json").exists():
        tm_paths, tm_labels, tm_sources = get_tm_paths_labels_and_sources_v2(frozen_dir)
    else:
        tm_paths, tm_labels, tm_sources = get_tm_paths_labels_and_sources(frozen_dir)

    results = {
        "binary_dir": str(binary_dir),
        "fiveclass_dir": str(fiveclass_dir),
        "splits": {},
    }

    def run_split(name, paths, labels):
        if not paths:
            return
        labels = np.array(labels)
        pred_bin, prob_bin = run_binary_ensemble(bin_sessions, bin_input, paths, args.batch_size, image_size)
        pred_5, prob_5 = run_fiveclass_ensemble(five_sessions, five_input, paths, args.batch_size, image_size)
        m = agreement_metrics(labels, pred_bin, pred_5, prob_bin, prob_5)
        m["split"] = name
        results["splits"][name] = m

    print("Agreement on T5...")
    run_split("T5", t5_paths, t5_labels)
    print("Agreement on TB...")
    run_split("TB", tb_paths, tb_labels)
    if tc_paths:
        print("Agreement on TC...")
        run_split("TC", tc_paths, tc_labels)
    print("Agreement on TM...")
    run_split("TM", tm_paths, tm_labels)

    # Overall (TM) summary for backward compatibility
    if "TM" in results["splits"]:
        tm = results["splits"]["TM"]
        results["overall_agreement_pct"] = round(tm["argmax_agreement"] * 100, 2)
        results["overall_n"] = tm["n"]

    print("\n" + "=" * 60)
    print("Agreement (binary vs 5-class)")
    print("=" * 60)
    for name, m in results["splits"].items():
        print(f"  {name}: n={m['n']}  argmax_agreement={m['argmax_agreement']*100:.2f}%  prob_corr={m['prob_correlation']:.4f}  confusion tn={m['confusion_5_vs_bin']['tn']} fp={m['confusion_5_vs_bin']['fp']} fn={m['confusion_5_vs_bin']['fn']} tp={m['confusion_5_vs_bin']['tp']}")

    out_path = args.output
    if args.eval_report_dir:
        out_dir = Path(args.eval_report_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / "agreement_all_splits.json"
    if out_path is None:
        out_path = Path("agreement_all_splits.json")
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {out_path}")


if __name__ == "__main__":
    main()
