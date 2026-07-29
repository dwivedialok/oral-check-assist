# Patient-Wise Dataset and Model Development

**Version:** 1.0  
**Target Audience:** Collaborators - AI/ML Engineers

This document serves as the reference for the creation, experimentation, and results of the **Patient-Wise** dataset splitting strategy. It compliments the root `MODEL_DEVELOPMENT_AND_USAGE.md` by explicitly documenting the transition from image-wise splits to strict patient-wise stratification, mitigating data leakage, and establishing a true clinical baseline.

---

## 1. Problem Statement & Dataset Strategy

The original splits for the `T5` (Sri Lankan) and `SMART-II` datasets were performed using random **image-wise** sampling. Because an individual patient often has multiple photos taken of their oral cavity, this allowed images of the *same* patient to appear in both the training set and the test set. 
As a result, a model could implicitly learn to recognize unique patient anatomical features (lip shape, specific lighting, teeth configurations) rather than generalizing strictly to the pathology, leading to heavily inflated test metrics.

### Datasets and Notebooks Used

To resolve this, we reconstructed the datasets strictly by **Patient Demographic ID** via `GroupShuffleSplit`:

- **T5_patientwise (5-Class Dataset)**: 
  - Restructured into mutually exclusive patient buckets (Train / Val / Test).
  - *Setup Notebook*: `ml/training/notebooks/rebuild_T5_dataset_patientwise.ipynb`
  - *Add-on*: Used `copy_unknown_class.ipynb` to accurately migrate non-oral 'Unknown' samples.
- **SMART-II_patientwise**: 
  - Restructured by patient ID and manually mapped to aligned 5-class target labels (`Healthy`, `Benign`, `OPMD`).
  - *Setup Notebook*: `ml/training/notebooks/rebuild_SMART_dataset_patientwise.ipynb`
- **TB & TC**: 
  - Since these are physically distinct holdout datasets (gathered from different clinics), their original 15% random splits were retained identically to preserve comparability.

### Aggregation Mechanism
- *Script*: `ml/training/notebooks/frozen_test_sets.py` (Version 3)
- Contains the new `build_and_save_frozen_sets_v3()` pipeline which unions `T5_patientwise`, `SMART-II_patientwise`, `TB`, and `TC` to create a master frozen test slice (`TM_v3`) strictly free of data leakage.

---

## 2. Retraining Experiments

Using the best-performing freeze strategy from previous iterations (`progressive_K5`), we trained new ensembles exclusively on the patient-wise pooled training manifests.

- **Binary Ensemble** (`train_binary_ensemble_patientwise.ipynb`): 
  - Fuses the labeled train/val images from `T5_patientwise`, `SMART-II_patientwise`, `TB`, and `TC`.
  - Maps to ` Cancer (1) / Non-Cancer (0)`.
- **5-Class Ensemble** (`train_5class_ensemble_patientwise.ipynb`): 
  - Fuses the labeled train/val images exclusively from `T5_patientwise` and `SMART-II_patientwise`.

---

## 3. Results and Comparisons

A unified comparison was conducted across three distinct generations of models. 
- *Evaluation Notebook*: `ml/training/notebooks/compare_models_patientwise.ipynb`

The comparison ran strict ONNX model inference against the `TM_v3` test master array. 
**Evaluated Models**:
1. `*_Production`: Original heavily fine-tuned model (image-wise split).
2. `*_Prev_ProgK5`: Progressive K5 model on old datasets (image-wise split).
3. `*_PatientWise`: New Progressive K5 models on strict patient-wise data.

### Source-Level AUC Comparison

| Model | Source: SMART-II | Source: T5 | Source: TB | Source: TC | Max_AUC_Gap |
|-------|------------------|------------|------------|------------|-------------|
| Binary_Prev_ProgK5 | nan* | 0.9769 | 0.9836 | 0.9983 | 0.0215 |
| Binary_Production | nan* | 0.9782 | 0.9800 | 1.0000 | 0.0218 |
| 5Class_Production | nan* | 0.9881 | 0.8031 | 1.0000 | 0.1969 |
| **5Class_PatientWise** | nan* | **0.7714** | 0.5655 | 0.5933 | 0.2059 |
| **Binary_PatientWise** | nan* | **0.7743** | **0.9920** | **0.9500** | 0.2178 |
| 5Class_Prev_ProgK5 | nan* | 0.9858 | 0.7629 | 1.0000 | 0.2371 |

