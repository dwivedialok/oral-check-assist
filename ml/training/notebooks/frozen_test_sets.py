"""
Frozen test sets for comparable evaluation across all models.

Defines four test sets:
  T5: 5-class-only test (from 5-class dataset test/ split)
  TB: binary-only test (fixed 15% holdout from oral_cavity_binary_dataset)
  TC: binary test from Oral-Image-small-binary-dataset (15% holdout, NEW)
  TM: mixed merged test = T5 (binary view, exclude Unknown) ∪ TB ∪ TC, with source labels

All models (5-class TFLite/ONNX, binary merged TFLite) should be evaluated on T5, TB, TC, and TM
so results are comparable. Per-source metrics on TM distinguish:
  - "model can't learn signal" (poor on all sources)
  - "model learns but doesn't transfer" (good on one source, bad on another)

Usage:
  from frozen_test_sets import build_and_save_frozen_sets_v2, load_frozen_sets_v2, get_all_train_val_for_training

  # One-time: build and save manifests (or run as script)
  build_and_save_frozen_sets_v2(data_dir_5class=..., data_dir_binary=..., data_dir_small_binary=..., out_dir=...)

  # Load for evaluation
  T5, TB, TC, TM, meta = load_frozen_sets_v2(out_dir)

  # For training: get all binary paths that are NOT in frozen test sets
  train_val_paths, train_val_labels = get_all_train_val_for_training(out_dir)

Legacy functions (build_and_save_frozen_sets, load_frozen_sets) still work for backward compatibility.
"""

import json
import os
from pathlib import Path

from sklearn.model_selection import train_test_split

# Fixed seed so TB/TC and any randomness are reproducible
SEED = 42
# Fraction of binary datasets reserved as frozen test
BINARY_TEST_FRACTION = 0.15

# 5-class names: index 0=Benign, 1=Healthy, 2=OCA, 3=OPMD, 4=Unknown
CLASS_NAMES_5 = ["Benign", "Healthy", "OCA", "OPMD", "Unknown"]
# Binary mapping: OCA, OPMD -> 1 (cancer); Benign, Healthy -> 0 (non-cancer); Unknown -> None (exclude from binary eval)
CLASS_TO_BINARY = {"Benign": 0, "Healthy": 0, "OCA": 1, "OPMD": 1, "Unknown": None}

# Local dataset root (images are NOT in this git repo).
# Override with ORAL_DATA_ROOT, e.g. export ORAL_DATA_ROOT=/data/oral
_DATA_ROOT = os.path.expanduser(os.environ.get("ORAL_DATA_ROOT", "~/dev"))


def _under_data_root(*parts: str) -> str:
    return os.path.join(_DATA_ROOT, *parts)


# Default paths for all datasets (resolved under ORAL_DATA_ROOT / ~/dev)
DEFAULT_DATA_DIR_5CLASS = _under_data_root("oral_cavity_5class_dataset")
DEFAULT_DATA_DIR_BINARY = _under_data_root("oral_cavity_binary_dataset")
DEFAULT_DATA_DIR_SMALL_BINARY = _under_data_root(
    "oral-images-dataset", "Oral-Image-small-binary-dataset"
)

# v3 Patient-wise Paths
DEFAULT_DATA_DIR_5CLASS_PATIENTWISE = _under_data_root(
    "oral_cavity_5class_dataset_patientwise"
)
DEFAULT_DATA_DIR_SMART_PATIENTWISE = _under_data_root(
    "oral_cavity_smart_ii_patientwise"
)

CLASS_NAMES_SMART = ["Benign", "Healthy", "OPMD"]


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


