# Like-for-like: Virtual Ensemble vs Binary Merged TFLite

## Goal

Compare the **best Virtual Ensemble** (76.36% on 5-class test per `CURRENT_PROGRESS_STATUS.md`) with the **best binary merged TFLite** (63.07% from agent config 02 per `AGENT_RUN_SUMMARY.md`) on the **same** binary test data so results are comparable.

## Reference numbers

| Model | Reported accuracy | Test set used |
|-------|--------------------|---------------|
| **Virtual Ensemble (3 ONNX)** | **76.36%** | 5-class test (533 samples) |
| **Binary merged TFLite (config 02)** | **63.07%** | Merged train/test split (744 test) |

The 63.07% was measured on a 15% stratified test split of the merged (binary + 5-class) dataset. For a fair comparison we evaluate both on the **frozen test sets T5, TB, TM** (see `BINARY_MERGED_ANALYSIS.md` and `frozen_test_sets/README.md`).

## Frozen test sets (T5, TB, TM)

| Set | Description |
|-----|-------------|
| **T5** | 5-class-only test (binary view: OCA+OPMD=1, Benign+Healthy=0; Unknown excluded). |
| **TB** | Binary-only test (15% holdout from binary dataset, never in training). |
| **TM** | Mixed = T5 ∪ TB. **TM accuracy** is the main comparable metric. |

## Steps for like-for-like comparison

### 1. Build frozen manifests (once)

From `ml/training/notebooks` with the correct venv:

```bash
python frozen_test_sets.py
```

This uses default paths (`~/dev/oral_cavity_5class_dataset`, `~/dev/oral_cavity_binary_dataset`) or set them in the script. Output: `frozen_test_sets/T5.json`, `TB.json`, `TM.json`, `meta.json`.

### 2. Evaluate Virtual Ensemble on T5, TB, TM

Ensemble ONNX models are in project `assets/` (ensemble_model_1/2/3.onnx).

```bash
cd ml/training/notebooks
python evaluate_on_frozen_sets.py --model ../../../assets --model_type 5class_onnx_ensemble --output results/ensemble_frozen_T5_TB_TM.json
```

### 3. Evaluate binary merged TFLite on T5, TB, TM (same sets)

Best binary run: `results/binary_merged/run_20260129_173447/`.

```bash
python evaluate_on_frozen_sets.py --model results/binary_merged/run_20260129_173447/tflite/binary_merged_dynamic.tflite --model_type binary_tflite --output results/binary_merged_frozen_T5_TB_TM.json
```

### 4. Compare

- Open `results/ensemble_frozen_T5_TB_TM.json` and `results/binary_merged_frozen_T5_TB_TM.json`.
- Compare **TM** accuracy (and optionally T5, TB, TM_source_A, TM_source_B) for the two models.

## Notebook

In `pytorch_to_onnx_ensemble.ipynb`, the final section **"Like-for-like: Virtual Ensemble on frozen binary test sets"** runs step 2 from the notebook (same script call). Run the conversion and ensemble cells first so `OUTPUT_DIR` or `assets/` has the three ONNX files.

## Like-for-like results (frozen T5, TB, TM)

| Model | T5 Acc | TB Acc | **TM Acc** | TM Sens | TM Spec |
|-------|--------|--------|------------|---------|---------|
| **Virtual Ensemble (5-class ONNX)** | 81.40% | 74.39% | **79.04%** | 75.93% | 82.39% |
| **Binary merged TFLite (config 02)** | 53.31% | 56.10% | **54.25%** | 87.30% | 18.75% |

**Conclusion**

- **No preprocessing bug.** The binary merged model was trained with resize 224 and `/255` (no ImageNet normalization). The evaluator uses the same (PIL resize 224, `/255`), so processing matches training.
- **Binary merged performs poorly on this holdout.** On the **same** T5/TB/TM data, Ensemble gets **79% TM accuracy** vs binary merged **54%**. So the binary merged model is genuinely worse on this evaluation.
- **Binary merged is heavily cancer-biased.** High sensitivity (87%) but very low specificity (18.75%) means it predicts “cancer” for most images. That fits the pattern already seen in `BINARY_MERGED_ANALYSIS.md` for some configs (e.g. full/light aug). So the issue is **model behavior** (bias + generalization), not evaluator processing.
- The **63.07%** from the agent was on a **different** test set (15% stratified split of merged data). On the **frozen** T5/TB/TM we get 54% — either the frozen sets are harder or the model generalizes poorly to T5/TB.

**Takeaway:** For comparable mixed-data evaluation (T5/TB/TM), the **Virtual Ensemble is the better model**. Improving the binary merged pipeline would require addressing class balance, augmentation, and/or architecture, not the evaluation preprocessing.

---

## Summary

- **63.07%** is the best binary merged accuracy so far (config 02, agent run) on its own test split.
- On **frozen T5/TB/TM**, Ensemble ≈ **79%** vs binary merged ≈ **54%**; preprocessing matches training for both.
- Then compare **TM** (and T5/TB) between the two JSON outputs for a like-for-like comparison.