*\*Note: `nan` for SMART-II occurs if the randomly selected test subset does not contain both positive and negative cases (e.g., only Normal/Benign), making an AUC calculation mathematically impossible.*

### Sensitivity at Target Specificity (TM_v3 Overall)

| Model | Target Spec | Sensitivity | Achieved Spec | Threshold |
|-------|-------------|-------------|---------------|-----------|
| Binary_PatientWise | 0.80 | 0.831 | 0.801 | 0.751 |
| Binary_PatientWise | 0.90 | 0.699 | 0.902 | 0.929 |
| 5Class_PatientWise | 0.80 | 0.506 | 0.801 | 0.569 |
| 5Class_PatientWise | 0.90 | 0.419 | 0.901 | 0.687 |

---

## 4. Analysis and Significance

### 1. The Definitive Proof of Data Leakage
The older image-wise models (`Production` and `Prev_ProgK5`) achieved near-perfect **0.97 - 0.98 AUC** on the T5 test subset. However, shifting to a strict patient boundary caused the `PatientWise` models to drop to **~0.77 AUC** on T5. 
This definitively proves the previous models were "cheating"—they were memorizing specific patient anatomical features during training and recognizing them during testing, severely inflating the previous accuracy figures.

### 2. Establishing the True Baseline
The **0.77 AUC** (supported by an 83.1% Sensitivity at 80.1% Specificity across the `TM_v3` pool) constitutes the **true, un-leaked real-world generalizability** baseline for an unseen patient on the Sri Lankan (T5) distribution. Having this mathematically honest metric allows for valid research iterations (e.g., Self-Supervised Learning) going forward.

### 3. High Performance on External Holdouts
The `Binary_PatientWise` model retained excellent AUC on the `TB` (0.992) and `TC` (0.950) distributions. Because these datasets are physically separate from T5/SMART-II, they never suffered from single-patient leakage. The fact that the new model still performs flawlessly on them indicates that the core oncology classification logic is intact and robust across clinics.

### 4. 5-Class Out-of-Domain Failure
The 5-Class models perform poorly on the `TB` and `TC` sources (0.56 - 0.80 AUC). This is an expected side-effect of domain shift: the 5-Class training pool *only* contains T5 and SMART-II datasets. The models have never seen the lighting, equipment, or annotation types from TB and TC, limiting their generalizability to those domains.

---

## 5. SSL-Enhanced Backbone (Dental Caries + TM_v3 Unlabeled) vs ImageNet Backbone

We trained a new backbone using the pipeline:
- `ImageNet MobileNetV3-Large -> SSL pretraining on (Dental Caries + TM_v3 unlabeled train pool) -> supervised TM_v3 binary fine-tuning`.
- Notebook: `ml/training/notebooks/ssl_caries_tmv3_pretrain_then_finetune.ipynb`
- Evaluation artifact: `ml/training/notebooks/results/ssl_caries_tmv3/ssl_caries_tmv3_20260302_195212/evaluation_tm_v3_by_strategy.json`

### SSL Backbone: TM_v3 Key Metrics

| Strategy | TM_v3 AUC | Accuracy @ thr=0.5 | Sensitivity @ thr=0.5 | Specificity @ thr=0.5 |
|----------|-----------|--------------------|------------------------|------------------------|
| full_finetune | **0.9096** | 0.5996 | 0.0000 | 1.0000 |
| progressive_K5 | 0.8925 | 0.5996 | 0.0000 | 1.0000 |

### SSL Backbone: Sensitivity at Target Specificity

| Strategy | Target Spec | Sensitivity | Achieved Spec | Threshold |
|----------|-------------|-------------|---------------|-----------|
| full_finetune | 0.80 | **0.8652** | 0.8011 | 0.1634 |
| full_finetune | 0.90 | **0.7416** | 0.9024 | 0.2048 |
| progressive_K5 | 0.80 | 0.7725 | 0.8049 | 0.2371 |
| progressive_K5 | 0.90 | 0.6489 | 0.9024 | 0.2760 |

### Comparison to Existing ImageNet Patient-Wise Baseline (Binary_PatientWise)

