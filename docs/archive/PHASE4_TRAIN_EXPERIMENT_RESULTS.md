# Phase 4 Experiment Results Summary

**Last Updated:** February 12, 2026 — Experiment 4 (Temperature Scaling) added; Phase 4 complete.

---

## Baseline (target to beat)

Phase 4 experiments aimed to match or beat the **baseline progressive_K5** binary ensemble from `freeze_strategy_comparison.ipynb` (run `freeze_comparison_20260208_121618`). Key TM (mixed frozen test set) metrics:

| Metric | Baseline (progressive_K5) |
|--------|---------------------------|
| **TM AUC** | **0.9291** |
| **TM Sens@90Spec** | **78.9%** |
| **Brier Score** | **0.1099** |
| **ECE** | **0.0476** |

Full baseline comparison: see `MODEL_DEVELOPMENT_AND_USAGE.md` → "Freeze Strategy Comparison Results".

---

## All experiments at a glance (TM – frozen test set)

Single reference table for baseline and all Phase 4 experiments:

| Metric | Baseline | Exp 1 (AdamW) | Exp 2 (Freeze BN) | Exp 3 (Focal) | Exp 4 (Temp) |
|--------|----------|---------------|-------------------|---------------|---------------|
| **TM AUC** | **0.9291** | 0.8966 | 0.9160 | 0.8964 | 0.8971 |
| **TM Accuracy** | — | 81.51% | 82.80% | 81.26% | 80.23% |
| **TM Sens@90Spec** | **78.9%** | 72.6% | 78.1% | 73.6% | 73.13% |
| **Brier Score** | **0.1099** | 0.1409 | 0.1256 | 0.1435 | 0.1388 |
| **ECE** | **0.0476** | 0.3612 | 0.3642 | 0.3924 | 0.3505 |

**Outcome:** No experiment beat baseline. Best among experiments: **Freeze BN** (TM AUC 0.9160, Sens@90Spec 78.1%); **Temp** had best calibration (ECE 0.3505) but still far from baseline.

---

## Experiment 1: AdamW Optimizer ✅ **Completed & Evaluated**

### Configuration
- **Run ID:** `exp_adamw_ensemble` (3-model ensemble)
- **Strategy:** `progressive_K5` (warmup 5 epochs, then unfreeze last 5 blocks)
- **Optimizer:** `adamw` with `weight_decay=0.01`
- **Loss:** Cross-entropy with `label_smoothing=0.05`
- **Freeze BN:** `false` (normal BN training)
- **Learning Rates:** `lr_head=0.001`, `lr_backbone=0.0001`
- **Batch Size:** 32
- **Epochs:** 50 (max), with early stopping patience=12
- **Class Weight:** Cancer multiplier=1.5
- **Dropout Rates:** [0.3, 0.1, 0.2] for ensemble models
- **Ensemble Weights:** [0.30, 0.40, 0.30]

### Training Details
- **Ensemble Models:** 3 models trained with different dropout rates and seeds
- **Individual Validation AUCs:** [0.8720, 0.8805, 0.8773]
- **Mean Validation AUC:** 0.8766
- **ONNX Models:** `results/train_experiment/exp_adamw_ensemble/onnx/ensemble_model_{1,2,3}.onnx`
- **Status:** Training completed successfully, ensemble exported to ONNX

### Frozen Test Set Evaluation Results

**TM (Mixed Test Set - Primary Metric):**
- **TM AUC:** 0.8966 ⚠️ **Below baseline** (baseline: 0.9291, **-0.0325**)
- **TM Accuracy:** 81.51%
- **TM Sensitivity:** 88.06%
- **TM Specificity:** 74.54%
- **TM Sens@90Spec:** 72.6% ⚠️ **Below baseline** (baseline: 78.9%, **-6.3%**)
- **Brier Score:** 0.1409 ⚠️ **Worse than baseline** (baseline: 0.1099, **+0.0310**)
- **ECE:** 0.3612 ⚠️ **Much worse than baseline** (baseline: 0.0476, **+0.3136**)

**Other Test Sets:**
- **T5 (5-class test):** AUC 0.8369, Acc 76.24%, Sens 86.53%, Spec 65.69%
- **TB (binary test):** AUC 0.9678, Acc 90.24%, Sens 88.72%, Spec 92.04%
- **TC (small binary):** AUC 0.9817, Acc 89.80%, Sens 100.00%, Spec 80.00%

