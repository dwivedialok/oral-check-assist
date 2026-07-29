# Phase 1 & Phase 2 Results Summary

**Last Updated:** February 12, 2026

---

## Phase 0: Baseline Evaluation ✅ **Completed**

**Purpose:** Establish baseline metrics for binary and 5-class models on frozen test sets.

**Results Location:**
- **Evaluation Report:** `ml/training/notebooks/results/phase0_run/eval_report/`
  - `binary_metrics.json` - Binary ensemble metrics on all splits
  - `fiveclass_metrics.json` - 5-class ensemble metrics on all splits
  - `agreement_all_splits.json` - Agreement analysis between binary and 5-class
  - `thresholds.json` - Threshold analysis

**Key Baseline Metrics (from decision.json):**
- **TM (Mixed Test Set):**
  - Binary AUROC: **0.9291**
  - Binary Sens@90Spec: **78.86%**
  - Binary Brier: **0.1099**
  - Binary ECE: **0.3775**
  - 5-class AUROC: **0.8568**
  - 5-class Sens@90Spec: **58.71%**

---

## Phase 1: Lock Production Decision ✅ **Completed**

**Purpose:** Generate decision summary from Phase 0 evaluation and lock production model paths.

**Results Location:**
- **Decision Summary:** `ml/training/notebooks/results/phase0_run/eval_report/decision.json`
- **Decision Report:** `ml/training/notebooks/results/phase0_run/eval_report/decision.md`

**Locked Models:**
- **Binary Ensemble:** `ml/training/notebooks/results/freeze_comparison/freeze_comparison_20260208_121618/onnx`
  - Strategy: `progressive_K5`
  - 3-model ensemble (ensemble_model_1.onnx, ensemble_model_2.onnx, ensemble_model_3.onnx)
  
- **5-Class Ensemble:** `ml/training/notebooks/results/improved_5class/improved_5class_20260209_172821/onnx`
  - Strategy: `progressive_K5`
  - 3-model ensemble

**Decision Status:** ✅ **Locked** (`"locked": true` in decision.json)

**Key Metrics Summary (from decision.md):**

| Split | N | Binary AUROC | Binary S@90Sp | 5-class AUROC | 5-class S@90Sp |
| ----- | --- | ------------ | ------------- | ------------- | -------------- |
| T5 | 484 | 0.8830 | 64.90% | 0.8711 | 60.82% |
| TB | 246 | 0.9836 | 96.24% | 0.7629 | 43.61% |
| TC | 49 | 0.9983 | 100.00% | 1.0000 | 100.00% |
| **TM** | **779** | **0.9291** | **78.86%** | **0.8568** | **58.71%** |

---

## Phase 2: Gated Fusion Policy ✅ **Completed**

**Purpose:** Evaluate gated fusion policy (combining binary and 5-class predictions) vs current Dart approach.

**Results Location:**
- **Fusion Policy Results:** `ml/training/notebooks/results/fusion_policy_results.json`

**Key Findings:**

### TM (Mixed Test Set) - Primary Comparison

| Metric | Gated Fusion | Current Dart | Winner |
|--------|--------------|--------------|--------|
| **Sens@90Spec** | **78.86%** | **78.86%** | **Tie** ✅ |
| **Sensitivity** | 91.79% | 90.30% | Gated Fusion |
| **Specificity** | 66.58% | 71.62% | Current Dart |
| **Dangerous Misses** | **33** | **39** | **Gated Fusion** ✅ (-6) |
| **Unnecessary Refers** | 126 | 107 | Current Dart |

### Other Test Sets

**T5 (5-class test):**
- Gated Fusion: Sens@90Spec 67.76%, Dangerous Misses: 25
- Current Dart: Sens@90Spec 64.90%, Dangerous Misses: 31
- **Winner: Gated Fusion** (better Sens@90Spec, fewer dangerous misses)

**TB (binary test):**
- Gated Fusion: Sens@90Spec 90.23%, Dangerous Misses: 8
- Current Dart: Sens@90Spec 96.24%, Dangerous Misses: 8
- **Winner: Current Dart** (better Sens@90Spec, same dangerous misses)

**TC (small binary):**
- Both: Sens@90Spec 100%, Dangerous Misses: 0
- **Tie**

### Conclusion

**Gated Fusion Policy:**
- ✅ **Matches** current Dart on TM Sens@90Spec (78.86%)
- ✅ **Reduces dangerous misses** on TM (33 vs 39, **-15%**)
- ✅ **Better** on T5 (67.76% vs 64.90% Sens@90Spec, fewer dangerous misses)
- ⚠️ **Worse** on TB (90.23% vs 96.24% Sens@90Spec)
- ⚠️ **More unnecessary refers** on TM (126 vs 107)

**Recommendation:** Gated fusion is **acceptable** — matches TM Sens@90Spec while reducing dangerous misses. The increase in unnecessary refers may be acceptable given the reduction in dangerous misses.

**Status:** ✅ **Policy evaluated and documented**

---

## Summary

| Phase | Status | Key Output | Location |
|-------|--------|------------|----------|
| **Phase 0** | ✅ Complete | Baseline evaluation metrics | `results/phase0_run/eval_report/` |
| **Phase 1** | ✅ Complete | Locked production model paths | `results/phase0_run/eval_report/decision.json` |
| **Phase 2** | ✅ Complete | Gated fusion policy evaluation | `results/fusion_policy_results.json` |
| **Phase 4** | 🔄 In Progress | Architecture experiments | `PHASE4_TRAIN_EXPERIMENT_RESULTS.md` |

---

## Related Documentation

- **Phase 4 Results:** See `PHASE4_TRAIN_EXPERIMENT_RESULTS.md` for architecture experiment results
- **Model Registry:** See `ml/training/notebooks/model_registry.py` for canonical model paths
- **Model Development:** See `MODEL_DEVELOPMENT_AND_USAGE.md` for full model development history

---

*Last updated: February 12, 2026*