def build_t_smart(data_dir_smart):
    """Build T_SMART: 3-class test set from test/ folder. Each row: path, label_5class, label_binary, source='D'."""
    root = Path(data_dir_smart) / "test"
    rows = []
    for class_name in CLASS_NAMES_SMART:
        paths = _collect_images(root / class_name)
        label_binary = CLASS_TO_BINARY[class_name]
        for p in paths:
            rows.append({
                "path": p,
                "label_5class": class_name,
                "label_binary": label_binary,
                "source": "D",
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


def build_tc_and_train_val(data_dir_small_binary, seed=SEED, test_size=BINARY_TEST_FRACTION):
    """
    Split Oral-Image-small-binary-dataset into TC (frozen test) and train+val pool.
    
    Dataset structure:
      original_data/benign_lesions -> non-cancer (0)
      original_data/malignant_lesions -> cancer (1)
    
    NOTE: We only use original_data, NOT augmented_data, to avoid double-augmentation
    issues when Albumentations is applied during training. Pre-augmented images can
    cause compounding effects (rotation on rotation, blur on blur, etc.) leading to
    unrealistic training samples.
    
    Returns (TC_rows, train_val_paths, train_val_labels) so training excludes TC.
    """
    root = Path(data_dir_small_binary)
    
    # Collect only ORIGINAL images (no pre-augmented data)
    # Augmentation will be applied on-the-fly during training via Albumentations
    cancer_paths = []
    non_cancer_paths = []
    
    # Original data only
    cancer_paths.extend(_collect_images(root / "original_data" / "malignant_lesions"))
    non_cancer_paths.extend(_collect_images(root / "original_data" / "benign_lesions"))
    
    all_paths = cancer_paths + non_cancer_paths
    all_labels = [1] * len(cancer_paths) + [0] * len(non_cancer_paths)
    
    if len(all_paths) == 0:
        print(f"  Warning: No images found in {data_dir_small_binary}")
        return [], [], []
    
    train_val_paths, test_paths, train_val_labels, test_labels = train_test_split(
        all_paths, all_labels, test_size=test_size, random_state=seed, stratify=all_labels
    )
    TC = [
        {"path": p, "label_binary": lb, "label_5class": None, "source": "C"}
        for p, lb in zip(test_paths, test_labels)
    ]
    return TC, train_val_paths, train_val_labels


def build_tm_v2(t5_rows, tb_rows, tc_rows):
    """
    TM = T5 (binary view; exclude Unknown) ∪ TB ∪ TC.
    Each row has path, label_binary, source ('A', 'B', or 'C').
    """
    tm = []
    for r in t5_rows:
        if r["label_binary"] is not None:
            tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "A"})
    for r in tb_rows:
        tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "B"})
    for r in tc_rows:
        tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "C"})
    return tm


def build_tm_v3(t5_rows, t_smart_rows, tb_rows, tc_rows):
    """
    TM_v3 = T5 (binary view; exclude Unknown) ∪ T_SMART ∪ TB ∪ TC.
    Sources: A(T5), D(SMART-II), B(TB), C(TC).
    """
    tm = []
    for r in t5_rows:
        if r["label_binary"] is not None:
            tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "A"})
    for r in t_smart_rows:
        if r["label_binary"] is not None:
            tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "D"})
    for r in tb_rows:
        tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "B"})
    for r in tc_rows:
        tm.append({"path": r["path"], "label_binary": r["label_binary"], "source": "C"})
    return tm


