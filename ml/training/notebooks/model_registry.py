"""
Canonical Model Registry
========================
Single source of truth for all trained model paths used across notebooks.

IMPORTANT: Update this file whenever a new model run becomes the canonical version.
Every notebook that loads models for evaluation or agreement analysis should import
paths from here — never hardcode model paths directly.

Last updated: 23 May 2026
"""

from pathlib import Path

# ─── Root directories ─────────────────────────────────────────────────────────
NOTEBOOK_DIR = Path(__file__).resolve().parent
RESULTS_DIR = NOTEBOOK_DIR / "results"
FROZEN_SETS_DIR = NOTEBOOK_DIR / "frozen_test_sets"

# ─── Binary Ensemble (progressive_K5) ────────────────────────────────────────
# Source: freeze_strategy_comparison.ipynb  (run: freeze_comparison_20260208_121618)
# Strategy: progressive_K5  (winner on frozen test sets — TM AUC 0.9291)
# Exported to ONNX in section 18 of that notebook on 09 Feb 2026.
BINARY_PROGRESSIVE_K5_RUN = "freeze_comparison/freeze_comparison_20260208_121618"
BINARY_PROGRESSIVE_K5_ONNX_DIR = RESULTS_DIR / BINARY_PROGRESSIVE_K5_RUN / "onnx"
BINARY_PROGRESSIVE_K5_PTH_DIR = RESULTS_DIR / BINARY_PROGRESSIVE_K5_RUN / "models"

# ─── 5-Class Ensemble (progressive_K5) ───────────────────────────────────────
# Source: improved_5class_ensemble.ipynb  (run: improved_5class_20260209_172821)
# Strategy: progressive_K5  (same strategy applied to 5-class task)
# ONNX exported in section 8a of that notebook.
FIVECLASS_PROGRESSIVE_K5_RUN = "improved_5class/improved_5class_20260209_172821"
FIVECLASS_PROGRESSIVE_K5_PTH_DIR = RESULTS_DIR / FIVECLASS_PROGRESSIVE_K5_RUN / "models"
FIVECLASS_PROGRESSIVE_K5_ONNX_DIR = RESULTS_DIR / FIVECLASS_PROGRESSIVE_K5_RUN / "onnx"

# ─── SSL Backbone Full Fine-Tuned Ensembles (patient-wise) ───────────────────
# Source: ssl_multitask_ensembles_patientwise.ipynb
# Single run contains binary + 5-class + 3-class ONNX in one onnx/ dir.
# Binary: binary_ssl_fullft_model_1..3.onnx.  5-class: class5_ssl_fullft_model_1..3.onnx.
SSL_MULTITASK_ENSEMBLES_RUN = "ssl_multitask_ensembles/ssl_multitask_ensembles_20260303_120722"
SSL_MULTITASK_ENSEMBLES_ONNX_DIR = RESULTS_DIR / SSL_MULTITASK_ENSEMBLES_RUN / "onnx"
SSL_MULTITASK_ENSEMBLES_PTH_DIR = RESULTS_DIR / SSL_MULTITASK_ENSEMBLES_RUN / "models"
SSL_MULTITASK_BINARY_ONNX_NAMES = [
    "binary_ssl_fullft_model_1.onnx",
    "binary_ssl_fullft_model_2.onnx",
    "binary_ssl_fullft_model_3.onnx",
]
SSL_MULTITASK_FIVECLASS_ONNX_NAMES = [
    "class5_ssl_fullft_model_1.onnx",
    "class5_ssl_fullft_model_2.onnx",
    "class5_ssl_fullft_model_3.onnx",
]

# ─── Superseded production (archived, not in app) ────────────────────────────
# Source: improved_binary_training.ipynb — image-wise full fine-tune (inflated metrics).
BINARY_LEGACY_FULL_FINETUNE_RUN = "improved_binary_ensemble/improved_run_20260205_150642"
BINARY_LEGACY_FULL_FINETUNE_ONNX_DIR = RESULTS_DIR / BINARY_LEGACY_FULL_FINETUNE_RUN / "onnx"

