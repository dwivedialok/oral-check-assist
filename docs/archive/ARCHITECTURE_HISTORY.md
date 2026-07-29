# Model Architecture History

**Purpose:** Layer-level record of architecture and training-strategy evolution for oral cavity classification. What we tried, what we selected, and why.

**Related:** See [MODEL_DEVELOPMENT_AND_USAGE.md](MODEL_DEVELOPMENT_AND_USAGE.md) for datasets, performance, and app integration.

---

## 1. MobileNetV3Large Structure (Layer Types)

The backbone is `backbone.features` — a **Sequential of 17 blocks** (0–16):

| Block | Layer Type | Params | Contains |
|-------|------------|--------|----------|
| 0 | Conv2dNormActivation | 464 | Conv2d → **BatchNorm2d** → ReLU |
| 1–15 | InvertedResidual | varies | Expansion Conv+BN → Depthwise Conv+BN → (optional SE) → Projection Conv+**BN** |
| 16 | Conv2dNormActivation | 155,520 | Conv2d → **BatchNorm2d** → ReLU |

**Key layer types:**
- **Conv2d** — convolution (learns filters)
- **BatchNorm2d** — normalizes activations; has learnable scale (γ) and shift (β) + running mean/variance
- **ReLU / HardSwish** — activation (no learnable params)
- **InvertedResidual** — mobile block: expansion → depthwise → projection; each step has Conv+BN
- **SqueezeExcitation (SE)** — channel attention (inside some InvertedResidual blocks)

**After backbone:** a custom **classifier head** (not part of backbone):
- AdaptiveAvgPool2d → Flatten → Dropout → Linear(960→256) → ReLU → Linear(256→num_classes)

**Total:** ~3.2M params (backbone ~2.97M, head ~247K).

---

## 2. Initial Production Models

**Data clarification:** T5, TB, TC, TM are **frozen test sets** (never used for training). Training uses train/val splits from the merged datasets (5-class: `oral_cavity_5class_dataset` train+val; binary: merged train+val from all 3 sources, excluding the 15% holdouts that became TB/TC).

### 5-Class (`production_oral_cavity_classifier.ipynb`)

| Aspect | Choice |
|--------|--------|
| **Task** | 5 classes: Benign, Healthy, OCA, OPMD, Unknown |
| **Strategy** | Full fine-tune (all parameters trainable from epoch 1) |
| **What was trained** | All backbone blocks (0–16) + head — Conv, BN, Linear all updated |
| **Training data** | 5-class dataset train/val (not T5; T5 is test) |
| **Ensemble** | 3 models, dropout [0.3, 0.1, 0.2], weights [0.30, 0.40, 0.30] |
| **Head** | Model 3 has 512-dim intermediate; models 1–2 use 256-dim |

### Binary (`improved_binary_training.ipynb`)

| Aspect | Choice |
|--------|--------|
| **Task** | 2 classes: non-cancer, cancer |
| **Strategy** | Full fine-tune |
| **What was trained** | All backbone blocks (0–16) + head |
| **Training data** | Merged binary train/val (5-class mapped + binary dataset + small binary; not TM) |
| **Ensemble** | 3 models, same dropout/weights pattern as 5-class |

**Note:** These models are still deployed in the app (`assets/ensemble_model_*.onnx` for 5-class; binary from `improved_binary_ensemble`).

---

## 3. Freeze Strategy Comparison (`freeze_strategy_comparison.ipynb`)

**Goal:** Compare backbone freeze strategies for binary classification. Evaluated on frozen test sets (T5, TB, TC, TM). **Training data:** merged binary train/val (same as initial production).

### Strategies Tested (Layer-Level)

| Strategy | Backbone blocks 0–16 | Head | What actually trains |
|----------|----------------------|------|----------------------|
| **head_only** | All frozen (Conv+BN no gradient) | ✓ | Head only (~247K params) |
| **progressive_K3** | Blocks 0–13 frozen; **14, 15, 16** unfrozen | ✓ | Head + last 3 blocks (~1.75M params) |
| **progressive_K5** | Blocks 0–11 frozen; **12, 13, 14, 15, 16** unfrozen | ✓ | Head + last 5 blocks (~2.57M params) |
| **full_finetune** | All unfrozen | ✓ | Everything (~3.2M params) |

**Progressive schedule:** (1) Warm-up 5 epochs: backbone frozen, head trains. (2) Main training: unfreeze last K blocks, train head @ lr_head, backbone @ lr_backbone (10× lower). All layers in unfrozen blocks (Conv, BN, etc.) receive gradients.

### Result (Binary Model)

| Strategy | TM AUC | TM Sens@90Spec | Brier | ECE |
|----------|--------|----------------|-------|-----|
| head_only | 0.8952 | 70.1% | 0.1353 | 0.0561 |
| progressive_K3 | 0.9149 | 73.6% | 0.1263 | 0.0599 |
| **progressive_K5** | **0.9291** | **78.9%** | **0.1099** | **0.0476** |
| full_finetune | 0.9235 | 82.6% | 0.1094 | 0.0578 |

