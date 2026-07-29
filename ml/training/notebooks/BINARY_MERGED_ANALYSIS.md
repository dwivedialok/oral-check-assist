# Binary Merged Model – Run Analysis

## Real-world usage: 5-class (69.66%) vs binary merged (63.07%)

**Short answer:** The numbers are **not comparable**. The 69.66% model was evaluated only on the **same 5-class dataset** it was trained on (a held-out test split of that dataset). The 63.07% model was evaluated on a **merged test set** (images from both the binary dataset and the 5-class dataset). From a real-world perspective, the 63.07% figure may be the **more honest** estimate when deployment sees mixed or diverse sources.

### How each model was evaluated

| Model | Training data | Test set | What test actually is |
|-------|---------------|----------|------------------------|
| **5-class TFLite / PyTorch (69.66%)** | 5-class dataset train split | 5-class dataset **test** split | Same dataset, same distribution as train (only split differs). No binary-dataset images. |
| **Binary merged (63.07%)** | Merged: binary + 5-class (mapped to binary) | 15% **stratified split of merged** | Mix of images from **both** binary and 5-class sources. More diverse. |

So:

1. **69.66% is “in-distribution” for 5-class only.**  
   The 5-class model was never evaluated on (a) the binary dataset, or (b) a combined distribution. If real-world usage looks like “only 5-class-like images,” that number can be relevant. If real-world usage includes different clinics, different acquisition, or mixed sources (e.g. binary + 5-class), 69.66% is **optimistic** — we don’t know how the 5-class model would perform on that mixed set (it could be worse than 63%).

2. **63.07% is measured on a harder, more diverse test.**  
   The merged test set contains images from two distinct sources. So 63.07% is the accuracy we actually measured when the model is tested on a **mixed** distribution. For deployment scenarios where input distribution is mixed or unknown, this is the **more realistic** number we have for the binary merged model.

3. **“Adding binary made the model worse” is misleading.**  
   We did not simply “add binary and get worse.” We changed both training and evaluation:
   - Training: we added binary data and merged with 5-class (mapped to binary).
   - Evaluation: we switched to a **merged** test set (two sources).  
   So the binary merged model is being judged on a **stricter** evaluation (more diverse test). The 5-class model was never judged on that same test; it might do no better (or worse) there.

### Conclusion for real-world usage

- **Do not** conclude that “the 5-class dataset and TFLite from it was better and adding the binary dataset resulted in a poorer model.”
- **Do** conclude that:
  - The 5-class 69.66% is valid only for the **5-class test set** (same distribution as its training data).
  - The binary merged 63.07% is valid for a **merged, two-source test set**.
  - For real-world use where the input distribution is **mixed or unknown**, the 63.07% model is the one we have actually evaluated in that setting; the 5-class model’s real-world performance on mixed data is **unknown** and could be similar or worse than 63%.

To compare fairly, we would need to run the **same** evaluation for both: e.g. evaluate the 5-class (or its binary mapping) and the binary merged model on the **same** merged test set, and report accuracy on that common test set.

### Frozen test sets (T5, TB, TM) — comparable evaluation

This is now implemented. **Three frozen test sets** are used so all models report on the same splits:

| Set | Description |
|-----|-------------|
| **T5** | 5-class-only test (from `oral_cavity_5class_dataset/test/`). Binary view: OCA+OPMD=1, Benign+Healthy=0. |
| **TB** | Binary-only test (fixed 15% holdout from `oral_cavity_binary_dataset`). Never used for training. |
| **TM** | Mixed merged test = T5 (binary-eligible) ∪ TB. Report **per-source (A vs B)** to see if the issue is “model can’t learn signal” vs “model doesn’t transfer across sources”. |

- **Binary merged notebook** (`binary_classification_merged_dataset.ipynb`): Training excludes T5 and TB; evaluation runs on T5, TB, and TM and reports TM per-source (A vs B). Results are in `evaluation_results.json` under keys `T5`, `TB`, `TM`, `TM_source_A`, `TM_source_B`.
- **Standalone evaluator** (`evaluate_on_frozen_sets.py`): Run any binary or 5-class TFLite on T5, TB, TM to get comparable metrics. Example:  
  `python evaluate_on_frozen_sets.py --model path/to/model.tflite --model_type binary_tflite`
- **Manifests** are built by `frozen_test_sets.py` and saved under `frozen_test_sets/`. See `frozen_test_sets/README.md`.

### Data distribution (train / val / test) — quick reference

One place to see how each dataset is split and **what is used for testing accuracy**.