# ─── Current Production Models (deployed in mobile app) ──────────────────────
# Source notebook: ssl_multitask_ensembles_patientwise.ipynb
# Single run trains binary + 5-class + 3-class; app uses binary + 5-class only.
# Git: binary ONNX since 0e82dfc; 5-class ONNX since 1573cf4:24a10927db89afd66be9e4418560243
BINARY_PRODUCTION_RUN = SSL_MULTITASK_ENSEMBLES_RUN
BINARY_PRODUCTION_ONNX_DIR = SSL_MULTITASK_ENSEMBLES_ONNX_DIR
BINARY_PRODUCTION_PTH_DIR = SSL_MULTITASK_ENSEMBLES_PTH_DIR / "binary_ssl_fullft"
BINARY_PRODUCTION_ONNX_NAMES = SSL_MULTITASK_BINARY_ONNX_NAMES
# Filenames in repo assets/ (historical spelling: mode not model)
BINARY_APP_ASSET_ONNX_NAMES = [
    "binary_ensemble_mode_1.onnx",
    "binary_ensemble_mode_2.onnx",
    "binary_ensemble_mode_3.onnx",
]

FIVECLASS_PRODUCTION_RUN = SSL_MULTITASK_ENSEMBLES_RUN
FIVECLASS_PRODUCTION_SOURCE_ONNX_DIR = SSL_MULTITASK_ENSEMBLES_ONNX_DIR
FIVECLASS_PRODUCTION_SOURCE_ONNX_NAMES = SSL_MULTITASK_FIVECLASS_ONNX_NAMES
FIVECLASS_PRODUCTION_PTH_DIR = SSL_MULTITASK_ENSEMBLES_PTH_DIR / "class5_ssl_fullft"
# Deployed copies live in app assets/ under standard ensemble_model_* names
FIVECLASS_PRODUCTION_ONNX_DIR = NOTEBOOK_DIR.parent.parent.parent / "assets"
FIVECLASS_APP_ASSET_ONNX_NAMES = [
    "ensemble_model_1.onnx",
    "ensemble_model_2.onnx",
    "ensemble_model_3.onnx",
]

# ─── Production decision (Phase 1 lock) ──────────────────────────────────────
# After run_full_evaluation.py and generate_decision_summary.py, decision.json
# and decision.md live in results/<run_id>/eval_report/.
# Canonical decision from phase0_test1 (or latest full eval run):
DEFAULT_EVAL_RUN_ID = "phase0_test1"
PRODUCTION_DECISION_DIR = RESULTS_DIR / DEFAULT_EVAL_RUN_ID / "eval_report"
PRODUCTION_DECISION_JSON = PRODUCTION_DECISION_DIR / "decision.json"
PRODUCTION_DECISION_MD = PRODUCTION_DECISION_DIR / "decision.md"

# ─── Ensemble Configuration ──────────────────────────────────────────────────
ENSEMBLE_WEIGHTS = [0.30, 0.40, 0.30]
ONNX_MODEL_NAMES = [
    "ensemble_model_1.onnx",
    "ensemble_model_2.onnx",
    "ensemble_model_3.onnx",
]

# 5-class class names (order must match training label indices)
FIVECLASS_CLASS_NAMES = ["Benign", "Healthy", "OCA", "OPMD", "Unknown"]
# 5-class indices that map to "cancer" in binary view
CANCER_CLASS_INDICES = {2, 3}  # OCA, OPMD

# ─── ImageNet preprocessing ──────────────────────────────────────────────────
IMAGE_SIZE = (224, 224)
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]


# ─── Helper utilities ─────────────────────────────────────────────────────────

