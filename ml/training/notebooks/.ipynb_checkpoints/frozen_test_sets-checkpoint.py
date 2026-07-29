"""
Frozen test sets for comparable evaluation across all models.

Defines three test sets:
  T5: 5-class-only test (from 5-class dataset test/ split)
  TB: binary-only test (fixed 15% holdout from binary dataset, never used for training)
  TM: mixed merged test = T5 (binary view, exclude Unknown) ∪ TB, with source labels for per-source metrics

All models (5-class TFLite/ONNX, binary merged TFLite) should be evaluated on T5, TB, and TM
so results are comparable. Per-source metrics on TM distinguish:
  - "model can't learn signal" (poor on all three)
  - "model learns but doesn't transfer" (good on one source, bad on another in TM)

Usage:
  from frozen_test_sets import build_and_save_frozen_sets, load_frozen_sets, get_binary_train_val_for_training

  # One-time: build and save manifests (or run as script)
  build_and_save_frozen_sets(data_dir_5class=..., data_dir_binary=..., out_dir=...)

  # Load for evaluation
  T5, TB, TM, meta = load_frozen_sets(out_dir)

  # For training binary merged: get binary paths that are NOT in TB
  binary_train_val_paths, binary_train_val_labels = get_binary_train_val_for_training(data_dir_binary, out_dir)
"""

import json
import os
from pathlib import Path

from sklearn.model_selection import train_test_split

# Fixed seed so TB and any randomness are reproducible
SEED = 42
# Fraction of binary dataset reserved as TB (frozen test)
BINARY_TEST_FRACTION = 0.15

# 5-class names: index 0=Benign, 1=Healthy, 2=OCA, 3=OPMD, 4=Unknown
CLASS_NAMES_5 = ["Benign", "Healthy", "OCA", "OPMD", "Unknown"]
# Binary mapping: OCA, OPMD -> 1 (cancer); Benign, Healthy -> 0 (non-cancer); Unknown -> None (exclude from binary eval)
CLASS_TO_BINARY = {"Benign": 0, "Healthy": 0, "OCA": 1, "OPMD": 1, "Unknown": None}


def _collect_images(folder_path, extensions=("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG")):
    folder = Path(folder_path)
    images = []
    if folder.exists():
        for ext in extensions:
            images.extend([str(p) for p in folder.glob(ext)])
    return images


def build_t5(data_dir_5class):
    """Build T5: 5-class test set from test/ folder. Each row: path, label_5class, label_binary, source='A'."""
    root = Path(data_dir_5class) / "test"
    rows = []
    for class_name in CLASS_NAMES_5:
        paths = _collect_images(root / class_name)
        label_binary = CLASS_TO_BINARY[class_name]
        for p in paths:
            rows.append({
                "path": p,
                "label_5class": class_name,
                "label_binary": label_binary,  # None for Unknown
                "source": "A",
            })
    return rows


def build_tb_and_train_val(data_dir_binary, seed=SEED, test_size=BINARY_TEST_FRACTION):
    """
    Split binary dataset into TB (frozen test) and train+val pool.
    Returns (TB_rows, train_val_paths, train_val_labels) so training excludes TB.
    """
    root = Path(data_dir_binary)
    cancer_paths = _collect_images(root / "cancer")
    non_cancer_paths = _collect_images(root / "non-cancer")
    all_paths = cancer_paths + non_cancer_paths
    all_labels = [1] * len(cancer_paths) + [0] * len(non_cancer_paths)

    train_val_paths, test_paths, train_val_labels, test_labels = train_test_split(
        all_paths, all_labels, test_size=test_size, random_state=seed, stratify=all_labels
    )
    TB = [
        {"path": p, "label_binary": lb, "label_5class": None, "source": "B"}
        for p, lb in zip(test_paths, test_labels)
    ]
    return TB, train_val_paths, train_val_labels


def build_tm(t5_rows, tb_rows):
    """
    TM = T5 (binary view; exclude Unknown) ∪ TB.
    Each row has path, label_binary, source ('A' or 'B').
    """
    tm = []
    for r in t5_rows:
        if r["label_binary"] is not None:
            tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "A"})
    for r in tb_rows:
        tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "B"})
    return tm