| Dataset / set | Train | Val | Test | Used for reporting test accuracy |
|---------------|-------|-----|------|-----------------------------------|
| **5-class** (`oral_cavity_5class_dataset`) | `train/` | `val/` | **`test/`** | 5-class models: accuracy on **test/** (same distribution as train). |
| **Binary** (`oral_cavity_binary_dataset`) | 85% (train+val pool) | — | **TB = 15% holdout** | Binary merged: TB is **never** in training; test accuracy can be reported on TB. |
| **Frozen T5** | — | — | **T5** = 5-class `test/` only | From 5-class dataset. **T5 count** = all 5-class test images (incl. Unknown). For binary metrics we use T5 **binary-eligible** only (exclude Unknown). |
| **Frozen TB** | — | — | **TB** = 15% of binary (seed 42) | From binary dataset. **TB count** = 15% stratified holdout. Never used for training in merged setup. |
| **Frozen TM** | — | — | **TM** = T5 (binary-eligible) ∪ TB | **TM** = mixed test set. **TM accuracy** is the main comparable metric across models (same set for Ensemble and binary TFLite). |

**Typical counts** (from `python frozen_test_sets.py`; your run may differ by dataset size):

| Set | Count | Notes |
|-----|-------|--------|
| T5 | 534 | 5-class test total (all classes). |
| T5 binary-eligible | 484 | T5 minus Unknown (used in TM from 5-class side). |
| TB | 246 | 15% of binary dataset. |
| TM | 730 | 484 + 246 (mixed test for comparable accuracy). |
| binary train+val (for merged training) | 1388 | Binary paths **not** in TB; use for training binary merged. |

**What is used for testing accuracy in each scenario:**

- **5-class / Ensemble (76.36%)**: originally reported on 5-class **test/** (533 samples in status doc). For like-for-like comparison, report on **T5, TB, TM** via `evaluate_on_frozen_sets.py`.
- **Binary merged (63.07%)**: agent run reported on a **15% stratified test split of merged** data (744 samples). For like-for-like, report on **T5, TB, TM** (730 samples) via the same script.
- **Comparable numbers**: run both models on **T5, TB, TM** and compare **TM** (and optionally T5, TB, TM_source_A, TM_source_B).

---

## Latest run (run_20260129_152953) vs previous (run_20260129_140007)

| Metric | Previous (no class weights, simple aug) | Latest (class weights + rot/zoom) |
|--------|----------------------------------------|----------------------------------|
| **Test accuracy** | 60.60% | 56.58% (↓ ~4%) |
| **Cancer (sensitivity)** | 69.21% | 72.70% (↑) |
| **Non-cancer (specificity)** | 51.40% | 39.33% (↓ ~12%) |

## What the confusion matrix shows (latest run)

```
                  Predicted
                  Non-cancer  Cancer
Actual Non-cancer:     140       216   ← 356 total non-cancer
Actual Cancer:        104       277   ← 381 total cancer
```

- **216 false positives**: non-cancer images predicted as cancer (up from 173).
- **277 true positives**: cancer correctly predicted (up from 263).
- **140 true negatives**: non-cancer correctly predicted (down from 183).

So the model is **predicting “cancer” more often**: 493/737 ≈ 67% of predictions are cancer (vs ~59% before). The decision boundary moved toward “cancer”.

## What this indicates

1. **Cancer accuracy up, non-cancer down**  
   The model became more **cancer-biased**: it calls more cases cancer, so:
   - More cancers are caught (sensitivity ↑).
   - More non-cancers are wrongly called cancer (specificity ↓).

2. **Class weights (balanced)**  
   We upweighted the minority class (non-cancer). In theory that should help specificity. In practice the optimizer may have reduced loss more by:
   - Increasing “cancer” predictions (more TP, fewer FN), and  
   - Accepting more FP on non-cancer.  
   So balanced weights did not improve specificity here and may have pushed the boundary toward “cancer”.

3. **Augmentation (rot90 + zoom)**  
   Stronger augmentation can:
   - Hurt classes that rely on fine or orientation-dependent cues (possibly non-cancer).
   - Favor classes with more robust, global features (possibly cancer-like appearance).  
   So rot/zoom might be helping sensitivity and hurting specificity.

4. **Training history**  
   - Best **val_accuracy** ≈ 58.05% (epoch 13), best **val_loss** ≈ 0.6822.  
   - Test accuracy 56.58% is in line with validation; no sign of big overfitting.  
   - Model is consistently marginal; the main issue is **bias toward “cancer”**, not instability.

5. **Confidence**  
   Mean prob ≈ 0.526, range ≈ 0.24–0.77. Predictions are spread; the mean slightly above 0.5 is consistent with a slight cancer bias at threshold 0.5.

## Recommendations

1. **Revert class weights** for the next run and compare again (to see if specificity returns toward ~51%).
2. **Soften augmentation**: remove rot90/zoom and keep only flip + brightness + contrast; check if specificity improves.
3. **Try a higher decision threshold** (e.g. 0.55 or 0.6) when predicting “cancer”: fewer FP, so specificity ↑ and sensitivity ↓. Good if you want to reduce false alarms.
4. **Optional**: weight **non-cancer more** than “balanced” (e.g. 1.3–1.5× for class 0) to push the boundary back toward “non-cancer” and see if specificity improves without killing sensitivity.

## Summary

- **Cancer accuracy up + non-cancer down** = model is more willing to call a case “cancer”.
- **Confusion matrix** = more FP (216), fewer TN (140); **history** = stable but modest val performance.
- Next steps: revert/reduce class weights, reduce augmentation, and/or raise the decision threshold and document results in this file.