def build_and_save_frozen_sets_v2(
    data_dir_5class=None,
    data_dir_binary=None,
    data_dir_small_binary=None,
    out_dir=None,
):
    """
    Build T5, TB, TC, TM and save manifests to out_dir.
    Also save train+val pools for each binary source.
    Returns (T5, TB, TC, TM, meta).
    """
    if data_dir_5class is None:
        data_dir_5class = DEFAULT_DATA_DIR_5CLASS
    if data_dir_binary is None:
        data_dir_binary = DEFAULT_DATA_DIR_BINARY
    if data_dir_small_binary is None:
        data_dir_small_binary = DEFAULT_DATA_DIR_SMALL_BINARY
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Building frozen test sets v2...")
    print(f"  5-class dataset: {data_dir_5class}")
    print(f"  Binary dataset: {data_dir_binary}")
    print(f"  Small binary dataset: {data_dir_small_binary}")

    # Build T5 (5-class test set)
    T5 = build_t5(data_dir_5class)
    
    # Build TB (oral_cavity_binary_dataset holdout)
    TB, binary_train_val_paths, binary_train_val_labels = build_tb_and_train_val(data_dir_binary)
    
    # Build TC (Oral-Image-small-binary-dataset holdout)
    TC, small_binary_train_val_paths, small_binary_train_val_labels = build_tc_and_train_val(data_dir_small_binary)
    
    # Build TM (merged: T5 + TB + TC)
    TM = build_tm_v2(T5, TB, TC)

    meta = {
        "version": 2,
        "seed": SEED,
        "binary_test_fraction": BINARY_TEST_FRACTION,
        "T5_count": len(T5),
        "TB_count": len(TB),
        "TC_count": len(TC),
        "TM_count": len(TM),
        "T5_binary_eligible": sum(1 for r in T5 if r["label_binary"] is not None),
        "data_dir_5class": str(data_dir_5class),
        "data_dir_binary": str(data_dir_binary),
        "data_dir_small_binary": str(data_dir_small_binary),
    }

    # Save test sets
    with open(out_dir / "T5.json", "w") as f:
        json.dump(T5, f, indent=2)
    with open(out_dir / "TB.json", "w") as f:
        json.dump(TB, f, indent=2)
    with open(out_dir / "TC.json", "w") as f:
        json.dump(TC, f, indent=2)
    with open(out_dir / "TM.json", "w") as f:
        json.dump(TM, f, indent=2)
    with open(out_dir / "meta.json", "w") as f:
        json.dump(meta, f, indent=2)
    
    # Save train+val pools for each source (excluding frozen test)
    binary_train_val_manifest = [
        {"path": p, "label_binary": lb, "source": "B"} 
        for p, lb in zip(binary_train_val_paths, binary_train_val_labels)
    ]
    with open(out_dir / "binary_train_val_for_training.json", "w") as f:
        json.dump(binary_train_val_manifest, f, indent=2)
    
    small_binary_train_val_manifest = [
        {"path": p, "label_binary": lb, "source": "C"} 
        for p, lb in zip(small_binary_train_val_paths, small_binary_train_val_labels)
    ]
    with open(out_dir / "small_binary_train_val_for_training.json", "w") as f:
        json.dump(small_binary_train_val_manifest, f, indent=2)

    print(f"\nFrozen test sets v2 saved to {out_dir}")
    print(f"  T5: {len(T5)} samples (5-class test)")
    print(f"  TB: {len(TB)} samples (binary dataset test)")
    print(f"  TC: {len(TC)} samples (small binary dataset test)")
    print(f"  TM: {len(TM)} samples (mixed, all sources)")
    print(f"  binary_train_val_for_training: {len(binary_train_val_manifest)} paths")
    print(f"  small_binary_train_val_for_training: {len(small_binary_train_val_manifest)} paths")
    
    return T5, TB, TC, TM, meta


def load_frozen_sets_v2(out_dir=None):
    """Load T5, TB, TC, TM and meta from out_dir (v2 format)."""
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    
    with open(out_dir / "T5.json") as f:
        T5 = json.load(f)
    with open(out_dir / "TB.json") as f:
        TB = json.load(f)
    
    # TC might not exist in older frozen sets
    tc_path = out_dir / "TC.json"
    if tc_path.exists():
        with open(tc_path) as f:
            TC = json.load(f)
    else:
        TC = []
    
    with open(out_dir / "TM.json") as f:
        TM = json.load(f)
    with open(out_dir / "meta.json") as f:
        meta = json.load(f)
    
    return T5, TB, TC, TM, meta


