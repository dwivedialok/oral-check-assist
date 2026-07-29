#!/usr/bin/env python3
"""
Evaluate any binary or 5-class model on frozen test sets T5, TB, TM.

Makes results comparable across 5-class TFLite/ONNX and binary merged models by
reporting on the same three test sets and TM per-source (A vs B).

Usage:
  # Binary TFLite (e.g. from binary_classification_merged_dataset)
  python evaluate_on_frozen_sets.py --model path/to/binary_merged_dynamic.tflite --model_type binary_tflite

  # 5-class TFLite (map to binary for T5/TB/TM: OCA+OPMD=1, Benign+Healthy=0)
  python evaluate_on_frozen_sets.py --model path/to/5class.tflite --model_type 5class_tflite

  # 5-class ONNX Virtual Ensemble (3 models, weighted 0.30/0.40/0.30, map to binary for T5/TB/TM)
  python evaluate_on_frozen_sets.py --model path/to/dir/with/ensemble_model_1.onnx,2.onnx,3.onnx --model_type 5class_onnx_ensemble

  # Binary ONNX Virtual Ensemble (3 models, 2-class output; trained on merged binary dataset)
  python evaluate_on_frozen_sets.py --model path/to/dir/with/ensemble_model_1.onnx,2.onnx,3.onnx --model_type binary_onnx_ensemble

  # Output: prints summary and writes evaluation_frozen_T5_TB_TM.json to current dir (or --output)
"""

import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np
from sklearn.metrics import (
    roc_auc_score,
    average_precision_score,
    brier_score_loss,
)
from sklearn.calibration import calibration_curve

# Optional: onnxruntime for 5class_onnx_ensemble
try:
    import onnxruntime as ort
    HAS_ONNXRUNTIME = True
except ImportError:
    HAS_ONNXRUNTIME = False

# Add notebook dir so we can import frozen_test_sets
NOTEBOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(NOTEBOOK_DIR))

from frozen_test_sets import (
    get_t5_binary_paths_labels,
    get_tb_paths_labels,
    get_tm_paths_labels_and_sources,
    get_tm_paths_labels_and_sources_v2,
    get_tc_paths_labels,
    load_frozen_sets,
    load_frozen_sets_v2,
)


def _ensure_tf():
    import tensorflow as tf
    return tf


def load_and_preprocess_image(path, image_size=(224, 224)):
    """Load and preprocess for TFLite (HWC, float32, [0,1]). Uses PIL to support more formats (e.g. JPEG, PNG, WebP)."""
    from PIL import Image
    img = Image.open(path).convert("RGB")
    img = img.resize(image_size)
    arr = np.array(img).astype(np.float32) / 255.0
    return arr


def run_predictions_binary_tflite(model_path, paths, labels, batch_size=32, image_size=(224, 224)):
    tf = _ensure_tf()
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    # Many TFLite models are exported with batch size 1 (or report -1); use 1 when not clearly batched
    input_shape = input_details[0].get("shape", [])
    try:
        first_dim = input_shape[0] if len(input_shape) > 0 else None
        first_dim = int(first_dim) if first_dim is not None else None
        effective_batch = first_dim if (first_dim is not None and first_dim > 0) else 1
    except (TypeError, ValueError):
        effective_batch = 1

    preds, probs = [], []
    for i in range(0, len(paths), effective_batch):
        batch_paths = paths[i : i + effective_batch]
        batch_images = []
        for p in batch_paths:
            img = load_and_preprocess_image(p, image_size)
            batch_images.append(img)
        batch = np.stack(batch_images).astype(np.float32)
        if batch.shape[0] != len(batch_paths):
            continue
        interpreter.set_tensor(input_details[0]["index"], batch)
        interpreter.invoke()
        out = interpreter.get_tensor(output_details[0]["index"])
        if out.ndim == 2:
            out = out[:, -1] if out.shape[1] == 2 else out[:, 0]
        probs.extend(out.flatten().tolist())
        preds.extend((np.array(out).flatten() >= 0.5).astype(int).tolist())

    return np.array(preds), np.array(probs)


def load_and_preprocess_image_onnx_ensemble(path, image_size=(224, 224)):
    """Preprocess for ONNX ensemble (same as pytorch_to_onnx_ensemble.ipynb: PIL, 224, ImageNet norm, CHW)."""
    from PIL import Image
    img = Image.open(path).convert("RGB")
    img = img.resize(image_size)
    arr = np.array(img).astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406])
    std = np.array([0.229, 0.224, 0.225])
    arr = (arr - mean) / std
    arr = np.transpose(arr, (2, 0, 1))  # HWC -> CHW
    arr = np.expand_dims(arr, axis=0).astype(np.float32)
    return arr