**Per-Source Performance (TM):**
- **Source A (5-class):** Acc 76.24%, Sens 86.53%, Spec 65.69%
- **Source B (binary):** Acc 90.24%, Sens 88.72%, Spec 92.04%

**Evaluation File:** `results/train_experiment/exp_adamw_ensemble/frozen_eval.json`

---

## Experiment 2: Freeze BatchNorm ✅ **Completed & Evaluated**

### Configuration
- **Run ID:** `exp_freeze_bn_ensemble` (3-model ensemble)
- **Strategy:** `progressive_K5` (warmup 5 epochs, then unfreeze last 5 blocks)
- **Optimizer:** `adam` (not AdamW) with `weight_decay=0.0`
- **Loss:** Cross-entropy with `label_smoothing=0.05`
- **Freeze BN:** `true` ⭐ **Key difference** — BN layers stay in eval mode during training
- **Learning Rates:** `lr_head=0.001`, `lr_backbone=0.0001`
- **Batch Size:** 32
- **Epochs:** 50 (max), with early stopping patience=12
- **Class Weight:** Cancer multiplier=1.5
- **Dropout Rates:** [0.3, 0.1, 0.2] for ensemble models
- **Ensemble Weights:** [0.30, 0.40, 0.30]

### Training Details
- **Ensemble Models:** 3 models trained with different dropout rates and seeds
- **Individual Validation AUCs:** [0.8806, 0.8910, 0.8929]
- **Mean Validation AUC:** 0.8881
- **ONNX Models:** `results/train_experiment/exp_freeze_bn_ensemble/onnx/ensemble_model_{1,2,3}.onnx`
- **Status:** Training completed successfully, ensemble exported to ONNX

### What "Freeze BN" Means
- **Conv2d layers:** Still train normally (receive gradients)
- **BatchNorm2d layers:** Forced to `eval()` mode during training
  - Uses stored running mean/variance (no updates)
  - Scale (γ) and shift (β) parameters frozen (no gradients)
  - Architecture unchanged; only BN behavior differs from baseline

### Frozen Test Set Evaluation Results

**TM (Mixed Test Set - Primary Metric):**
- **TM AUC:** 0.9160 ⚠️ **Below baseline** (baseline: 0.9291, **-0.0131**)
- **TM Accuracy:** 82.80%
- **TM Sensitivity:** 90.80%
- **TM Specificity:** 74.27%
- **TM Sens@90Spec:** 78.1% ✅ **Matches baseline** (baseline: 78.9%, **-0.8%**)
- **Brier Score:** 0.1256 ⚠️ **Worse than baseline** (baseline: 0.1099, **+0.0157**)
- **ECE:** 0.3642 ⚠️ **Much worse than baseline** (baseline: 0.0476, **+0.3166**)

**Other Test Sets:**
- **T5 (5-class test):** AUC 0.8626, Acc 77.07%, Sens 88.16%, Spec 65.69%
- **TB (binary test):** AUC 0.9763, Acc 93.90%, Sens 93.98%, Spec 93.81%
- **TC (small binary):** AUC 0.9850, Acc 83.67%, Sens 100.00%, Spec 68.00%

**Per-Source Performance (TM):**
- **Source A (5-class):** Acc 77.07%, Sens 88.16%, Spec 65.69%
- **Source B (binary):** Acc 93.90%, Sens 93.98%, Spec 93.81%

**Evaluation File:** `results/train_experiment/exp_freeze_bn_ensemble/frozen_eval.json`

---

## Experiment 3: Focal Loss ✅ **Completed & Evaluated**

### Configuration
- **Run ID:** `exp_focal_ensemble` (3-model ensemble)
- **Strategy:** `progressive_K5` (warmup 5 epochs, then unfreeze last 5 blocks)
- **Optimizer:** Adam (weight_decay=0.0)
- **Loss:** **Focal loss** ⭐ (focal_gamma=2.0) — instead of cross-entropy
- **Freeze BN:** false
- **Label Smoothing:** 0.0 (focal config)
- **Dropout Rates:** [0.3, 0.1, 0.2] for ensemble models
- **Ensemble Weights:** [0.30, 0.40, 0.30]

### Training Details
- **Ensemble Models:** 3 models trained with different dropout rates and seeds
- **Individual Validation AUCs:** [0.8861, 0.8871, 0.8844]
- **Mean Validation AUC:** 0.8859
- **ONNX Models:** `results/train_experiment/exp_focal_ensemble/onnx/ensemble_model_{1,2,3}.onnx`
- **TensorBoard Logs:** ✅ `results/train_experiment/exp_focal_ensemble/ensemble_*/tb_logs/`
- **Status:** Training completed successfully, ensemble exported to ONNX and evaluated