def build_and_save_frozen_sets_v3(
    data_dir_5class=None,
    data_dir_smart=None,
    data_dir_binary=None,
    data_dir_small_binary=None,
    out_dir=None,
):
    """
    Build T5_v3, TSMART, TB, TC, TM_v3 and save manifests to out_dir.
    Uses patient-wise paths for T5 and SMART by default.
    Returns (T5, T_SMART, TB, TC, TM, meta).
    """
    if data_dir_5class is None:
        data_dir_5class = DEFAULT_DATA_DIR_5CLASS_PATIENTWISE
    if data_dir_smart is None:
        data_dir_smart = DEFAULT_DATA_DIR_SMART_PATIENTWISE
    if data_dir_binary is None:
        data_dir_binary = DEFAULT_DATA_DIR_BINARY
    if data_dir_small_binary is None:
        data_dir_small_binary = DEFAULT_DATA_DIR_SMALL_BINARY
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Building frozen test sets v3 (Patient-Wise)...")
    print(f"  5-class dataset: {data_dir_5class}")
    print(f"  SMART-II dataset: {data_dir_smart}")
    print(f"  Binary dataset: {data_dir_binary}")
    print(f"  Small binary dataset: {data_dir_small_binary}")

    T5 = build_t5(data_dir_5class)
    T_SMART = build_t_smart(data_dir_smart)
    TB, binary_train_val_paths, binary_train_val_labels = build_tb_and_train_val(data_dir_binary)
    TC, small_binary_train_val_paths, small_binary_train_val_labels = build_tc_and_train_val(data_dir_small_binary)
    TM = build_tm_v3(T5, T_SMART, TB, TC)

    meta = {
        "version": 3,
        "seed": SEED,
        "binary_test_fraction": BINARY_TEST_FRACTION,
        "T5_count": len(T5),
        "TSMART_count": len(T_SMART),
        "TB_count": len(TB),
        "TC_count": len(TC),
        "TM_count": len(TM),
        "T5_binary_eligible": sum(1 for r in T5 if r["label_binary"] is not None),
        "TSMART_binary_eligible": sum(1 for r in T_SMART if r["label_binary"] is not None),
        "data_dir_5class": str(data_dir_5class),
        "data_dir_smart": str(data_dir_smart),
        "data_dir_binary": str(data_dir_binary),
        "data_dir_small_binary": str(data_dir_small_binary),
    }

    # Save test sets
    with open(out_dir / "T5_v3.json", "w") as f:
        json.dump(T5, f, indent=2)
    with open(out_dir / "TSMART.json", "w") as f:
        json.dump(T_SMART, f, indent=2)
    with open(out_dir / "TB.json", "w") as f:
        json.dump(TB, f, indent=2)
    with open(out_dir / "TC.json", "w") as f:
        json.dump(TC, f, indent=2)
    with open(out_dir / "TM_v3.json", "w") as f:
        json.dump(TM, f, indent=2)
    with open(out_dir / "meta_v3.json", "w") as f:
        json.dump(meta, f, indent=2)
    
    # Save train+val pools for binary & small binary
    binary_train_val_manifest = [
        {"path": p, "label_binary": lb, "source": "B"} 
        for p, lb in zip(binary_train_val_paths, binary_train_val_labels)
    ]
    with open(out_dir / "binary_train_val_for_training.json", "w") as f:
        json.dump(binary_train_val_manifest, f, indent=2)
    
    small_binary_train_val_manifest = [
        {"path": p, "label_binary": lb, "source": "C"} 
        for p, lb in zip(small_binary_train_val_paths, small_binary_train_val_labels)
    ]
    with open(out_dir / "small_binary_train_val_for_training.json", "w") as f:
        json.dump(small_binary_train_val_manifest, f, indent=2)

    print(f"\\nFrozen test sets v3 saved to {out_dir}")
    print(f"  T5 (v3): {len(T5)} samples (Patient-wise 5-class test)")
    print(f"  TSMART: {len(T_SMART)} samples (Patient-wise SMART-II test)")
    print(f"  TB: {len(TB)} samples (binary dataset test)")
    print(f"  TC: {len(TC)} samples (small binary dataset test)")
    print(f"  TM_v3: {len(TM)} samples (mixed, all sources)")
    print(f"  binary_train_val_for_training: {len(binary_train_val_manifest)} paths")
    print(f"  small_binary_train_val_for_training: {len(small_binary_train_val_manifest)} paths")
    
    return T5, T_SMART, TB, TC, TM, meta


def load_frozen_sets_v3(out_dir=None):
    """Load T5_v3, TSMART, TB, TC, TM_v3 and meta_v3 from out_dir."""
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    
    with open(out_dir / "T5_v3.json") as f:
        T5 = json.load(f)
    with open(out_dir / "TSMART.json") as f:
        T_SMART = json.load(f)
    with open(out_dir / "TB.json") as f:
        TB = json.load(f)
    with open(out_dir / "TC.json") as f:
        TC = json.load(f)
    with open(out_dir / "TM_v3.json") as f:
        TM = json.load(f)
    with open(out_dir / "meta_v3.json") as f:
        meta = json.load(f)
    
    return T5, T_SMART, TB, TC, TM, meta


def get_tc_paths_labels(out_dir=None):
    """Return (paths, labels) for TC."""
    _, _, TC, _, _ = load_frozen_sets_v2(out_dir)
    return [r["path"] for r in TC], [r["label_binary"] for r in TC]