# 5-class indices: Benign=0, Healthy=1, OCA=2, OPMD=3, Unknown=4. Binary: OCA+OPMD -> 1, else -> 0.
CANCER_CLASS_INDICES = {2, 3}
# Ensemble weights (per CURRENT_PROGRESS_STATUS: 0.30, 0.40, 0.30)
ENSEMBLE_WEIGHTS = [0.30, 0.40, 0.30]


def run_predictions_binary_onnx_ensemble(model_dir, paths, labels_binary, batch_size=32, image_size=(224, 224)):
    """Binary ONNX Virtual Ensemble: 3 models, weighted average, 2-class output (0=non-cancer, 1=cancer)."""
    if not HAS_ONNXRUNTIME:
        raise RuntimeError("onnxruntime is required for binary_onnx_ensemble. pip install onnxruntime")
    model_dir = Path(model_dir)
    onnx_names = ["ensemble_model_1.onnx", "ensemble_model_2.onnx", "ensemble_model_3.onnx"]
    sessions = []
    input_name = None
    for name in onnx_names:
        p = model_dir / name
        if not p.exists():
            raise FileNotFoundError(f"Expected {p} for binary_onnx_ensemble")
        sess = ort.InferenceSession(str(p))
        sessions.append(sess)
        if input_name is None:
            input_name = sess.get_inputs()[0].name

    preds, probs = [], []
    for i in range(0, len(paths), batch_size):
        batch_paths = paths[i : i + batch_size]
        batch_arrays = [load_and_preprocess_image_onnx_ensemble(p, image_size) for p in batch_paths]
        batch_input = np.concatenate(batch_arrays, axis=0)
        all_preds = []
        for sess, w in zip(sessions, ENSEMBLE_WEIGHTS):
            out = sess.run(None, {input_name: batch_input})[0]
            all_preds.append(out * w)
        ensemble_logits = np.sum(all_preds, axis=0)
        # Output shape (N, 2): index 1 = cancer
        pred_binary = np.argmax(ensemble_logits, axis=1)
        # Probability of class 1 (cancer) via softmax
        exp_logits = np.exp(ensemble_logits - np.max(ensemble_logits, axis=1, keepdims=True))
        prob_cancer = (exp_logits[:, 1] / exp_logits.sum(axis=1)).astype(np.float64)
        preds.extend(pred_binary.tolist())
        probs.extend(prob_cancer.tolist())

    return np.array(preds), np.array(probs)


def run_predictions_5class_onnx_ensemble(model_dir, paths, labels_binary, batch_size=32, image_size=(224, 224)):
    """5-class ONNX Virtual Ensemble: 3 models, weighted average, map to binary (OCA+OPMD=1, else=0).
    Binary probability = p(OCA) + p(OPMD) after softmax over 5 classes."""
    if not HAS_ONNXRUNTIME:
        raise RuntimeError("onnxruntime is required for 5class_onnx_ensemble. pip install onnxruntime")
    model_dir = Path(model_dir)
    onnx_names = ["ensemble_model_1.onnx", "ensemble_model_2.onnx", "ensemble_model_3.onnx"]
    sessions = []
    input_name = None
    for name in onnx_names:
        p = model_dir / name
        if not p.exists():
            raise FileNotFoundError(f"Expected {p} for 5class_onnx_ensemble")
        sess = ort.InferenceSession(str(p))
        sessions.append(sess)
        if input_name is None:
            input_name = sess.get_inputs()[0].name

    preds, probs = [], []
    for i in range(0, len(paths), batch_size):
        batch_paths = paths[i : i + batch_size]
        batch_arrays = [load_and_preprocess_image_onnx_ensemble(p, image_size) for p in batch_paths]
        batch_input = np.concatenate(batch_arrays, axis=0)
        all_preds = []
        for sess, w in zip(sessions, ENSEMBLE_WEIGHTS):
            out = sess.run(None, {input_name: batch_input})[0]
            all_preds.append(out * w)
        ensemble_logits = np.sum(all_preds, axis=0)
        # Softmax to get class probabilities
        exp_logits = np.exp(ensemble_logits - np.max(ensemble_logits, axis=1, keepdims=True))
        class_probs = (exp_logits / exp_logits.sum(axis=1, keepdims=True)).astype(np.float64)
        # Binary cancer probability = p(OCA) + p(OPMD) (indices 2 and 3)
        prob_binary = (class_probs[:, 2] + class_probs[:, 3])
        class_idx = np.argmax(ensemble_logits, axis=1)
        pred_binary = np.array([1 if c in CANCER_CLASS_INDICES else 0 for c in class_idx])
        preds.extend(pred_binary.tolist())
        probs.extend(prob_binary.tolist())

    return np.array(preds), np.array(probs)


