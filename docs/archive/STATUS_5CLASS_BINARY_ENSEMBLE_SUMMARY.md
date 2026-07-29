# Status: 5-Class vs Binary Ensemble (Mobile App)

**Last updated:** Feb 2026

---

## 1. What the app actually uses

The mobile app runs **dual ensemble**: both **binary ensemble** and **5-class ensemble** on every photo.

- **Binary ensemble** → referral decision (refer vs low risk) and base risk level (low / moderate / high).
- **5-class ensemble** → fine label (Healthy, Benign, OPMD, OCA, Unknown) and probabilities.
- **Matrix** combines them: 5-class can **elevate** risk (OPMD → at least Moderate; OCA → High) and drives display label + disagreement note.

Assets:

- **5-class:** `assets/ensemble_model_1/2/3.onnx` (weights 0.30, 0.40, 0.30).
- **Binary:** `assets/binary_ensemble/ensemble_model_1/2/3.onnx`.

---

## 2. Accuracy, sensitivity, specificity (frozen sets T5, TB, TM)

All metrics below are on the **same frozen test sets** (T5 = 5-class test, TB = binary-only test, TM = mixed).

### 5-class ensemble (binary view: OCA+OPMD = positive)

| Set | n   | Accuracy | Sensitivity | Specificity |
|-----|-----|----------|-------------|-------------|
| T5  | 484 | 81.40%   | —           | —           |
| TB  | 246 | 74.39%   | —           | —           |
| **TM** | 730 | **79.04%** | **75.93%** | **82.39%** |

*Source: `ENSEMBLE_VS_BINARY_COMPARISON.md` / evaluate_on_frozen_sets (5-class ONNX ensemble).*

### Binary ensemble (used for referral in app)

| Set | n   | Accuracy | Sensitivity | Specificity |
|-----|-----|----------|-------------|-------------|
| T5  | 484 | 79.55%   | 79.59%      | 79.50%      |
| TB  | 246 | 93.09%   | 90.98%      | 95.58%      |
| **TM** | 730 | **84.11%** | **83.60%** | **84.66%**  |

*Source: `binary_ensemble_training.ipynb` (evaluation_frozen_T5_TB_TM.json).*

**Summary:** On the mixed set (TM), the **binary ensemble** is stronger (84% vs 79% accuracy; ~84% sens/spec). The 5-class ensemble is kept for **label** and **matrix elevation** (so OPMD/OCA never show as Low Risk when the detail model says otherwise).

---

## 3. Binary vs 5-class agreement on frozen sets

When both ensembles are run on the same images (binary: refer vs not; 5-class: suspicious OCA/OPMD vs not), agreement is:

| Set | Total | Agreed | Disagreed | Agreement % |
|-----|-------|--------|-----------|-------------|
| T5  | 484   | 407    | 77        | **84.1%**   |
| TB  | 246   | 184    | 62        | **74.8%**   |
| TM  | 730   | 591    | 139       | **81.0%**   |

- **T5:** 5-class test (in-distribution for 5-class); agreement highest.
- **TB:** Binary-only test; agreement lower (74.8%) — different source, different task calibration.
- **TM:** Overall ~81% agreement; the app shows a **disagreement note** when they disagree and uses the matrix so the **higher** risk wins.

---

## 4. Decision matrix (per photo)

| Binary (referral) | 5-class label     | Risk after matrix        | UI note |
|-------------------|-------------------|--------------------------|--------|
| Low risk          | Healthy / Benign  | Low                      | None   |
| Low risk          | OPMD              | **Moderate** (elevated)  | “Detailed label: OPMD – consider follow-up” |
| Low risk          | OCA               | **High** (elevated)      | “Detailed label: OCA – consider follow-up” |
| Refer             | OCA / OPMD        | High / Moderate by prob | None (agreed) |
| Refer             | Healthy / Benign  | Moderate / High by prob | “Refer recommended. Model detail: Healthy/Benign” |
| Any               | Unknown           | From binary              | “Unclear – consider follow-up. Binary result: …” |

Rules in code:

1. **Base risk** from binary: Low (no refer), Moderate (refer, P &lt; high threshold), High (refer, P ≥ threshold).
2. **Elevate:** If 5-class = OCA → risk at least **High**. If 5-class = OPMD and risk was Low → **Moderate**.
3. **Display label** = 5-class label.
4. **disagreementNote** when binary and 5-class disagree (e.g. binary low risk but 5-class OPMD/OCA).