### Frozen Test Set Evaluation Results

**TM (Mixed Test Set - Primary Metric):**
- **TM AUC:** 0.8964 ⚠️ **Below baseline** (baseline: 0.9291, **-0.0327**)
- **TM Accuracy:** 81.26%
- **TM Sensitivity:** 87.56%
- **TM Specificity:** 74.54%
- **TM Sens@90Spec:** 73.6% ⚠️ **Below baseline** (baseline: 78.9%, **-5.3%**)
- **Brier Score:** 0.1435 ⚠️ **Worse than baseline** (baseline: 0.1099, **+0.0336**)
- **ECE:** 0.3924 ⚠️ **Worst calibration** of all experiments (baseline: 0.0476, **+0.3448**)

**Other Test Sets:**
- **T5 (5-class test):** AUC 0.8364, Acc 75.00%, Sens 85.31%, Spec 64.44%
- **TB (binary test):** AUC 0.9769, Acc 92.28%, Sens 89.47%, Spec 95.58%
- **TC (small binary):** AUC 0.9850, Acc 87.76%, Sens 100.00%, Spec 76.00%

**Evaluation File:** `results/train_experiment/exp_focal_ensemble/frozen_eval.json`

---

## Experiment 4: Temperature Scaling ✅ **Completed & Evaluated**

### Configuration
- **Run ID:** `exp_temp_ensemble` (3-model ensemble)
- **Strategy:** `progressive_K5` (warmup 5 epochs, then unfreeze last 5 blocks)
- **Optimizer:** Adam (weight_decay=0.0)
- **Loss:** Cross-entropy with `label_smoothing=0.05`
- **Temperature Scaling:** `true` ⭐ **Key difference** — post-training calibration applied on validation logits
- **Freeze BN:** false
- **Dropout Rates:** [0.3, 0.1, 0.2] for ensemble models
- **Ensemble Weights:** [0.30, 0.40, 0.30]

### Training Details
- **Ensemble Models:** 3 models trained with different dropout rates and seeds
- **Individual Validation AUCs:** [0.8767, 0.8857, 0.8860]
- **Mean Validation AUC:** 0.8828
- **ONNX Models:** `results/train_experiment/exp_temp_ensemble/onnx/ensemble_model_{1,2,3}.onnx`
- **Status:** Training completed successfully, ensemble exported to ONNX and evaluated

### Frozen Test Set Evaluation Results

**TM (Mixed Test Set - Primary Metric):**
- **TM AUC:** 0.8971 ⚠️ **Below baseline** (baseline: 0.9291, **-0.0320**)
- **TM Accuracy:** 80.23%
- **TM Sensitivity:** 87.06%
- **TM Specificity:** 72.94%
- **TM Sens@90Spec:** 73.13% ⚠️ **Below baseline** (baseline: 78.9%, **-5.8%**)
- **Brier Score:** 0.1388 ⚠️ **Worse than baseline** (baseline: 0.1099, **+0.0289**)
- **ECE:** 0.3505 ⚠️ **Best calibration among the four experiments** but still far from baseline (baseline: 0.0476, **+0.3029**)

**Other Test Sets:**
- **T5 (5-class test):** AUC 0.8328, Acc 74.17%, Sens 85.31%, Spec 62.76%
- **TB (binary test):** AUC 0.9720, Acc 90.65%, Sens 87.97%, Spec 93.81%
- **TC (small binary):** AUC 0.9917, Acc 87.76%, Sens 100.00%, Spec 76.00%

**Per-Source Performance (TM):**
- **Source A (5-class):** Acc 74.17%, Sens 85.31%, Spec 62.76%
- **Source B (binary):** Acc 90.65%, Sens 87.97%, Spec 93.81%

**Evaluation File:** `results/train_experiment/exp_temp_ensemble/frozen_eval.json`

---

## Comparison Summary

### Training Configuration