def run_predictions_5class_tflite(model_path, paths, labels_binary, batch_size=32, image_size=(224, 224)):
    """5-class TFLite: output 5 classes; map to binary (OCA=2, OPMD=3 -> 1; Benign=0, Healthy=1 -> 0)."""
    tf = _ensure_tf()
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    # Class indices assumed: Benign=0, Healthy=1, OCA=2, OPMD=3, Unknown=4
    CANCER_CLASS_INDICES = {2, 3}  # OCA, OPMD
    # Respect fixed batch size (e.g. 1); many 5-class TFLite models are batch-1 only
    input_shape = input_details[0].get("shape", [])
    try:
        first_dim = input_shape[0] if len(input_shape) > 0 else None
        first_dim = int(first_dim) if first_dim is not None else None
        effective_batch = first_dim if (first_dim is not None and first_dim > 0) else 1
    except (TypeError, ValueError):
        effective_batch = 1

    preds, probs = [], []
    for i in range(0, len(paths), effective_batch):
        batch_paths = paths[i : i + effective_batch]
        batch_images = []
        for p in batch_paths:
            img = load_and_preprocess_image(p, image_size)
            batch_images.append(img)
        batch = np.stack(batch_images).astype(np.float32)
        interpreter.set_tensor(input_details[0]["index"], batch)
        interpreter.invoke()
        out = interpreter.get_tensor(output_details[0]["index"])
        if out.ndim == 2:
            class_idx = np.argmax(out, axis=1)
        else:
            class_idx = out.flatten()
        pred_binary = np.array([1 if c in CANCER_CLASS_INDICES else 0 for c in class_idx])
        # Fake prob as 0.9 for predicted class
        prob_binary = np.where(pred_binary == 1, 0.9, 0.1).astype(np.float32)
        preds.extend(pred_binary.tolist())
        probs.extend(prob_binary.tolist())

    return np.array(preds), np.array(probs)


def expected_calibration_error(y_true, y_prob, n_bins=10):
    """ECE: average |accuracy_bin - confidence_bin| weighted by bin count."""
    if len(y_true) == 0 or np.unique(y_true).size < 2:
        return 0.0
    prob_true, prob_pred = calibration_curve(y_true, y_prob, n_bins=n_bins, strategy="uniform")
    # Recompute bin counts and acc/conf per bin for ECE
    bins = np.linspace(0, 1, n_bins + 1)
    bin_indices = np.clip(np.searchsorted(bins[1:-1], y_prob), 0, n_bins - 1)
    ece = 0.0
    n = len(y_true)
    for b in range(n_bins):
        mask = bin_indices == b
        if mask.sum() == 0:
            continue
        acc_bin = float(np.mean(y_true[mask] == (y_prob[mask] >= 0.5).astype(int)))
        conf_bin = float(np.mean(y_prob[mask]))
        ece += mask.sum() / n * abs(acc_bin - conf_bin)
    return float(ece)


def sensitivity_at_specificity(y_true, y_prob, target_spec, n_thresholds=200):
    """Sensitivity at fixed target specificity (e.g. 0.90)."""
    if len(y_true) == 0 or np.unique(y_true).size < 2:
        return 0.0
    thresholds = np.linspace(0, 1, n_thresholds)
    best_sens = 0.0
    for t in thresholds:
        pred = (y_prob >= t).astype(int)
        tn = np.sum((pred == 0) & (y_true == 0))
        n_neg = np.sum(y_true == 0)
        spec = tn / n_neg if n_neg else 1.0
        if spec >= target_spec:
            tp = np.sum((pred == 1) & (y_true == 1))
            n_pos = np.sum(y_true == 1)
            sens = tp / n_pos if n_pos else 0.0
            if sens >= best_sens:
                best_sens = sens
    return float(best_sens)