---

## 5. How 5 photos are combined

- **Per photo:** Each of the 5 photos gets the **matrix output** above (risk level, binary referral, 5-class label, disagreement note).
- **Overall risk:** **max** of the 5 per-photo risk levels (so one High photo → overall High).
- **Probabilities:** **Weighted average** of 5-class probabilities across valid (oral) photos; weights from quality/validity.
- **Recommendations / specialist / urgency:** Derived from **overall risk** (the max).

So: one suspicious photo can drive “refer” and high overall risk; the rest soften only the probability distribution, not the final risk level.

---

## 6. Dataset and class distribution

### 5-class dataset (oral_cavity_5class_dataset)

Typical split (from notebooks):

| Class   | Train | Val | Test | Note |
|---------|-------|-----|------|------|
| OCA     | 216   | 35  | 36   | **Very small** (~287 total) |
| OPMD    | 975   | 209 | 209  | Largest cancer-related |
| Benign  | 656   | 128 | 129  | |
| Healthy | 510   | 109 | 110  | |
| Unknown | (varies) | | 50  | Excluded from binary metrics |

- **OCA is the smallest class** (order of magnitude fewer than OPMD). This drives lower per-class accuracy for OCA (e.g. ~65.71% in 5-class ensemble) and motivates class weights (e.g. OCA 1.5×) and more OCA data.

### Binary dataset (oral_cavity_binary_dataset)

- cancer: 884; non-cancer: 750 (total 1634).
- 15% holdout → **TB** (246 images); rest for train/val.

### Merged (for binary ensemble training)

- Cancer: 2564 (binary cancer + 5-class OCA+OPMD, deduped).
- Non-cancer: 2392.
- **TM** = T5 (binary-eligible, 484) ∪ TB (246) = 730 for comparable evaluation.

### Frozen set counts (meta)

- T5: 534 total (484 binary-eligible for TM).
- TB: 246.
- TM: 730.

---

## 7. Real-world challenges and role of more data

### Challenges

1. **Distribution shift:** Training is mostly **clinical / histopath-style** imagery; app input is **mobile or consumer camera** photos. Lighting, angle, resolution, and context differ → accuracy on “real” phone photos is unknown and likely lower than frozen-set numbers.
2. **Small OCA set:** Very few OCA images → model underrepresents true cancer; risk of missing OCA or over-relying on OPMD-like appearance.
3. **Binary vs 5-class disagreement:** ~19% of TM disagreements; different sources (T5 vs TB) and task design (referral vs fine label) → need clear UX (disagreement note, “consider follow-up”).
4. **Unknown class:** Unclear or non-oral images → “Unknown” and follow-up message; no large dedicated “real-world unknown” set.
5. **Generalization across devices:** Different phones/cameras and capture conditions not yet in training.

### How much can a larger dataset (mobile / decent camera) help?

- **Partially addressable:**
  - **Domain shift:** Adding a lot of **mobile/decent-camera oral photos** (with labels or referral outcomes) would directly improve robustness to real-world distribution and could narrow the gap between frozen-set metrics and field performance.
  - **OCA scarcity:** More OCA (and OPMD) from the same or similar acquisition settings would help per-class accuracy and referral sensitivity for cancer.
  - **Calibration:** More real-world data would improve probability calibration and threshold choices for “refer” vs “low risk.”
- **Not solved by data alone:**
  - **Inherent ambiguity:** Some lesions are borderline; disagreement between binary and 5-class (and between experts) will remain; the matrix + disagreement note is the right design.
  - **Device diversity:** Need ongoing diversity of devices and conditions in the dataset to keep generalizing.
- **Practical target:** A **larger, curated dataset of mobile/camera oral photos** (especially with OCA/OPMD and referral outcomes) is the single most impactful next step for real-world accuracy and trust.

---

## 8. One-line summary

**App:** Dual ensemble (binary + 5-class); binary drives referral and base risk; 5-class gives label and elevates risk (OPMD→Moderate, OCA→High); 5-photo result = **max risk** across photos + weighted-average 5-class probs. **Frozen TM:** binary ~84% acc (83.6% sens, 84.7% spec), 5-class ~79%; agreement ~81%. **OCA is very small** in the 5-class set; **real-world performance** is limited by clinical-vs-mobile distribution shift and can be improved most by **more mobile/camera oral photos** (especially OCA/OPMD and referral labels).
