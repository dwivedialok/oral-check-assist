# Phase 4: Ensemble Training Update

## Problem Identified

**Issue:** Phase 4 experiments were training **single models**, but the baseline progressive_K5 was evaluated as a **3-model ensemble** (TM AUC 0.9291). Comparing single models to ensembles is not fair.

**Baseline:**
- Trained 3 models with dropout rates [0.3, 0.1, 0.2]
- Evaluated as ensemble (weights [0.30, 0.40, 0.30])
- TM AUC: **0.9291** (ensemble result)

**Phase 4 (before fix):**
- Trained 1 model per experiment
- Cannot fairly compare to baseline ensemble

## Solution

Updated `train_experiment.py` to support **ensemble mode** (`--ensemble` flag) that:
1. Trains 3 models per experiment (same as baseline)
2. Uses dropout rates [0.3, 0.1, 0.2] (same as baseline)
3. Uses seeds [base_seed, base_seed+1, base_seed+2] for diversity
4. Exports each to ONNX (with `--export_onnx`)
5. Saves ensemble metadata

## Updated Usage

### For Future Experiments (Ensemble Mode)

```bash
# Experiment 3: Focal loss (when re-run with ensemble)
python train_experiment.py \
  --config experiment_configs/focal_loss.json \
  --run_id exp_focal_ensemble \
  --ensemble \
  --export_onnx

# Experiment 4: Temperature scaling (with ensemble)
python train_experiment.py \
  --config experiment_configs/temperature_scaling.json \
  --run_id exp_temp_ensemble \
  --ensemble \
  --export_onnx
```

### For Existing Single Models (Experiments 1 & 2)

**Option A: Re-train with ensemble mode** (recommended for fair comparison)
```bash
# Re-run Experiment 1 with ensemble
python train_experiment.py \
  --config experiment_configs/adamw.json \
  --run_id exp_adamw_ensemble \
  --ensemble \
  --export_onnx

# Re-run Experiment 2 with ensemble
python train_experiment.py \
  --config experiment_configs/freeze_bn.json \
  --run_id exp_freeze_bn_ensemble \
  --ensemble \
  --export_onnx
```

**Option B: Keep single models, compare to single baseline** (less ideal)
- Evaluate one baseline model (e.g., ensemble_3) on TM
- Compare Phase 4 singles to that single baseline
- Note: Won't match the 0.9291 ensemble number

## What Gets Created

With `--ensemble --export_onnx`:

```
results/train_experiment/<run_id>/
├── models/
│   ├── ensemble_model_1.pth
│   ├── ensemble_model_2.pth
│   └── ensemble_model_3.pth
├── onnx/
│   ├── ensemble_model_1.onnx
│   ├── ensemble_model_2.onnx
│   └── ensemble_model_3.onnx
├── ensemble_metadata.json  # Val AUCs, weights, config
├── config.json
└── ensemble_1/, ensemble_2/, ensemble_3/  # Individual training dirs
```

## Evaluation on Frozen Test Sets

After training ensemble, evaluate on frozen test sets:

```bash
python evaluate_on_frozen_sets.py \
  --model results/train_experiment/<run_id>/onnx \
  --model_type binary_onnx_ensemble \
  --output results/train_experiment/<run_id>/frozen_eval.json
```

This gives you **TM AUC** that's directly comparable to the baseline's **0.9291**.

## Current Status

- ✅ **Script updated** to support `--ensemble` and `--export_onnx`
- ⚠️ **Experiments 1 & 2**: Already trained as single models (need re-run for fair comparison)
- 🔄 **Experiment 3**: Currently running as single model (will need re-run with ensemble)
- ⏳ **Experiment 4**: Not started yet (should use `--ensemble` from the start)

## Recommendation

1. **Let Experiment 3 finish** (it's already running as single model)
2. **Re-run all 4 experiments with `--ensemble --export_onnx`** for fair comparison
3. **Evaluate each ensemble on frozen test sets** (T5, TB, TC, TM)
4. **Compare ensemble TM AUCs** to baseline's 0.9291

This ensures apples-to-apples comparison: **ensemble vs ensemble**.

---

*Updated: February 12, 2026*
