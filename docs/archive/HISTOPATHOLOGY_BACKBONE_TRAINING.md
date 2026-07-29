# Histopathology Backbone Pretraining — Data, Design, and Results

This document records the **domain-specific pretraining** of the MobileNetV3-Large backbone on histopathology images, the rationale for the approach, and the results. For strategic context (why use histology at all, other strategies), see [TRANSFER_LEARNING_WITH_HISTOPATH_IMAGES.md](TRANSFER_LEARNING_WITH_HISTOPATH_IMAGES.md).

---

## 1. Data source

| Item | Detail |
|------|--------|
| **Path** | `~/dev/oral-images-dataset/histopathology-images` |
| **Structure** | One folder per class; images may sit in subfolders (e.g. `mdoscc/o-3-00-30/*.png`). |
| **Classes (5)** | `mdoscc`, `normal`, `osmf`, `pdoscc`, `wdoscc` (sorted for stable label indices). |
| **Approx. counts** | mdoscc ~2,699, normal ~1,045, osmf ~2,095, pdoscc ~1,599, wdoscc ~2,790 (~10,228 total). |
| **Formats** | `.jpg`, `.jpeg`, `.png` (case-insensitive). |
| **Split** | 85% train / 15% val, stratified by class, `seed=42`. |

---

## 2. High-level design

We follow **Strategy A (Progressive Domain Transfer)** from the histopath guide:

1. **Pretrain** — Train MobileNetV3-Large + a 5-class head on the histopathology dataset. The backbone learns “medical” texture and tissue structure.
2. **Save backbone only** — Discard the 5-class head; keep `backbone_state_dict.pth` (features only) plus `class_mapping.json` for reference.
3. **Transfer** — For the app’s binary (or 5-class oral) task, build a new model: load the histology-pretrained backbone, attach a **new** head (960 → 256 → 2 or 960 → 256 → 5), then fine-tune on oral photos using head-only, progressive_K5, or full_finetune.

So: **histology gives the backbone “medical eyes”; the head is always task-specific and trained (or fine-tuned) on the target oral dataset.**

---

## 3. Architecture and reasoning

| Choice | Reason |
|--------|--------|
| **Backbone** | MobileNetV3-Large — same as production; ImageNet-initialized, then trained on histology so we can swap in one checkpoint for transfer. |
| **Input** | 224×224, ImageNet normalization (mean/std). |
| **Histology head** | 960 → 256 (ReLU) → 5 logits, with dropout 0.2. Matches the existing binary head width (256) for consistency when we swap heads. |
| **Training** | Cross-entropy, class-balanced weights, label smoothing 0.05; Adam 1e-4, cosine LR; early stopping on val AUC (patience 12). |
| **Augmentation** | Resize, HorizontalFlip, VerticalFlip, RandomRotate90, ShiftScaleRotate, RandomBrightnessContrast, HueSaturationValue, Normalize (Albumentations when available). |

The 5-class head is used only for pretraining; we do **not** deploy it. The exported artifact for downstream work is the backbone state dict.

---

## 4. Results (histopathology pretraining)

### Run: `run_20260214_080629`

| Metric | Value |
|--------|--------|
| **Early stop** | Epoch 28 |
| **Best val accuracy** | **95.44%** |
| **Best val AUC** (weighted, multiclass OVR) | **0.9962** |
| **Config** | `results/histology_pretrain/run_20260214_080629/config.json` (batch_size=32, lr=1e-4, dropout=0.2, val_split=0.15, seed=42). |

### Artifacts

| Artifact | Location |
|----------|----------|
| **Run folder** | `ml/training/notebooks/results/histology_pretrain/run_20260214_080629/` |
| **Full model** | `run_20260214_080629/models/full_model.pth` |
| **Backbone only** | `run_20260214_080629/backbone_state_dict.pth` |
| **Class mapping** | `run_20260214_080629/class_mapping.json` |
| **Latest for transfer** | `ml/training/notebooks/results/histology_pretrain/backbone_state_dict.pth` (and `class_mapping.json`) — copied from the latest run so the transfer notebook can load without editing paths. |

### Notebooks

- **Pretrain:** `ml/training/notebooks/histology_pretrain.ipynb`
- **Transfer (head_only, progressive_K5, full_finetune):** `ml/training/notebooks/histology_transfer_finetune.ipynb`
- **3-model progressive_K5 ensemble (export ONNX, eval T5/TB/TC/TM):** `ml/training/notebooks/histology_progressive_K5_ensemble.ipynb`

---

## 5. Transfer results (oral binary task)

Same data and split as `freeze_strategy_comparison.ipynb` (merged oral train/val, 15% val, seed=42). Reference: ImageNet-backbone head_only from that run had **mean val_auc 0.8723** (3-model ensemble), **best val_acc 78.07%**; on **frozen test set TM**: **TM AUC 0.8952**, **Sens@90Spec 70.1%** (see [MODEL_DEVELOPMENT_AND_USAGE.md](MODEL_DEVELOPMENT_AND_USAGE.md)).

