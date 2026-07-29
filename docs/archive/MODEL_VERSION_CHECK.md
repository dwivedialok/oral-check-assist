# Model Version Check: Current App vs Progressive_K5

**Date:** February 12, 2026

## Current Status

### ❌ **App is Using OLDER Models, NOT Progressive_K5**

## Evidence

### 1. **What the App Loads** (from `assets/` directory)

| Model Type | Files | Modified Date | Size |
|------------|-------|---------------|------|
| **Binary** | `binary_ensemble_mode_1/2/3.onnx` | **Feb 7, 19:38-39** | 13M, 13M, 14M |
| **5-Class** | `ensemble_model_1/2/3.onnx` | **Feb 4, 22:23** | 12M, 12M, 13M |

### 2. **What Should Be Used** (from `decision.json` and `model_registry.py`)

| Model Type | Source | Modified Date | Size |
|------------|--------|---------------|------|
| **Binary** | `freeze_comparison_20260208_121618/onnx/` | **Feb 9, 15:03** | 13M, 13M, 14M |
| **5-Class** | `improved_5class_20260209_172821/onnx/` | **Feb 10, 10:57** | 13M, 13M, 14M |

### 3. **MD5 Checksums (Proof They're Different)**

```
assets/binary_ensemble_mode_1.onnx:        c8d1752fd4535a3f7bb6b986e8873ba7
freeze_comparison.../ensemble_model_1.onnx: 9226846395172e8431a48e573d998f0d
❌ DIFFERENT FILES

assets/ensemble_model_1.onnx:              2b81168b577986bd1db513b8f2b14759
improved_5class.../ensemble_model_1.onnx:   4419149c0540479b3776f491c154d44e
❌ DIFFERENT FILES
```

### 4. **Decision.json Says Progressive_K5 Should Be Used**

From `ml/training/notebooks/results/phase0_run/eval_report/decision.json`:
```json
{
  "binary_model": "progressive_K5",
  "binary_onnx_dir": ".../freeze_comparison_20260208_121618/onnx",
  "fiveclass_model": "progressive_K5",
  "fiveclass_onnx_dir": ".../improved_5class_20260209_172821/onnx",
  "locked": true
}
```

## What Models Are Currently in Assets?

Based on file dates and sizes:

### Binary Models (`binary_ensemble_mode_*.onnx`)
- **Likely Source:** `improved_binary_training.ipynb` (older full fine-tune)
- **Date:** Feb 7, 2026
- **Strategy:** Full fine-tune (not progressive_K5)

### 5-Class Models (`ensemble_model_*.onnx`)
- **Likely Source:** `production_oral_cavity_classifier.ipynb` (older production)
- **Date:** Feb 4, 2026
- **Strategy:** Full fine-tune (not progressive_K5)

## How to Confirm

### Method 1: Check File Dates
```bash
ls -lh assets/*.onnx
ls -lh ml/training/notebooks/results/freeze_comparison/freeze_comparison_20260208_121618/onnx/*.onnx
ls -lh ml/training/notebooks/results/improved_5class/improved_5class_20260209_172821/onnx/*.onnx
```

### Method 2: Compare MD5 Checksums
```bash
md5 assets/binary_ensemble_mode_1.onnx
md5 ml/training/notebooks/results/freeze_comparison/freeze_comparison_20260208_121618/onnx/ensemble_model_1.onnx
# Different checksums = different models
```

### Method 3: Check Decision.json
```bash
cat ml/training/notebooks/results/phase0_run/eval_report/decision.json
# Shows what models SHOULD be used
```

### Method 4: Check Model Registry
```bash
cd ml/training/notebooks
python model_registry.py
# Shows canonical paths
```

## What Needs to Happen

### ✅ **Update Assets Directory**

Copy progressive_K5 models to assets:

```bash
# Binary models
cp ml/training/notebooks/results/freeze_comparison/freeze_comparison_20260208_121618/onnx/ensemble_model_1.onnx assets/binary_ensemble_mode_1.onnx
cp ml/training/notebooks/results/freeze_comparison/freeze_comparison_20260208_121618/onnx/ensemble_model_2.onnx assets/binary_ensemble_mode_2.onnx
cp ml/training/notebooks/results/freeze_comparison/freeze_comparison_20260208_121618/onnx/ensemble_model_3.onnx assets/binary_ensemble_mode_3.onnx

# 5-class models
cp ml/training/notebooks/results/improved_5class/improved_5class_20260209_172821/onnx/ensemble_model_1.onnx assets/ensemble_model_1.onnx
cp ml/training/notebooks/results/improved_5class/improved_5class_20260209_172821/onnx/ensemble_model_2.onnx assets/ensemble_model_2.onnx
cp ml/training/notebooks/results/improved_5class/improved_5class_20260209_172821/onnx/ensemble_model_3.onnx assets/ensemble_model_3.onnx
```

## Performance Impact

### Current Models (Older, Full Fine-tune)
- Binary: Unknown performance (likely lower than progressive_K5)
- 5-Class: Unknown performance (likely lower than progressive_K5)

### Progressive_K5 Models (Should Be Used)
- Binary: **TM AUC 0.9291, Sens@90Spec 78.9%** (from ARCHITECTURE_HISTORY.md)
- 5-Class: Progressive_K5 strategy (same as binary winner)

## Summary

| Aspect | Current (Assets) | Should Be (Progressive_K5) |
|--------|------------------|---------------------------|
| **Binary** | Older (Feb 7) | Progressive_K5 (Feb 9) |
| **5-Class** | Older (Feb 4) | Progressive_K5 (Feb 10) |
| **Strategy** | Full fine-tune | Progressive_K5 |
| **Performance** | Unknown | Binary: TM AUC 0.9291 |
| **Status** | ❌ Outdated | ✅ Latest & Best |

**Action Required:** Update assets directory with progressive_K5 models.