**Selected (Binary):** **progressive_K5** — best TM AUC, best source stability, best min(T5,TB) AUC with TM sensitivity ≥ 80%.

**Run:** `freeze_comparison_20260208_121618` → `model_registry.BINARY_PROGRESSIVE_K5_ONNX_DIR`

---

## 4. 5-Class Progressive_K5 (`improved_5class_ensemble.ipynb`)

**Goal:** Apply the same progressive_K5 strategy (winner for binary) to 5-class.

| Aspect | Choice |
|--------|--------|
| **Strategy** | progressive_K5 (head warm-up 5 ep → unfreeze last 5 blocks) |
| **What was trained** | Same as binary progressive_K5: blocks 12–16 + head |
| **Training data** | 5-class dataset train/val (not T5; T5 is test) |
| **Output** | 5 classes |

**Run:** `improved_5class_20260209_172821` → `model_registry.FIVECLASS_PROGRESSIVE_K5_ONNX_DIR`

---

## 5. Phase 4 Experiments (train_experiment.py)

**Goal:** Test training tweaks on binary progressive_K5. Same architecture and strategy; only training behavior changes. Evaluated on TM (and other splits).

| Experiment | Status | Change | What trains / stays same | Run ID | Notes |
|------------|--------|--------|---------------------------|--------|-------|
| **1. AdamW** | ✅ **Completed** | AdamW optimizer, weight_decay=0.01 | Same layers as baseline; only optimizer differs | `exp_adamw` | Checkpoint saved Feb 10 21:44 (12 MB) |
| **2. Freeze BN** | ✅ **Completed** | BN layers forced to `eval()` during training | **Conv, Linear** still train; **BatchNorm2d** does not update (running mean/var, γ, β frozen) | `exp_freeze_bn` | Checkpoint saved Feb 11 22:10 (12 MB) |
| **3. Focal loss** | 🔄 **In Progress** | Focal loss instead of cross-entropy | Same layers; only loss function differs | `exp_focal` | TB logs active (79 files, latest Feb 12 11:14); checkpoint pending |
| **4. Temperature scaling** | ⏳ **Pending** | Post-hoc calibration (learned temp on val) | Same model; calibration applied after inference | `exp_temp` | Not started yet |

**Status as of:** February 12, 2026 (11:14 AM)

**TensorBoard Logging:** Experiments 3 and 4 will log to TensorBoard (added Feb 12). Logs stored in `results/train_experiment/<run_id>/tb_logs/`.

### Experiment 2 (Freeze BN) — Layer Detail

| Layer type | Normal (freeze_bn=False) | Freeze BN (freeze_bn=True) |
|------------|---------------------------|----------------------------|
| **Conv2d** | Trains (gradients flow) | Trains |
| **BatchNorm2d** | Trains (updates running mean/var, γ, β) | **Frozen** — uses fixed stats, no gradient |
| **Linear** | Trains | Trains |

**Implementation:** During each training step, all `BatchNorm2d` and `BatchNorm1d` modules are switched to `eval()` mode so they use stored statistics and do not update. Architecture is identical; only BN behavior changes.

**What stays same:** Model structure (same 17 blocks + head), progressive_K5 schedule (warm-up + unfreeze last 5 blocks), training data, loss, optimizer (Adam). Only BN layers stop updating.

---

## Summary: Current Canonical Models

| Model | Source | Strategy |
|-------|--------|----------|
| **Binary** | `freeze_strategy_comparison.ipynb` | progressive_K5 |
| **5-Class** | `improved_5class_ensemble.ipynb` | progressive_K5 |

**App deployment:** Still uses older full fine-tune models; canonical progressive_K5 models are evaluated and ready for deployment.

---

## What Didn’t Work (or Didn’t Win)

| Approach | Outcome |
|----------|---------|
| **head_only** | Lower TM AUC (0.8952) vs progressive_K5; useful as diagnostic baseline |
| **progressive_K3** | Worse than K5; fewer unfrozen blocks underperformed |
| **full_finetune** | Higher val AUC but worse TM generalization; progressive_K5 won on frozen sets |

---

## Appendix: Common Clarifications

| Term | Meaning |
|------|---------|
| **T5, TB, TC, TM** | Frozen **test** sets — never used for training. Used only for evaluation. |
| **Blocks vs layers** | "Last 5 blocks" = last 5 children of `backbone.features` (blocks 12–16). Each block itself contains multiple Conv+BN layers. |
| **Progressive_K5** | Strategy: train head first (5 ep), then unfreeze blocks 12–16 and train them + head. |
| **Freeze BN** | BN layers stay in eval mode during training; Conv/Linear still train. No architecture change. |

---

---

## Phase 4 Experiment Results (Pending Evaluation)

After all 4 experiments complete, evaluate each model on frozen test sets (T5, TB, TC, TM) and compare:
- TM AUROC
- TM Sens@90Spec
- ECE (Expected Calibration Error)
- Brier Score

Results will be documented here once evaluation is complete.

---

*Last updated: February 12, 2026*