def _filter_existing_paths(paths, labels, split_name: str):
    """Drop manifest entries whose files are missing; warn to stderr."""
    from pathlib import Path as P

    ok_p, ok_l = [], []
    missing = []
    for p, lb in zip(paths, labels):
        if P(p).is_file():
            ok_p.append(p)
            ok_l.append(lb)
        else:
            missing.append(p)
    if missing:
        print(
            f"Warning: {split_name}: {len(missing)} path(s) not found on disk (skipped). "
            f"Example: {missing[0]}",
            file=sys.stderr,
        )
    if not ok_p:
        raise SystemExit(f"No images left for {split_name} after filtering missing paths.")
    return ok_p, ok_l


def _filter_tm_paths_labels_sources(tm_paths, tm_labels, tm_sources, split_name: str):
    """Like _filter_existing_paths but keeps tm_sources aligned (A/B/C tags)."""
    from pathlib import Path as P

    src = np.asarray(tm_sources).ravel()
    ok_p, ok_l, ok_s = [], [], []
    missing = []
    for i, p in enumerate(tm_paths):
        if P(p).is_file():
            ok_p.append(p)
            ok_l.append(tm_labels[i])
            ok_s.append(src[i])
        else:
            missing.append(p)
    if missing:
        print(
            f"Warning: {split_name}: {len(missing)} path(s) not found on disk (skipped). "
            f"Example: {missing[0]}",
            file=sys.stderr,
        )
    if not ok_p:
        raise SystemExit(f"No images left for {split_name} after filtering missing paths.")
    return ok_p, list(ok_l), np.array(ok_s)


def metrics_dict(true, pred, prob=None):
    """Basic metrics from predictions. If prob is provided, add AUROC, AUPRC, Brier, ECE, sens@90spec, sens@85spec."""
    acc = float(np.mean(pred == true))
    cancer_mask = true == 1
    non_cancer_mask = true == 0
    sens = float(np.mean(pred[cancer_mask] == true[cancer_mask])) if cancer_mask.sum() else 0.0
    spec = float(np.mean(pred[non_cancer_mask] == true[non_cancer_mask])) if non_cancer_mask.sum() else 0.0
    out = {"accuracy": acc, "sensitivity": sens, "specificity": spec, "n": int(len(true))}
    if prob is not None and len(prob) == len(true) and np.unique(true).size >= 2:
        out["auroc"] = float(roc_auc_score(true, prob))
        out["auprc"] = float(average_precision_score(true, prob))
        out["brier"] = float(brier_score_loss(true, prob))
        out["ece"] = expected_calibration_error(true, prob)
        out["sens_at_90spec"] = sensitivity_at_specificity(true, prob, 0.90)
        out["sens_at_85spec"] = sensitivity_at_specificity(true, prob, 0.85)
    return out