def get_onnx_paths(onnx_dir: Path, names: list[str] | None = None) -> list[Path]:
    """Return list of ONNX model paths from a directory, raising if any missing.
    If names is None, uses ONNX_MODEL_NAMES (progressive_K5 / production naming)."""
    onnx_dir = Path(onnx_dir)
    names = names or ONNX_MODEL_NAMES
    paths = [onnx_dir / name for name in names]
    missing = [p for p in paths if not p.exists()]
    if missing:
        raise FileNotFoundError(
            f"Missing ONNX model(s) in {onnx_dir}:\n"
            + "\n".join(f"  - {p.name}" for p in missing)
        )
    return paths


def get_ssl_multitask_binary_onnx_paths() -> list[Path]:
    """Return paths to the 3 binary SSL full fine-tuned ONNX models."""
    return get_onnx_paths(SSL_MULTITASK_ENSEMBLES_ONNX_DIR, SSL_MULTITASK_BINARY_ONNX_NAMES)


def get_ssl_multitask_fiveclass_onnx_paths() -> list[Path]:
    """Return paths to the 3 5-class SSL full fine-tuned ONNX models."""
    return get_onnx_paths(SSL_MULTITASK_ENSEMBLES_ONNX_DIR, SSL_MULTITASK_FIVECLASS_ONNX_NAMES)


def get_binary_production_onnx_paths(*, app_assets: bool = False) -> list[Path]:
    """Production binary ONNX: training run dir by default, or repo assets/ if app_assets=True."""
    if app_assets:
        assets_dir = NOTEBOOK_DIR.parent.parent.parent / "assets"
        return get_onnx_paths(assets_dir, BINARY_APP_ASSET_ONNX_NAMES)
    return get_onnx_paths(BINARY_PRODUCTION_ONNX_DIR, BINARY_PRODUCTION_ONNX_NAMES)


def get_fiveclass_production_onnx_paths(*, app_assets: bool = True) -> list[Path]:
    """Production 5-class ONNX: repo assets/ by default, or training run dir if app_assets=False."""
    if app_assets:
        return get_onnx_paths(FIVECLASS_PRODUCTION_ONNX_DIR, FIVECLASS_APP_ASSET_ONNX_NAMES)
    return get_onnx_paths(
        FIVECLASS_PRODUCTION_SOURCE_ONNX_DIR, FIVECLASS_PRODUCTION_SOURCE_ONNX_NAMES
    )


def summary() -> str:
    """Print a summary of all registered model paths and their status."""
    lines = [
        "Model Registry Summary",
        "=" * 60,
        f"Production run: {BINARY_PRODUCTION_RUN}",
        "Source notebook: ssl_multitask_ensembles_patientwise.ipynb",
        "",
    ]

    entries = [
        ("Binary production — training ONNX", BINARY_PRODUCTION_ONNX_DIR),
        ("Binary production — app assets", NOTEBOOK_DIR.parent.parent.parent / "assets"),
        ("5-class production — training ONNX", FIVECLASS_PRODUCTION_SOURCE_ONNX_DIR),
        ("5-class production — app assets", FIVECLASS_PRODUCTION_ONNX_DIR),
        ("Binary legacy full-finetune (archived)", BINARY_LEGACY_FULL_FINETUNE_ONNX_DIR),
        ("Binary progressive_K5 (ONNX)", BINARY_PROGRESSIVE_K5_ONNX_DIR),
        ("5-class progressive_K5 (ONNX)", FIVECLASS_PROGRESSIVE_K5_ONNX_DIR),
        ("SSL multitask ensembles (PTH)", SSL_MULTITASK_ENSEMBLES_PTH_DIR),
    ]

    for label, path in entries:
        exists = path.exists()
        onnx_count = len(list(path.glob("*.onnx"))) if exists else 0
        pth_count = len(list(path.glob("*.pth"))) if exists else 0
        status = "OK" if exists else "MISSING"
        detail = ""
        if onnx_count:
            detail += f" ({onnx_count} ONNX)"
        if pth_count:
            detail += f" ({pth_count} PTH)"
        lines.append(f"  [{status}] {label}{detail}")
        lines.append(f"         {path}")

    return "\n".join(lines)


if __name__ == "__main__":
    print(summary())
