# SSL and Multitask Ensemble Pipeline for Oral Cavity Classification

**Target Audience:** AI/ML Engineers  
**Purpose:** Technical overview of the two-stage pipeline for developing a robust oral cancer classifier using domain-specific Self-Supervised Learning (SSL) and patient-wise multitask ensembles.

---

## 1. High-Level Pipeline Architecture

The development process is split into two distinct notebooks to isolate the domain-specific feature extraction from the supervised classification tasks.

1.  **Stage 1: SSL Pre-training (`ssl_caries_tmv3_pretrain_then_finetune.ipynb`)**
    * **Goal:** Adapt a generic ImageNet-trained backbone to the specific visual domain of oral pathology.
    * **Method:** SimSiam (Simple Siamese) representation learning on unlabeled dental and oral images.
2.  **Stage 2: Multitask Ensemble Training (`ssl_multitask_ensembles_patientwise.ipynb`)**
    * **Goal:** Fine-tune specialized ensembles for binary and multi-class clinical tasks.
    * **Method:** Supervised full fine-tuning using the SSL weights and strict patient-wise data stratification.

---

## 2. CNN Architecture: MobileNetV3-Large

The backbone for all models is **MobileNetV3-Large**, chosen for its balance of high accuracy and low latency on mobile hardware.

* **Backbone Structure:** 17 Sequential blocks including `InvertedResidual` and `Conv2dNormActivation` layers.
* **Attention Mechanism:** Utilizes Squeeze-and-Excitation (SE) blocks within the residual layers to recalibrate channel-wise feature responses.
* **Classifier Head:** A custom head consisting of `AdaptiveAvgPool2d`, `Dropout`, and two `Linear` layers (e.g., 960 → 256 → num_classes).
* **Parameters:** Approximately 3.2M total parameters (~2.97M backbone + ~247K head).

---

## 3. Stage 1: SimSiam SSL Pre-training

To bridge the domain gap between natural images (ImageNet) and clinical oral photography, we employ **SimSiam (Simple Siamese)** learning.

* **Unlabeled Pool:** Fuses images from the `oral-dental-caries-dataset` and the training pool of our primary oral pathology datasets (T5, SMART-II, etc.).
* **Mechanism:** The model processes two different augmented "views" of the same image through a shared encoder. A prediction MLP and a stop-gradient operation are used to prevent representational collapse while minimizing negative cosine similarity between the views.
* **Output:** A pre-trained encoder state dictionary (`ssl_backbone_state_dict.pth`) that has learned relevant low-level and mid-level features for oral tissue and pathology.

---

## 4. Stage 2: Multitask Ensembles & Patient-Wise Splits

The second stage transitions to supervised learning using the SSL-enhanced backbone.

### A. Data Integrity: Patient-Wise Stratification
To eliminate "memorization" of patient-specific anatomy (teeth, lip shape), we use **Patient Demographic IDs** via `GroupShuffleSplit`. This ensures that images from the same patient never appear in both the training and test sets, providing a true clinical generalizability baseline.

### B. Training Strategy: Full Fine-Tuning
While standard ImageNet backbones often require "Progressive Freezing" to prevent overfitting, our experiments show that the **SSL backbone combined with a full fine-tune** (making all 17 blocks trainable from epoch 1) provides the highest sensitivity.

### C. The Ensembles
We train three distinct ensembles, each using a 3-model "majority/weighted" architecture to improve robustness:
1.  **Binary:** Cancer (OCA/OPMD) vs. Non-Cancer (Healthy/Benign).
2.  **3-Class:** Healthy, Benign, and `OPMD_PLUS` (OCA ∪ OPMD).
3.  **5-Class:** Detailed clinical breakdown (Healthy, Benign, OPMD, OCA, Unknown).

---

## 5. Evaluation and Production Readiness

Models are evaluated against the **TM_v3 master frozen test set**.

* **Clinical Operating Points:** We specifically optimize for sensitivity at **80% and 90% specificity** to align with referral screening requirements.
* **Deployment:** The winning models are exported to **ONNX format** with dynamic batch axes, allowing for <100ms inference on-device in the mobile application.

---

## 6. Deployed App Assets (verified May 2026)

The Flutter app loads ONNX from `assets/`. Both deployed ensembles come from run **`ssl_multitask_ensembles_20260303_120722`** (`ssl_multitask_ensembles_patientwise.ipynb`).

| App file | Training ONNX | In git since |
|----------|---------------|--------------|
| `binary_ensemble_mode_{1,2,3}.onnx` | `binary_ssl_fullft_model_{1,2,3}.onnx` | commit `0e82dfc` |
| `ensemble_model_{1,2,3}.onnx` | `class5_ssl_fullft_model_{1,2,3}.onnx` | commit `1573cf4` (v0.1.11+17) |

**Checksum verification:** SHA256 of every file in `assets/` matches the corresponding file under  
`ml/training/notebooks/results/ssl_multitask_ensembles/ssl_multitask_ensembles_20260303_120722/onnx/` (see full hash table in `docs/MODEL_DEVELOPMENT_AND_USAGE.md` § Current Production Models).

**TM_v3 metrics** (patient-wise, no leakage — full tables in `docs/PATIENTWISE_MODEL_DEVELOPMENT.md` §6):

| Ensemble | AUC | Accuracy | Sens @ 80% spec | Sens @ 90% spec |
|----------|-----|----------|-----------------|-----------------|
| Binary SSL (referral) | 0.9202 | 0.8144 | 0.8315 (thr 0.4735) | 0.7416 |
| 5-class SSL (subtype; binary view on TM_v3) | 0.7367 | 0.7222 | 0.5702 | 0.4607 |

Canonical paths: `ml/training/notebooks/model_registry.py` (`BINARY_PRODUCTION_RUN` / `FIVECLASS_PRODUCTION_RUN`).