def main():
    parser = argparse.ArgumentParser(description="Evaluate model on frozen test sets T5, TB, TC, TM")
    parser.add_argument("--model", required=True, help="Path to model (TFLite or ONNX)")
    parser.add_argument("--model_type", choices=["binary_tflite", "5class_tflite", "5class_onnx_ensemble", "binary_onnx_ensemble"], default="binary_tflite")
    parser.add_argument("--frozen_dir", default=None, help="Directory with T5.json, TB.json, TC.json, TM.json")
    parser.add_argument("--output", default=None, help="Output JSON path (default: evaluation_frozen_T5_TB_TM.json)")
    parser.add_argument("--eval_report_dir", default=None, help="If set, write binary_metrics.json or fiveclass_metrics.json here (for run_full_evaluation)")
    parser.add_argument("--run_id", default=None, help="Run ID for eval_report_dir naming")
    parser.add_argument("--batch_size", type=int, default=32)
    parser.add_argument("--image_size", type=int, nargs=2, default=[224, 224])
    parser.add_argument(
        "--skip-missing-images",
        action="store_true",
        help="Skip frozen-manifest paths that are not on disk (warns; use when manifests are stale vs local tree)",
    )
    args = parser.parse_args()

    if args.frozen_dir is None:
        args.frozen_dir = NOTEBOOK_DIR / "frozen_test_sets"
    args.frozen_dir = Path(args.frozen_dir)
    if args.output is None:
        args.output = Path("evaluation_frozen_T5_TB_TM.json")
    else:
        args.output = Path(args.output)
    image_size = tuple(args.image_size)

    # Load frozen sets: use v2 if TC exists for full T5/TB/TC/TM and TM sources A/B/C
    T5, TB, TM, meta = load_frozen_sets(args.frozen_dir)
    t5_paths, t5_labels = get_t5_binary_paths_labels(args.frozen_dir)
    tb_paths, tb_labels = get_tb_paths_labels(args.frozen_dir)
    tc_paths, tc_labels = [], []
    if (args.frozen_dir / "TC.json").exists():
        try:
            tc_paths, tc_labels = get_tc_paths_labels(args.frozen_dir)
        except Exception:
            pass
    use_v2_tm = (args.frozen_dir / "TC.json").exists()
    if use_v2_tm:
        tm_paths, tm_labels, tm_sources = get_tm_paths_labels_and_sources_v2(args.frozen_dir)
    else:
        tm_paths, tm_labels, tm_sources = get_tm_paths_labels_and_sources(args.frozen_dir)

    model_path = Path(args.model)
    if not model_path.exists():
        print(f"Error: model not found: {model_path}", file=sys.stderr)
        sys.exit(1)

    if args.model_type == "binary_tflite":
        run_fn = run_predictions_binary_tflite
    elif args.model_type == "5class_tflite":
        run_fn = run_predictions_5class_tflite
    elif args.model_type == "5class_onnx_ensemble":
        if not HAS_ONNXRUNTIME:
            print("Error: onnxruntime is required for 5class_onnx_ensemble. pip install onnxruntime", file=sys.stderr)
            sys.exit(1)
        for name in ["ensemble_model_1.onnx", "ensemble_model_2.onnx", "ensemble_model_3.onnx"]:
            if not (model_path / name).exists():
                print(f"Error: expected {model_path / name} for 5class_onnx_ensemble", file=sys.stderr)
                sys.exit(1)
        run_fn = run_predictions_5class_onnx_ensemble
    elif args.model_type == "binary_onnx_ensemble":
        if not HAS_ONNXRUNTIME:
            print("Error: onnxruntime is required for binary_onnx_ensemble. pip install onnxruntime", file=sys.stderr)
            sys.exit(1)
        for name in ["ensemble_model_1.onnx", "ensemble_model_2.onnx", "ensemble_model_3.onnx"]:
            if not (model_path / name).exists():
                print(f"Error: expected {model_path / name} for binary_onnx_ensemble", file=sys.stderr)
                sys.exit(1)
        run_fn = run_predictions_binary_onnx_ensemble
    else:
        run_fn = run_predictions_5class_tflite

    if args.skip_missing_images:
        t5_paths, t5_labels = _filter_existing_paths(t5_paths, t5_labels, "T5")
        tb_paths, tb_labels = _filter_existing_paths(tb_paths, tb_labels, "TB")
        if tc_paths:
            tc_paths, tc_labels = _filter_existing_paths(tc_paths, tc_labels, "TC")
        tm_paths, tm_labels, tm_sources = _filter_tm_paths_labels_sources(
            tm_paths, tm_labels, tm_sources, "TM"
        )

    print("Running on T5...")
    t5_pred, t5_prob = run_fn(model_path, t5_paths, t5_labels, args.batch_size, image_size)
    t5_true = np.array(t5_labels)
    print("Running on TB...")
    tb_pred, tb_prob = run_fn(model_path, tb_paths, tb_labels, args.batch_size, image_size)
    tb_true = np.array(tb_labels)
    if tc_paths:
        print("Running on TC...")
        tc_pred, tc_prob = run_fn(model_path, tc_paths, tc_labels, args.batch_size, image_size)
        tc_true = np.array(tc_labels)
    else:
        tc_pred = tc_prob = tc_true = np.array([])
    print("Running on TM...")
    tm_pred, tm_prob = run_fn(model_path, tm_paths, tm_labels, args.batch_size, image_size)
    tm_true = np.array(tm_labels)

    m_t5 = metrics_dict(t5_true, t5_pred, t5_prob)
    m_tb = metrics_dict(tb_true, tb_pred, tb_prob)
    m_tm = metrics_dict(tm_true, tm_pred, tm_prob)
    if len(tc_true) > 0:
        m_tc = metrics_dict(tc_true, tc_pred, tc_prob)
    else:
        m_tc = {}

    tm_sources = np.array(tm_sources)
    tm_a_mask = tm_sources == "A"
    tm_b_mask = tm_sources == "B"
    tm_c_mask = tm_sources == "C"
    m_tm_A = metrics_dict(tm_true[tm_a_mask], tm_pred[tm_a_mask], tm_prob[tm_a_mask]) if tm_a_mask.sum() else {}
    m_tm_B = metrics_dict(tm_true[tm_b_mask], tm_pred[tm_b_mask], tm_prob[tm_b_mask]) if tm_b_mask.sum() else {}
    m_tm_C = metrics_dict(tm_true[tm_c_mask], tm_pred[tm_c_mask], tm_prob[tm_c_mask]) if tm_c_mask.sum() else {}

    results = {
        "model": str(model_path),
        "model_type": args.model_type,
        "T5": m_t5,
        "TB": m_tb,
        "TM": m_tm,
        "TM_source_A": m_tm_A,
        "TM_source_B": m_tm_B,
    }
    if m_tc:
        results["TC"] = m_tc
    if m_tm_C:
        results["TM_source_C"] = m_tm_C

    # Print summary
    print("\n" + "=" * 60)
    print("Frozen test sets: T5, TB" + (", TC" if m_tc else "") + ", TM")
    print("=" * 60)
    print(f"T5 (5-class test):  n={m_t5['n']}  Acc={m_t5['accuracy']*100:.2f}%  Sens={m_t5['sensitivity']*100:.2f}%  Spec={m_t5['specificity']*100:.2f}%" + (f"  AUROC={m_t5.get('auroc', 0):.4f}" if m_t5.get('auroc') is not None else ""))
    print(f"TB (binary test):   n={m_tb['n']}  Acc={m_tb['accuracy']*100:.2f}%  Sens={m_tb['sensitivity']*100:.2f}%  Spec={m_tb['specificity']*100:.2f}%" + (f"  AUROC={m_tb.get('auroc', 0):.4f}" if m_tb.get('auroc') is not None else ""))
    if m_tc:
        print(f"TC (small binary):  n={m_tc['n']}  Acc={m_tc['accuracy']*100:.2f}%  Sens={m_tc['sensitivity']*100:.2f}%  Spec={m_tc['specificity']*100:.2f}%" + (f"  AUROC={m_tc.get('auroc', 0):.4f}" if m_tc.get('auroc') is not None else ""))
    print(f"TM (mixed):         n={m_tm['n']}  Acc={m_tm['accuracy']*100:.2f}%  Sens={m_tm['sensitivity']*100:.2f}%  Spec={m_tm['specificity']*100:.2f}%" + (f"  AUROC={m_tm.get('auroc', 0):.4f}  S@90Sp={m_tm.get('sens_at_90spec', 0)*100:.1f}%  Brier={m_tm.get('brier', 0):.4f}  ECE={m_tm.get('ece', 0):.4f}" if m_tm.get('auroc') is not None else ""))
    print("TM per-source:")
    print(f"  Source A (5-class): Acc={m_tm_A.get('accuracy',0)*100:.2f}%  Sens={m_tm_A.get('sensitivity',0)*100:.2f}%  Spec={m_tm_A.get('specificity',0)*100:.2f}%")
    print(f"  Source B (binary): Acc={m_tm_B.get('accuracy',0)*100:.2f}%  Sens={m_tm_B.get('sensitivity',0)*100:.2f}%  Spec={m_tm_B.get('specificity',0)*100:.2f}%")
    if m_tm_C:
        print(f"  Source C (small):  Acc={m_tm_C.get('accuracy',0)*100:.2f}%  Sens={m_tm_C.get('sensitivity',0)*100:.2f}%  Spec={m_tm_C.get('specificity',0)*100:.2f}%")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {args.output}")

    if args.eval_report_dir:
        out_dir = Path(args.eval_report_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        is_binary = args.model_type in ("binary_tflite", "binary_onnx_ensemble")
        fname = "binary_metrics.json" if is_binary else "fiveclass_metrics.json"
        report_path = out_dir / fname
        report = {"model": str(model_path), "model_type": args.model_type, "run_id": args.run_id}
        report.update({k: v for k, v in results.items() if k in ("T5", "TB", "TC", "TM", "TM_source_A", "TM_source_B", "TM_source_C")})
        with open(report_path, "w") as f:
            json.dump(report, f, indent=2)
        print(f"Eval report written to: {report_path}")


if __name__ == "__main__":
    main()