| Aspect | Experiment 1 (AdamW) | Experiment 2 (Freeze BN) | Experiment 3 (Focal) | Experiment 4 (Temp) |
|--------|----------------------|--------------------------|----------------------|---------------------|
| **Run ID** | `exp_adamw_ensemble` | `exp_freeze_bn_ensemble` | `exp_focal_ensemble` | `exp_temp_ensemble` |
| **Optimizer** | AdamW (weight_decay=0.01) | Adam (weight_decay=0.0) | Adam (weight_decay=0.0) | Adam (weight_decay=0.0) |
| **Loss** | Cross-entropy | Cross-entropy | **Focal loss** | Cross-entropy |
| **BN Training** | Normal | Frozen (eval mode) | Normal | Normal |
| **Ensemble** | ✅ 3 models | ✅ 3 models | ✅ 3 models | ✅ 3 models |
| **Status** | ✅ Completed & Evaluated | ✅ Completed & Evaluated | ✅ Completed & Evaluated | ✅ Completed & Evaluated |
| **Mean Val AUC** | 0.8766 | 0.8881 | 0.8859 | 0.8828 |
| **TB Logs** | ❌ No | ❌ No | ✅ Yes | N/A |

### Frozen Test Set Performance (TM - Primary Comparison)

*Quick reference: see [All experiments at a glance](#all-experiments-at-a-glance-tm--frozen-test-set) at the top.*

| Metric | Baseline (progressive_K5) | Exp 1 (AdamW) | Exp 2 (Freeze BN) | Exp 3 (Focal) | Exp 4 (Temp) |
|--------|---------------------------|---------------|-------------------|---------------|--------------|
| **TM AUC** | **0.9291** | 0.8966 ⚠️ (-0.0325) | 0.9160 ⚠️ (-0.0131) | 0.8964 ⚠️ (-0.0327) | 0.8971 ⚠️ (-0.0320) |
| **TM Accuracy** | (not reported) | 81.51% | 82.80% | 81.26% | 80.23% |
| **TM Sens@90Spec** | **78.9%** | 72.6% ⚠️ (-6.3%) | 78.1% ✅ (-0.8%) | 73.6% ⚠️ (-5.3%) | 73.13% ⚠️ (-5.8%) |
| **Brier Score** | **0.1099** | 0.1409 ⚠️ (+0.0310) | 0.1256 ⚠️ (+0.0157) | 0.1435 ⚠️ (+0.0336) | 0.1388 ⚠️ (+0.0289) |
| **ECE** | **0.0476** | 0.3612 ⚠️ (+0.3136) | 0.3642 ⚠️ (+0.3166) | 0.3924 ⚠️ (+0.3448) | 0.3505 ⚠️ (+0.3029) |

### Key Findings

**Experiment 1 (AdamW):**
- ❌ **Worse than baseline** on all key metrics
- TM AUC **-0.0325** below baseline
- Sens@90Spec **-6.3%** below baseline
- **Calibration is poor** (ECE 0.3612 vs baseline 0.0476) — model is overconfident
- **Conclusion:** AdamW with weight_decay=0.01 does not improve over baseline progressive_K5

**Experiment 2 (Freeze BN):**
- ⚠️ **Slightly worse than baseline** on TM AUC (-0.0131)
- ✅ **Sens@90Spec nearly matches baseline** (78.1% vs 78.9%, -0.8%)
- ⚠️ **Calibration is poor** (ECE 0.3642 vs baseline 0.0476) — similar to AdamW
- **Better than AdamW** on TM AUC (+0.0194) and Sens@90Spec (+5.5%)
- **Conclusion:** Freezing BN during training slightly hurts performance vs baseline, but performs better than AdamW

**Experiment 3 (Focal Loss):**
- ❌ **Worse than baseline** on all key metrics
- TM AUC **-0.0327** below baseline (similar to AdamW)
- Sens@90Spec **-5.3%** below baseline (73.6% vs 78.9%)
- **Calibration is worst** of all experiments (ECE 0.3924 vs baseline 0.0476)
- **Conclusion:** Focal loss did not improve calibration or AUC; baseline cross-entropy remains better

**Experiment 4 (Temperature Scaling):**
- ❌ **Worse than baseline** on TM AUC (-0.0320) and Sens@90Spec (-5.8%)
- ✅ **Best ECE among the four experiments** (0.3505) but still much worse than baseline (0.0476)
- **Conclusion:** Temperature scaling helps calibration relative to other Phase 4 runs but does not match baseline; baseline remains best

**Overall Assessment:**
- **All four experiments are below baseline** — no experiment beats baseline progressive_K5 (TM AUC 0.9291)
- **Ranking on TM AUC:** Freeze BN (0.9160) > Temp (0.8971) > AdamW (0.8966) ≈ Focal (0.8964)
- **Ranking on ECE (calibration):** Temp (0.3505) best among experiments < AdamW (0.3612) < Freeze BN (0.3642) < Focal (0.3924); all still far above baseline (0.0476)
- **Phase 4 is complete.** Baseline progressive_K5 remains the recommended production strategy

---

## Next Steps

### Phase 4 Closed

All four experiments are complete. No experiment beats baseline progressive_K5 on TM AUC, Sens@90Spec, or ECE. **Production model remains baseline progressive_K5.** See [MODEL_VERSION_CHECK.md](MODEL_VERSION_CHECK.md) for deployment (copy baseline ONNX to `assets/` if needed).

### Future Work (optional)

1. **Post-hoc temperature scaling on the baseline** — Apply temperature scaling to the already-trained baseline progressive_K5 ensemble (on a validation set), then re-evaluate ECE on TM. This tests whether calibration can be improved without retraining; AUC and Sens@90Spec should be unchanged.

2. **Calibration investigation** — Phase 4 ensembles all show ECE ~0.35 vs baseline ~0.05. Document as a known limitation; possible causes: different training run/seed, data split, or evaluation pipeline (e.g. ONNX vs PyTorch).

3. **No further Phase 4 reruns** — No need to re-run AdamW, Freeze BN, Focal, or Temperature Scaling for production; baseline is the chosen model.

### Related Documentation

- **Phase 1 & Phase 2 Results:** See `PHASE1_PHASE2_RESULTS.md`
- **Model Development:** See `MODEL_DEVELOPMENT_AND_USAGE.md`
- **Model Registry:** See `ml/training/notebooks/model_registry.py`

---

## Notes

- **TensorBoard:** Experiments 1 and 2 were trained before TB logging was added (Feb 12). Experiments 3 and 4 have TensorBoard logs where applicable.
- **Validation Metrics:** Training script prints validation AUC/accuracy every 2 epochs; ensemble mean and individual AUCs are in `ensemble_metadata.json` per run.
- **Early Stopping:** All experiments use patience=12. Phase 4 is complete; all four experiments have been evaluated on frozen test sets.

---

## Extracting Metrics from Completed Experiments

### Using the Extraction Script

A script has been created to extract metrics from Experiments 1 & 2 checkpoints:

```bash
# Extract metrics for a single experiment
python extract_experiment_metrics.py --run_id exp_adamw
python extract_experiment_metrics.py --run_id exp_freeze_bn

# Extract metrics for both experiments at once
python extract_experiment_metrics.py --all
```

**What it does:**
- Loads the checkpoint and config
- Reconstructs the model and validation data loader (same seed/config as training)
- Evaluates the model on the validation set
- Extracts: `final_val_accuracy`, `final_val_auc`, `final_val_loss`
- Tries to extract `best_val_auc` from terminal logs if available
- Saves `training_metrics.json` to the experiment directory

**Known metrics from terminal logs:**
- **Experiment 2 (exp_freeze_bn):** Best val AUC: **0.8721** (from terminal log file 353362.txt)
- **Experiment 1 (exp_adamw):** Check terminal logs or run extraction script

---

## Detailed Results Files

- **Experiment 1 (AdamW) Evaluation:** `ml/training/notebooks/results/train_experiment/exp_adamw_ensemble/frozen_eval.json`
- **Experiment 1 (AdamW) Metadata:** `ml/training/notebooks/results/train_experiment/exp_adamw_ensemble/ensemble_metadata.json`
- **Experiment 2 (Freeze BN) Evaluation:** `ml/training/notebooks/results/train_experiment/exp_freeze_bn_ensemble/frozen_eval.json`
- **Experiment 2 (Freeze BN) Metadata:** `ml/training/notebooks/results/train_experiment/exp_freeze_bn_ensemble/ensemble_metadata.json`
- **Experiment 3 (Focal) Evaluation:** `ml/training/notebooks/results/train_experiment/exp_focal_ensemble/frozen_eval.json`
- **Experiment 3 (Focal) Metadata:** `ml/training/notebooks/results/train_experiment/exp_focal_ensemble/ensemble_metadata.json`
- **Experiment 4 (Temp) Evaluation:** `ml/training/notebooks/results/train_experiment/exp_temp_ensemble/frozen_eval.json`
- **Experiment 4 (Temp) Metadata:** `ml/training/notebooks/results/train_experiment/exp_temp_ensemble/ensemble_metadata.json`
- **Baseline Comparison:** See `MODEL_DEVELOPMENT_AND_USAGE.md` section "Freeze Strategy Comparison Results"

---

*Last updated: February 12, 2026 — Added Experiment 4 (Temperature Scaling); Phase 4 complete.*