def build_and_save_frozen_sets(
    data_dir_5class=None,
    data_dir_binary=None,
    out_dir=None,
):
    """
    Build T5, TB, TM and save manifests to out_dir. Also save binary TB so we can
    exclude those paths when building training data. Returns (T5, TB, TM, meta).
    """
    if data_dir_5class is None:
        data_dir_5class = os.path.expanduser("~/dev/oral_cavity_5class_dataset")
    if data_dir_binary is None:
        data_dir_binary = os.path.expanduser("~/dev/oral_cavity_binary_dataset")
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    T5 = build_t5(data_dir_5class)
    TB, binary_train_val_paths, binary_train_val_labels = build_tb_and_train_val(data_dir_binary)
    TM = build_tm(T5, TB)

    meta = {
        "seed": SEED,
        "binary_test_fraction": BINARY_TEST_FRACTION,
        "T5_count": len(T5),
        "TB_count": len(TB),
        "TM_count": len(TM),
        "T5_binary_eligible": sum(1 for r in T5 if r["label_binary"] is not None),
        "data_dir_5class": str(data_dir_5class),
        "data_dir_binary": str(data_dir_binary),
    }

    with open(out_dir / "T5.json", "w") as f:
        json.dump(T5, f, indent=2)
    with open(out_dir / "TB.json", "w") as f:
        json.dump(TB, f, indent=2)
    with open(out_dir / "TM.json", "w") as f:
        json.dump(TM, f, indent=2)
    with open(out_dir / "meta.json", "w") as f:
        json.dump(meta, f, indent=2)
    # For training: list of binary paths that are NOT in TB (train+val only)
    binary_train_val_manifest = [
        {"path": p, "label_binary": lb} for p, lb in zip(binary_train_val_paths, binary_train_val_labels)
    ]
    with open(out_dir / "binary_train_val_for_training.json", "w") as f:
        json.dump(binary_train_val_manifest, f, indent=2)

    print(f"Frozen test sets saved to {out_dir}")
    print(f"  T5: {len(T5)} samples (5-class test)")
    print(f"  TB: {len(TB)} samples (binary-only test)")
    print(f"  TM: {len(TM)} samples (mixed, source-balanced for reporting)")
    print(f"  binary_train_val_for_training: {len(binary_train_val_manifest)} paths (use these for merged training)")
    return T5, TB, TM, meta


def load_frozen_sets(out_dir=None):
    """Load T5, TB, TM and meta from out_dir."""
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    with open(out_dir / "T5.json") as f:
        T5 = json.load(f)
    with open(out_dir / "TB.json") as f:
        TB = json.load(f)
    with open(out_dir / "TM.json") as f:
        TM = json.load(f)
    with open(out_dir / "meta.json") as f:
        meta = json.load(f)
    return T5, TB, TM, meta


def get_binary_train_val_for_training(data_dir_binary=None, out_dir=None):
    """
    Return (paths, labels) for binary dataset excluding TB, for use in merged training.
    If frozen sets not yet built, builds them first.
    """
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    manifest_path = out_dir / "binary_train_val_for_training.json"
    if not manifest_path.exists():
        if data_dir_binary is None:
            data_dir_binary = os.path.expanduser("~/dev/oral_cavity_binary_dataset")
        build_and_save_frozen_sets(
            data_dir_5class=os.path.expanduser("~/dev/oral_cavity_5class_dataset"),
            data_dir_binary=data_dir_binary,
            out_dir=out_dir,
        )
    with open(manifest_path) as f:
        manifest = json.load(f)
    paths = [r["path"] for r in manifest]
    labels = [r["label_binary"] for r in manifest]
    return paths, labels


def get_t5_binary_paths_labels(out_dir=None):
    """Return (paths, labels) for T5 restricted to binary-eligible rows (exclude Unknown). For binary model eval."""
    T5, _, _, _ = load_frozen_sets(out_dir)
    paths = [r["path"] for r in T5 if r["label_binary"] is not None]
    labels = [r["label_binary"] for r in T5 if r["label_binary"] is not None]
    return paths, labels


def get_tb_paths_labels(out_dir=None):
    """Return (paths, labels) for TB."""
    _, TB, _, _ = load_frozen_sets(out_dir)
    return [r["path"] for r in TB], [r["label_binary"] for r in TB]


def get_tm_paths_labels_and_sources(out_dir=None):
    """Return (paths, labels, sources) for TM. sources[i] is 'A' or 'B'."""
    _, _, TM, _ = load_frozen_sets(out_dir)
    return [r["path"] for r in TM], [r["label_binary"] for r in TM], [r["source"] for r in TM]


if __name__ == "__main__":
    build_and_save_frozen_sets()