| Backbone / Strategy | Target Spec | Sensitivity | Achieved Spec |
|---------------------|-------------|-------------|---------------|
| ImageNet baseline (`Binary_PatientWise`) | 0.80 | 0.8310 | 0.8010 |
| SSL backbone + full_finetune | 0.80 | **0.8652** | 0.8011 |
| SSL backbone + progressive_K5 | 0.80 | 0.7725 | 0.8049 |
| ImageNet baseline (`Binary_PatientWise`) | 0.90 | 0.6990 | 0.9020 |
| SSL backbone + full_finetune | 0.90 | **0.7416** | 0.9024 |
| SSL backbone + progressive_K5 | 0.90 | 0.6489 | 0.9024 |

### Interpretation

1. With the SSL-enhanced backbone, `full_finetune` is now the strongest binary strategy on TM_v3.
2. At clinically relevant operating points (80% and 90% specificity), SSL + `full_finetune` improves sensitivity over the existing ImageNet patient-wise baseline.
3. The default threshold (`0.5`) is not usable here (all-negative predictions); deployment must use operating-point threshold calibration (e.g., thresholds near `0.16-0.20` for this run).

---

## 6. SSL-Backbone Patient-Wise Ensembles on TM_v3

Using the SSL-pretrained MobileNetV3 backbone from Section 5, we trained three **patient-wise ensembles** on the pooled train/val data and evaluated them on the frozen `TM_v3` test master:

- Notebook: `ml/training/notebooks/ssl_multitask_ensembles_patientwise.ipynb`
- All metrics below are computed in **binary view** on TM_v3 (Cancer vs Non-Cancer), consistent with prior sections.

### 6.1 Binary SSL Ensemble (Patient-Wise)

**TM_v3 overall (threshold = 0.5):**

| Metric | Value |
|--------|-------|
| AUC | **0.9202** |
| Accuracy | 0.8144 |
| Sensitivity | 0.8174 |
| Specificity | 0.8124 |

**Sensitivity at target specificity (TM_v3 overall):**

| Target Spec | Sensitivity | Achieved Spec | Threshold |
|-------------|-------------|---------------|-----------|
| 0.80 | **0.8315** | 0.8011 | 0.4735 |
| 0.90 | **0.7416** | 0.9006 | 0.7128 |

These results closely match the original ImageNet `Binary_PatientWise` baseline at 80% specificity, while improving sensitivity at 90% specificity (from ~0.70 → ~0.74).

### 6.2 5-Class SSL Ensemble (Patient-Wise, Binary View: OCA ∪ OPMD vs Others)

**TM_v3 overall (threshold = 0.5):**

| Metric | Value |
|--------|-------|
| AUC | **0.7367** |
| Accuracy | 0.7222 |
| Sensitivity | 0.4494 |
| Specificity | 0.9043 |

**Sensitivity at target specificity (TM_v3 overall):**

| Target Spec | Sensitivity | Achieved Spec | Threshold |
|-------------|-------------|---------------|-----------|
| 0.80 | **0.5702** | 0.8049 | 0.3859 |
| 0.90 | **0.4607** | 0.9024 | 0.4962 |

Compared to the ImageNet `5Class_PatientWise` baseline, the SSL-backed 5-class ensemble improves sensitivity at both 80% and 90% specificity while maintaining similar achieved specificity.

### 6.3 3-Class SSL Ensemble (Patient-Wise, Binary View: OPMD_PLUS vs Others)

Here, `OPMD_PLUS` groups `OPMD ∪ OCA` into the positive class, mirroring the 3-class training objective.

**TM_v3 overall (threshold = 0.5):**

| Metric | Value |
|--------|-------|
| AUC | **0.7280** |
| Accuracy | 0.6929 |
| Sensitivity | 0.4101 |
| Specificity | 0.8818 |

**Sensitivity at target specificity (TM_v3 overall):**

| Target Spec | Sensitivity | Achieved Spec | Threshold |
|-------------|-------------|---------------|-----------|
| 0.80 | **0.5169** | 0.8068 | 0.3870 |
| 0.90 | **0.3933** | 0.9006 | 0.5359 |

While no prior patient-wise 3-class baseline exists for direct comparison, these results are broadly consistent with the 5-class SSL ensemble, and substantially below the binary SSL ensemble, reinforcing binary as the strongest deployment candidate.
