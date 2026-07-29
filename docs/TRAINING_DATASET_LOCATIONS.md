# Training dataset locations

Reference for **on-disk paths** used when training patient-wise ensembles and **original sources** where those datasets were obtained. Canonical download URLs are taken from [MODEL_DEVELOPMENT_AND_USAGE.md](MODEL_DEVELOPMENT_AND_USAGE.md) (Dataset Distribution). Patient-wise layout and defaults are defined in `ml/training/notebooks/frozen_test_sets.py` and recorded in `ml/training/notebooks/frozen_test_sets/meta_v3.json`.

---

## 1. Original public sources (before patient-wise rebuilds)

| ID | Role | Canonical source URL | Notes |
| -- | ---- | -------------------- | ----- |
| **T5** | 5-class (Benign, Healthy, OCA, OPMD, Unknown) | [Zenodo record 10664056](https://zenodo.org/records/10664056) | Primary 5-class reference; “T5” in notebooks. |
| **TB** | Binary (cancer vs non-cancer) | [Kaggle: oral-cancer-images-for-classification](https://www.kaggle.com/datasets/muhammadatef/oral-cancer-images-for-classification) | External binary set; “TB”. |
| **TC** | Binary (cancer vs non-cancer) | [Mendeley: mhjyrn35p4/2](https://data.mendeley.com/datasets/mhjyrn35p4/2) | Small binary set; training uses `original_data/` only (see model dev doc). |
| **NEW_MINI_1** | Small / smoke-test | [Kaggle: oral-cancer-lips-and-tongue-images](https://www.kaggle.com/datasets/shivam17299/oral-cancer-lips-and-tongue-images) | Optional; not part of the standard patient-wise v3 training pool. |

**SMART-II:** The rebuild notebook describes the **AI Khosh SMART-II** dataset and uses a local tree under `oral-images-dataset/SMART-II-Dataset` (see `ml/training/notebooks/rebuild_SMART_dataset_patientwise.ipynb`). There is **no** canonical download URL in the markdown tables above; keep provenance with your internal copy of that release.

---

## 2. Typical local paths (this repo’s conventions)

Paths resolve under **`ORAL_DATA_ROOT`** (default `~/dev`) in `frozen_test_sets.py`. Example:

```bash
export ORAL_DATA_ROOT=/data/oral   # optional; otherwise ~/dev
```

Frozen JSON manifests under `ml/training/notebooks/frozen_test_sets/` may still contain absolute paths from the machine that last rebuilt them; training images are **not** shipped in git. Rebuild manifests locally after placing datasets under your data root.

### 2.1 Raw / unpacked archives (used by rebuild notebooks)

| Purpose | Example path | Linked source |
| -------- | ------------- | ------------- |
| Zenodo T5 unpacked | `~/dev/oral-images-dataset/zenodo_10664056_SriLankan` | T5 → Zenodo 10664056 |
| SMART-II unpacked | `~/dev/oral-images-dataset/SMART-II-Dataset` | SMART-II (local; see §1) |

### 2.2 Image-wise defaults (legacy; older `frozen_test_sets` v1/v2)

| Variable / role | Default path |
| ----------------- | ------------ |
| `DEFAULT_DATA_DIR_5CLASS` | `~/dev/oral_cavity_5class_dataset` |
| `DEFAULT_DATA_DIR_BINARY` | `~/dev/oral_cavity_binary_dataset` |
| `DEFAULT_DATA_DIR_SMALL_BINARY` | `~/dev/oral-images-dataset/Oral-Image-small-binary-dataset` |

### 2.3 Patient-wise training roots (v3; current patient-wise ensembles)

| Variable / role | Default path |
| ----------------- | ------------ |
| `DEFAULT_DATA_DIR_5CLASS_PATIENTWISE` | `~/dev/oral_cavity_5class_dataset_patientwise` |
| `DEFAULT_DATA_DIR_SMART_PATIENTWISE` | `~/dev/oral_cavity_smart_ii_patientwise` |

**Frozen-set builder** (`build_and_save_frozen_sets_v3`) reads the patient-wise T5 and SMART paths above, plus binary TB at `~/dev/oral_cavity_binary_dataset` and TC at `~/dev/oral-images-dataset/Oral-Image-small-binary-dataset`. Exact paths from the last committed build are in `ml/training/notebooks/frozen_test_sets/meta_v3.json`.

---

## 3. What each training notebook uses

| Training | Notebook | Data locations |
| -------- | ---------- | -------------- |
| **Binary ensemble (patient-wise)** | `ml/training/notebooks/train_binary_ensemble_patientwise.ipynb` | Merged pool from `get_all_train_val_for_training_v3`: TB train/val manifest (`binary_train_val_for_training.json`), TC train/val manifest (`small_binary_train_val_for_training.json`), **T5 patientwise** `train/`/`val/` (binary labels; Unknown excluded), **SMART patientwise** `train/`/`val/` (Benign, Healthy, OPMD → binary). |
| **5-class ensemble (patient-wise)** | `ml/training/notebooks/train_5class_ensemble_patientwise.ipynb` | **`oral_cavity_5class_dataset_patientwise`** — all 5 classes in `train/`/`val/`; **`oral_cavity_smart_ii_patientwise`** — Benign, Healthy, OPMD only in `train/`/`val/`. TB/TC are **not** used for 5-class training. |

Setup notebooks: `rebuild_T5_dataset_patientwise.ipynb`, `rebuild_SMART_dataset_patientwise.ipynb`. Broader context: [PATIENTWISE_MODEL_DEVELOPMENT.md](PATIENTWISE_MODEL_DEVELOPMENT.md).

---

## 4. Related docs

- [MODEL_DEVELOPMENT_AND_USAGE.md](MODEL_DEVELOPMENT_AND_USAGE.md) — full dataset descriptions, splits, and frozen-test behavior.
- [PATIENTWISE_MODEL_DEVELOPMENT.md](PATIENTWISE_MODEL_DEVELOPMENT.md) — patient-wise strategy and evaluation.