### head_only (histology backbone)

| Metric | Histology transfer (single model) | Freeze comparison (ImageNet, 3-model mean) |
|--------|------------------------------------|--------------------------------------------|
| **Val AUC** | **0.8572** | 0.8723 |
| **Val accuracy** | **76.44%** | 78.07% (best individual) |
| **Early stop** | Epoch 31 | Epochs 40–46 (per model) |
| **TM AUC** | *(not run yet)* | 0.8952 |
| **TM Sens@90Spec** | *(not run yet)* | 70.1% |

**Comparison:** Histology head_only is slightly lower on the **validation set** (val_auc −0.015, val_acc −1.6%) than ImageNet head_only. That is plausible: the histology backbone is tuned to microscope texture, and with only the head trained on oral photos it may not match ImageNet's generic features on this val split. Single-model vs 3-model mean also adds variance. To compare fairly on **frozen test (TM)**, run the same evaluation (e.g. `evaluate_on_frozen_sets.py` or the notebook's eval cells) on the saved histology head_only checkpoint and record TM AUC and Sens@90Spec.

### progressive_K5 (histology backbone)

**Single-model transfer** (from `histology_transfer_finetune.ipynb`):

| Metric | Histology transfer (single model) | Freeze comparison (ImageNet, 3-model mean) |
|--------|------------------------------------|--------------------------------------------|
| **Val AUC** | **0.8886** | 0.8912 |
| **Val accuracy** | **80.30%** | 81.78% (best individual) |
| **Early stop** | Epoch 27 (after 5-ep warmup) | Epochs 24–42 (per model) |

**3-model ensemble** (from `histology_progressive_K5_ensemble.ipynb` — same config as ImageNet: dropout [0.3, 0.1, 0.2], seeds 42/43/44, warmup 5 ep, unfreeze last 5, 50 ep, patience 12):

| Model | Histology backbone | ImageNet backbone |
|-------|--------------------|-------------------|
| Ensemble 1 (dropout=0.3) | val_auc=0.8852 (early stop ep 23) | val_auc=0.8847 (ep 24) |
| Ensemble 2 (dropout=0.1) | val_auc=0.8887 (early stop ep 47) | val_auc=0.8881 (ep 33) |
| Ensemble 3 (dropout=0.2) | *(run completed)* | val_auc=0.9007 (ep 42) |
| **Ensemble mean val AUC** | **~0.8915** | 0.8912 |

**Frozen test sets** (T5, TB, TC, TM — `evaluate_on_frozen_sets.py`, binary_onnx_ensemble):

| Metric | Histology 3-model ensemble | ImageNet progressive_K5 |
|--------|-----------------------------|-------------------------|
| **T5 AUC** | 0.8635 | 0.8830 |
| **TB AUC** | 0.9896 | 0.9836 |
| **TC AUC** | 0.9950 | 0.9983 |
| **TM AUC** | 0.9218 | **0.9291** |
| **TM Sens** | 88.81% | 85.57% |
| **TM Spec** | 76.92% | 83.55% |
| **TM Sens@90Spec** | 76.4% | **78.9%** |
| **TM Brier** | 0.1195 | **0.1099** |
| **TM ECE** | 0.3665 | **0.0476** |

**Summary:** Validation AUC is on par with ImageNet (ensemble mean ~0.8915 vs 0.8912). On frozen sets, histology is slightly lower on TM AUC (−0.0073) and T5 AUC (−0.0195), higher on TB AUC (+0.0060) and TM sensitivity (+3.24%). Calibration is worse (ECE 0.3665 vs 0.0476); consider temperature scaling or other calibration for deployment.

### full_finetune (histology backbone)

| Metric | Histology transfer (single model) | Freeze comparison (ImageNet, 3-model mean) |
|--------|------------------------------------|--------------------------------------------|
| **Val AUC** | **0.8803** | 0.8996 |
| **Val accuracy** | **74.22%** | 81.93% (best individual) |
| **Early stop** | Epoch 15 | Epochs 23–33 (per model) |
| **TM AUC** | *(not run yet)* | 0.9235 |
| **TM Sens@90Spec** | *(not run yet)* | 82.6% |

**Comparison:** Histology full_finetune is lower than ImageNet full_finetune on the validation set (val_auc −0.019, val_acc −7.7%). Progressive_K5 with histology (0.8886) outperformed full_finetune with histology (0.8803) on val AUC, suggesting progressive unfreezing may be a better fit for this backbone. TM evaluation pending.

---

## 6. Next steps and future results

- **Done:** 3-model histology progressive_K5 ensemble trained (`histology_progressive_K5_ensemble.ipynb`), exported to ONNX, and evaluated on T5/TB/TC/TM. Results recorded in section 5.
- **Future:** Consider calibration (e.g. temperature scaling) to improve ECE; additional pretrain or transfer runs can be added as new rows in section 5.

---

*Last updated: February 2025 — pretrain run, single-model transfer (head_only, progressive_K5, full_finetune), and 3-model histology progressive_K5 ensemble frozen-set results recorded.*
