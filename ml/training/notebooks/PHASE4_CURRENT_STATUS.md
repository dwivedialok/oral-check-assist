# Phase 4: Current Status & Next Steps

**Last Updated:** February 12, 2026

---

## ✅ What Just Finished

**Metrics extraction completed:**
- ✅ **Experiment 1 (AdamW)**: Best Val AUC = **0.8804**, Final Val Acc = **77.63%**
- ✅ **Experiment 2 (Freeze BN)**: Best Val AUC = **0.8721**, Final Val Acc = **77.48%**

**Note:** These are **validation set** metrics (internal train/val split), NOT frozen test set (TM) metrics. They're not directly comparable to the baseline's TM AUC of 0.9291.

---

## 🔄 What's Currently Happening

**Experiment 3 (Focal loss):**
- Status: Training appears to have stopped (no checkpoint found)
- Last TB log: Feb 12, 01:47 AM (old)
- TB logs exist but no `best.pth` checkpoint
- **Action needed:** Check if training crashed or is still running

---

## ⚠️ The Problem We Discovered

**Comparison mismatch:**
- **Baseline progressive_K5**: Evaluated as **3-model ensemble** → TM AUC **0.9291**
- **Phase 4 experiments**: Trained as **single models** → Cannot fairly compare

**Solution:** Re-run all experiments with `--ensemble` flag to train 3 models each.

---

## 📋 What You Should Do Next

### Option A: Re-run All 4 Experiments with Ensemble (Recommended)

**Yes, this means re-running Experiments 1 & 2**, but it's necessary for fair comparison:

```bash
cd ml/training/notebooks

# Experiment 1: AdamW (ensemble)
python train_experiment.py \
  --config experiment_configs/adamw.json \
  --run_id exp_adamw_ensemble \
  --ensemble \
  --export_onnx

# Experiment 2: Freeze BN (ensemble)
python train_experiment.py \
  --config experiment_configs/freeze_bn.json \
  --run_id exp_freeze_bn_ensemble \
  --ensemble \
  --export_onnx

# Experiment 3: Focal loss (ensemble) - re-run since current run seems incomplete
python train_experiment.py \
  --config experiment_configs/focal_loss.json \
  --run_id exp_focal_ensemble \
  --ensemble \
  --export_onnx

# Experiment 4: Temperature scaling (ensemble)
python train_experiment.py \
  --config experiment_configs/temperature_scaling.json \
  --run_id exp_temp_ensemble \
  --ensemble \
  --export_onnx
```

**Time estimate:** Each ensemble takes ~3× longer (3 models). Expect ~2-3 hours per experiment on MPS.

### Option B: Keep Single Models, Compare to Single Baseline (Less Ideal)

If you don't want to re-train:
1. Evaluate **one baseline model** (e.g., `ensemble_model_3.pth`) on TM
2. Compare Phase 4 single models to that single baseline
3. **Note:** Won't match the 0.9291 ensemble number

---

## 🎯 After Ensemble Training Completes

Evaluate each ensemble on frozen test sets:

```bash
for exp in exp_adamw_ensemble exp_freeze_bn_ensemble exp_focal_ensemble exp_temp_ensemble; do
  python evaluate_on_frozen_sets.py \
    --model results/train_experiment/$exp/onnx \
    --model_type binary_onnx_ensemble \
    --output results/train_experiment/$exp/frozen_eval.json
done
```

Then compare **TM AUC** from each experiment to baseline's **0.9291**.

---

## 📊 Current Single-Model Results (For Reference)

| Experiment | Best Val AUC | Final Val Acc | Status |
|------------|--------------|---------------|--------|
| **1. AdamW** | 0.8804 | 77.63% | ✅ Single model complete |
| **2. Freeze BN** | 0.8721 | 77.48% | ✅ Single model complete |
| **3. Focal loss** | ? | ? | ⚠️ Training incomplete (no checkpoint) |
| **4. Temperature scaling** | - | - | ⏳ Not started |

**Note:** These validation AUCs are **not** comparable to baseline's TM AUC (0.9291) because:
- Different evaluation sets (validation vs frozen test TM)
- Different model types (single vs ensemble)

---

## 💡 Recommendation

**Re-run all 4 experiments with `--ensemble --export_onnx`** to get:
- Fair comparison (ensemble vs ensemble)
- Proper TM AUC metrics
- ONNX models ready for deployment evaluation

The single-model runs (exp_adamw, exp_freeze_bn) can be kept for reference, but won't be used for final comparison.

---

*This document will be updated as ensemble training progresses.*
