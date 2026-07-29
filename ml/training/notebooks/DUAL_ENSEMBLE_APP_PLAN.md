# Dual-ensemble app plan: binary + 5-class

## Is it possible?

**Yes.** Training a **second ensemble** (same architecture as the current 5-class ensemble, but with **2 output classes**) on the **merged binary dataset** can improve binary accuracy because:

1. **More data** – Merged training uses 5-class train+val (mapped to binary) plus binary train+val (excluding TB). That’s more samples than 5-class–only training.
2. **Ensemble diversity** – Three models with different dropout (0.3, 0.1, 0.2) and slightly different heads often outperform a single model.
3. **Current gap** – The 5-class ensemble mapped to binary gets **~79% TM** on frozen sets; the single binary TFLite gets **~54% TM**. A binary ensemble trained on merged data has room to sit between or above these.

So the plan is:

- **Keep** the existing 5-class ONNX ensemble (cancer vs not via OCA+OPMD mapping; also gives fine labels).
- **Add** a new binary ONNX ensemble trained on merged binary data (same frozen train/val splits as `binary_classification_merged_dataset.ipynb`).
- **Use both in the app**: binary ensemble for “cancer or not”; 5-class ensemble for “better label”; combine with a simple matrix for the final UX.

---

## Current models

| Model | Training data | Output | TM (frozen) |
|-------|----------------|--------|-------------|
| **5-class ONNX ensemble** | 5-class dataset | 5 classes → map to binary (OCA+OPMD=1) | ~79% |
| **Binary merged TFLite** | Merged binary (5-class + binary, TB excluded) | 2 classes | ~54% |

---

## Steps to add the binary ensemble

### 1. Train binary ensemble (PyTorch)

- **Notebook**: Use **`binary_ensemble_training.ipynb`** (full pipeline: config, data, train 3 models, export ONNX, evaluate on T5/TB/TM).
- **Architecture**: Same as `pytorch_to_onnx_ensemble.ipynb`: `ConservativeMobileNetV3` with `EnsembleModel1`, `EnsembleModel2`, `EnsembleModel3`, but **`num_classes=2`**.
- **Data**: Same as merged binary training:
  - **Binary train+val**: `get_binary_train_val_for_training(data_dir_binary, frozen_test_sets)` (excludes TB).
  - **5-class train+val** (mapped to binary): `train/` + `val/` from 5-class dataset, labels Benign/Healthy→0, OCA/OPMD→1; exclude Unknown.
- **Splits**: Stratified train/val from merged pool; T5 and TB are never seen during training.
- **Output**: Three PyTorch checkpoints in `results/binary_ensemble/run_YYYYMMDD_HHMMSS/models/` (e.g. `ensemble_model_1.pth`, `ensemble_model_2.pth`, `ensemble_model_3.pth`).

### 2. Export to ONNX

- **`binary_ensemble_training.ipynb`** includes an ONNX conversion cell (same logic as `pytorch_to_onnx_ensemble.ipynb` with **`num_classes=2`**).
- Same input: (1, 3, 224, 224), ImageNet normalization.
- Output: (batch, 2) logits.
- ONNX files are written to `results/binary_ensemble/run_YYYYMMDD_HHMMSS/onnx/` (e.g. `ensemble_model_1.onnx`, `ensemble_model_2.onnx`, `ensemble_model_3.onnx`). Copy to `assets/binary_ensemble/` for the app.

### 3. Evaluate on frozen sets

- Use `evaluate_on_frozen_sets.py` with **`--model_type binary_onnx_ensemble`** and `--model path/to/dir/with/binary_ensemble_*.onnx`.
- Compare T5, TB, TM (and TM_source_A / TM_source_B) with the 5-class ensemble and the single binary TFLite.

---

## App: two models + “clever matrix”

### Roles

- **Binary ensemble** → “Cancer or not?” (primary referral decision).
- **5-class ensemble** → “Which label?” (OCA, OPMD, Benign, Healthy, Unknown) for explanation and UX.

### Combining the two (matrix)

Use **binary ensemble** for the **referral decision** (cancer vs non-cancer). Use **5-class ensemble** for the **display label** and to handle edge cases.

| Binary ensemble | 5-class ensemble | Show to user |
|-----------------|------------------|---------------|
| Non-cancer      | Benign / Healthy | “Low risk: Benign” or “Low risk: Healthy” |
| Non-cancer      | OCA / OPMD       | “Low risk” but add note: “Detailed label: OCA/OPMD – consider follow-up” (disagreement) |
| Cancer          | OCA / OPMD       | “Refer: OCA” or “Refer: OPMD” (agree) |
| Cancer          | Benign / Healthy | “Refer: follow-up recommended” + 5-class label (disagreement; prefer binary for referral) |
| *               | Unknown          | “Unclear – consider follow-up” + binary result |

Optional refinements:

- If **both** say cancer → strong “Refer” and show 5-class label.
- If **binary says cancer, 5-class says Healthy/Benign** → show “Refer recommended” and “Model detail: Benign/Healthy” so the user and clinician see the disagreement.
- Confidence: you can show binary probability (cancer) and 5-class confidence side by side.

This keeps the **referral rule** simple (binary ensemble) while still surfacing the **richer label** (5-class) and making disagreements visible.

---

## File / asset layout (suggested)

- **5-class ensemble** (existing): `assets/ensemble_model_1.onnx`, `ensemble_model_2.onnx`, `ensemble_model_3.onnx`.
- **Binary ensemble** (new): e.g. `assets/binary_ensemble/ensemble_model_1.onnx`, `ensemble_model_2.onnx`, `ensemble_model_3.onnx` (or same names in a different folder).
- App loads both; runs same preprocessing (224×224, ImageNet norm) for each; then applies the matrix above for the final result.

---

## Summary

- **Yes**, a second ensemble trained on the merged binary dataset can improve binary accuracy and is worth building.
- **Steps**: Train 3 PyTorch binary models on merged data (same splits as binary merged notebook) → export to ONNX (num_classes=2) → evaluate with `binary_onnx_ensemble` on T5/TB/TM.
- **App**: Binary ensemble = “cancer or not”; 5-class ensemble = “better label”; use the matrix above to show a single, clear result to the user while still exposing both predictions when useful.