def get_all_train_val_for_training(out_dir=None):
    """
    Return (paths, labels, sources) for ALL binary training data excluding frozen test sets.
    Combines: binary_train_val + small_binary_train_val + 5-class train/val (mapped to binary).
    """
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    
    all_paths = []
    all_labels = []
    all_sources = []
    
    # Load binary train/val (source B)
    binary_manifest_path = out_dir / "binary_train_val_for_training.json"
    if binary_manifest_path.exists():
        with open(binary_manifest_path) as f:
            manifest = json.load(f)
        for r in manifest:
            all_paths.append(r["path"])
            all_labels.append(r["label_binary"])
            all_sources.append(r.get("source", "B"))
    
    # Load small binary train/val (source C)
    small_binary_manifest_path = out_dir / "small_binary_train_val_for_training.json"
    if small_binary_manifest_path.exists():
        with open(small_binary_manifest_path) as f:
            manifest = json.load(f)
        for r in manifest:
            all_paths.append(r["path"])
            all_labels.append(r["label_binary"])
            all_sources.append(r.get("source", "C"))
    
    return all_paths, all_labels, all_sources


def get_all_train_val_for_training_v3(
    out_dir=None, 
    data_dir_5class=None, 
    data_dir_smart=None
):
    """
    Return (paths, labels, sources) for ALL binary training data excluding frozen test sets (v3 version).
    Combines: binary_train_val (B) + small_binary_train_val (C) 
            + patient-wise 5-class train/val (A) 
            + patient-wise SMART train/val (D).
    All labels are dynamically mapped to binary.
    """
    if out_dir is None:
        out_dir = Path(__file__).resolve().parent / "frozen_test_sets"
    out_dir = Path(out_dir)
    if data_dir_5class is None:
        data_dir_5class = DEFAULT_DATA_DIR_5CLASS_PATIENTWISE
    if data_dir_smart is None:
        data_dir_smart = DEFAULT_DATA_DIR_SMART_PATIENTWISE

    all_paths = []
    all_labels = []
    all_sources = []
    
    # Baseline existing binary pools
    base_paths, base_labels, base_sources = get_all_train_val_for_training(out_dir)
    all_paths.extend(base_paths)
    all_labels.extend(base_labels)
    all_sources.extend(base_sources)

    # Gather patient-wise T5 train/val
    five_dir = Path(data_dir_5class)
    for split in ["train", "val"]:
        for class_name in CLASS_NAMES_5:
            # exclude unknown from binary training
            if class_name == "Unknown":
                continue
            folder_paths = _collect_images(five_dir / split / class_name)
            for p in folder_paths:
                all_paths.append(p)
                all_labels.append(CLASS_TO_BINARY[class_name])
                all_sources.append("A")

    # Gather patient-wise SMART train/val
    smart_dir = Path(data_dir_smart)
    for split in ["train", "val"]:
        for class_name in CLASS_NAMES_SMART:
            folder_paths = _collect_images(smart_dir / split / class_name)
            for p in folder_paths:
                all_paths.append(p)
                all_labels.append(CLASS_TO_BINARY[class_name])
                all_sources.append("D")

    return all_paths, all_labels, all_sources


def get_tm_paths_labels_and_sources_v2(out_dir=None):
    """Return (paths, labels, sources) for TM v2. sources[i] is 'A', 'B', or 'C'."""
    _, _, _, TM, _ = load_frozen_sets_v2(out_dir)
    return [r["path"] for r in TM], [r["label_binary"] for r in TM], [r["source"] for r in TM]


def get_tm_paths_labels_and_sources_v3(out_dir=None):
    """Return (paths, labels, sources) for TM v3. sources is 'A', 'B', 'C', or 'D'."""
    _, _, _, _, TM, _ = load_frozen_sets_v3(out_dir)
    return [r["path"] for r in TM], [r["label_binary"] for r in TM], [r["source"] for r in TM]


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
        data_dir_5class = DEFAULT_DATA_DIR_5CLASS
    if data_dir_binary is None:
        data_dir_binary = DEFAULT_DATA_DIR_BINARY
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
            data_dir_binary = DEFAULT_DATA_DIR_BINARY
        build_and_save_frozen_sets(
            data_dir_5class=DEFAULT_DATA_DIR_5CLASS,
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
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--v3":
        # Build v3 frozen sets (patient-wise 5-class + SMART, plus binary datasets)
        build_and_save_frozen_sets_v3()
    elif len(sys.argv) > 1 and sys.argv[1] == "--v2":
        # Build v2 frozen sets (includes TC from small binary dataset)
        build_and_save_frozen_sets_v2()
    else:
        # Legacy: build v1 frozen sets (T5, TB, TM only)
        print("Building v1 frozen sets (use --v3 for new patient-wise format)")
        build_and_save_frozen_sets()
