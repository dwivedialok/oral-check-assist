# Binary-primary risk grading — design notes and PR2 validation requirements

This document captures the **engineering rationale**, **proposed change**, and **validation-set evidence required** before defaulting on a *binary-only* risk-grading mode for the screening pipeline. It is the engineering counterpart to the clinician-facing wording fixes shipped in PR1 (see `docs/APP_CLINICIAN_GUIDE.md` §3.3).

> **Scope.** This is not a model retrain. It is a **policy** change in the V2 dual-ensemble post-processing (`lib/services/model_inference_service.dart`) and a **threshold review** in `lib/services/screening_config.dart`. No ONNX weights move.

---

## 1. Today’s behaviour (baseline)

From the existing code paths (already covered in the clinician guide §3–§5; summarised here for self-containment):

| Layer | Decision | Driven by |
|---|---|---|
| **Per-photo Risk badge** (Low / Moderate / High) | `cancerProb` thresholds (0.4735, 0.65) | **Binary only.** 5-class label cannot upgrade or downgrade. |
| **Per-photo `oodUnclear` flag** | `5-class top == Unknown` AND `P(Unknown) > 0.6` | **5-class only**, but its only effect is to *exclude* the photo from aggregation (set badge to N/A). Cannot raise risk. |
| **Per-photo display label** | If `max 5-class < 0.5` → `Uncertain`; otherwise the 5-class top class | **5-class only.** Now displays as *“Awaiting clinical verification (Uncertain)”* (PR1) — no longer conflated with the OOD wording. |
| **Session screen-positive** | `maxScore ≥ 0.65` OR `hybridAvg ≥ 0.4735` over usable photos | **Binary only.** |
| **Session outcome** | `reviewRecommended` / `retakeSuggested` / `lowRisk` | Binary score + quality + count rules. |
| **Session Risk Level** (Moderate vs **High**) | Within `reviewRecommended`: `subtypeGuidance == ocaDominant` → High, else Moderate | **5-class subtype.** This is the residual lever where 5-class can move the headline result. |
| **Session Urgency** (Prompt vs **Urgent**) | Same as above — `ocaDominant` → Urgent | **5-class subtype.** |
| **Final communicated risk** | `aiRisk` × `eriLevel` matrix | AI risk and tobacco exposure. ERI never downgrades. |

The binary model is therefore already the sole authority for *“refer or not”*. The 5-class model only differentiates **Moderate vs High** and **Prompt vs Urgent** *within* the referral branch.

## 2. Why we want to change it (and what we are NOT doing)

### What clinicians reported
- *“Camera quality 99 % but the app says image unclear.”* → Wording fix. **Shipped in PR1**: `Uncertain` and `Unknown` now produce different user-facing strings (`lib/l10n/l10n_extensions.dart::classLabelFriendly`).
- *“Confidence 28 % alongside HIGH RISK is confusing.”* → Wording fix. **Shipped in PR1**: the metric is now displayed as *“Label confidence”* in the PDF and detailed results to make its scope explicit (top aggregated 5-class probability, not screening confidence).
- *“The detail model is the noisiest piece — why does it move the headline?”* → **PR2** addresses this.

### PR2 proposal in one sentence
Add a single config flag — `binaryOnlyRiskGrading` — that, when on, causes session **Risk Level** and **Urgency** to be derived purely from binary scores (ignoring 5-class subtype dominance). Subtype text remains visible as informational context in the report.

### Things we are NOT doing in PR2
- Not retraining the binary or 5-class models.
- Not changing `binaryScreeningThreshold` (0.4735) — this is the calibrated ~80 % specificity operating point; moving it changes the screen-positive *rate* of the entire app.
- Not changing the OOD path (`oodUnknownThreshold`, `Unknown` exclusion). That is a legitimate use of the 5-class model.
- Not removing subtype wording. OCA-dominant / OPMD-dominant / benign-dominant text continues to render as informational context. Only its **lifting power** on Risk and Urgency is removed under the flag.
- Not touching the ERI matrix (`lib/services/eri_service.dart`). Tobacco-driven elevation Moderate → High remains as today.

## 3. What changes in code (preview)

In `lib/services/screening_config.dart`:

```dart
/// When true, session Risk Level and Urgency follow binary scores only.
/// 5-class subtype guidance becomes informational text in the report.
static const bool binaryOnlyRiskGrading = false; // default off until validated
```

In `lib/services/model_inference_service.dart`, replace the subtype-driven branch in `outcomeToRiskLevel` and `outcomeToUrgency` with a binary-band rule when the flag is on. The rule reuses **`maxScore`** from the same hybrid aggregation already computed:

| Condition (when flag is on) | Risk Level | Urgency |
|---|---|---|
| `outcome == lowRisk` | Low | Routine |
| `outcome == retakeSuggested` | Moderate | Retake |
| `outcome == reviewRecommended` AND `maxScore ≥ highConfSingleViewThreshold` | High | Urgent |
| `outcome == reviewRecommended` AND `maxScore < highConfSingleViewThreshold` | Moderate | Prompt |

Note that `aggregateResults` already computes and logs `maxScore`; we just need to plumb it into the mapping. No new aggregation passes.

After the flag flip, an OCA-dominant 5-class signal will only matter if **the binary score also lands ≥ `highConfSingleViewThreshold` on at least one usable photo**. That is the correctness contract we need to validate.

---

## 4. Validation-set evidence required before flipping the default

We need to answer **two empirical questions** before defaulting `binaryOnlyRiskGrading` to `true`:

1. **Sensitivity preservation.** Does the new rule keep the same *proportion of ground-truth-positive sessions* labelled **High Risk + Urgent** as the current rule? The clinical concern is *“we don’t want to drop OCA cases from High → Moderate”*.
2. **Threshold sufficiency.** Is the current `highConfSingleViewThreshold = 0.65` still the right cut-point under the new rule, or should it be lowered (e.g. 0.55) to compensate for losing the OCA-dominance lever?

The dataset for these answers is **TM_v3** — the internal pooled, **patient-wise-frozen** test set referenced throughout `docs/PATIENTWISE_MODEL_DEVELOPMENT.md` and §8 of the clinician guide. No new data collection is required.

### 4.1 Required artefacts

For every session in TM_v3 (where a “session” = one patient’s set of photos):

| Field | Source | Why we need it |
|---|---|---|
| `session_id`, `patient_id` | dataset metadata | Patient-wise grouping; sanity check that no patient appears twice. |
| `ground_truth` ∈ {Healthy, Benign, OPMD, OCA} | dataset labels | The target. OPMD ∪ OCA = clinical positive (the binary label). |
| `binary_scores[]` per photo | run binary ensemble on each photo | To compute `maxScore` and `hybridAvg`. |
| `five_class_probs[]` per photo | run 5-class ensemble on each photo | To compute `subtypeGuidance` under current rule. |
| `quality_score` per photo | `PhotoQualityService.assessQuality` | To honour the existing usability gate (`qualityMin = 0.5`). |
| `current_rule_outcome` | `aggregateResults` with current code | Risk Level + Urgency under today’s policy. |
| `proposed_rule_outcome` | `aggregateResults` with proposed branch | Risk Level + Urgency under PR2 policy. |

Run with the **existing** thresholds first. Only after we see the metrics below should we re-run sweeping `highConfSingleViewThreshold` ∈ {0.50, 0.55, 0.60, 0.65, 0.70, 0.75}.

### 4.2 Metrics required (per rule, plus deltas)

For each of the two rules (current vs proposed), compute the following on TM_v3:

#### Sensitivity / specificity at session level
- **Sensitivity (Se)** for *referral* = P(`screenPositive` | ground_truth ∈ {OPMD, OCA}). Note: this should be **identical** between the two rules — the referral decision is binary-only in both. If they differ, there is a code defect, not a policy difference. *Sanity check.*
- **Sensitivity for High Risk** = P(`riskLevel == High` | ground_truth == OCA). **This is the headline number.** A drop > 5 percentage points absolute under the proposed rule is the threshold at which we’d want to lower `highConfSingleViewThreshold`.
- **Sensitivity for OPMD-as-Moderate-or-High** = P(`riskLevel ∈ {Moderate, High}` | ground_truth == OPMD). Should be unaffected; it’s already binary-driven via the screen-positive path.
- **Specificity for High Risk** = P(`riskLevel != High` | ground_truth == Healthy). We want this **non-decreasing** under the proposed rule (i.e. fewer false High labels, or at worst the same).

#### Confusion matrices at session level
- 3×N matrix: predicted `riskLevel` (Low / Moderate / High) × ground_truth (Healthy / Benign / OPMD / OCA), under each rule.
- 4×N matrix: predicted `urgencyLevel` (Routine / Retake / Prompt / Urgent) × ground_truth.

#### Disagreement audit (current ≠ proposed)
For every TM_v3 session where the two rules disagree, dump:
- Patient ID, ground truth, photo count, photo-by-photo (`binary_score`, `quality`, top 5-class).
- `maxScore`, `hybridAvg`, current `subtypeGuidance`, current Risk, proposed Risk.

Group these by ground-truth class. We expect the disagreement pile to be dominated by **OCA-dominant + low maxScore** sessions (where current rule says High via subtype, proposed rule says Moderate). Those are exactly the cases the threshold sweep is meant to recover.

#### Threshold sweep table (proposed rule only)
For each candidate `highConfSingleViewThreshold` in {0.50, 0.55, 0.60, 0.65, 0.70, 0.75}, report:

| Threshold | Se(High \| OCA) | Sp(High \| Healthy) | Se(High \| OPMD) | Net High-rate | Net Urgent-rate |
|---|---|---|---|---|---|

“Net rate” = fraction of all TM_v3 sessions assigned to that bucket. Helps quantify operational impact (clinic visit volume).

### 4.3 Acceptance criteria for flipping the default to `true`

Default the flag on **only if all of these hold** on TM_v3:

1. Referral Se is **identical** between the two rules (sanity).
2. Se(`High` | OCA) under the proposed rule, evaluated at the chosen `highConfSingleViewThreshold`, is **≥ Se(`High` | OCA) − 0.02 (absolute)** under the current rule. (i.e. we accept at most 2 pp drop in OCA→High recall.)
3. Sp(`High` | Healthy) under the proposed rule **does not decrease**.
4. The disagreement audit shows no OCA-positive session moving from High → Low. (High → Moderate is acceptable; High → Low is not.)
5. The Net Urgent-rate change is within the operationally agreed band (define with clinical leads — typically ±20 % relative).

If criterion 2 cannot be met at any threshold ≥ 0.5, **do not flip the default**. Instead, ship PR2 with the flag default `false` and treat it as an opt-in for evaluation builds, while a model-side improvement (TTA, calibration, retraining) is planned.

### 4.4 Reproducibility

Add a script `scripts/eval_binary_primary_risk_grading.dart` (or `ml/eval_*.py`, whichever is the team’s convention) that:
- Loads TM_v3 once.
- Runs both rules through `aggregateResults` (the proposed branch behind the flag — easy because the flag is read at decision time).
- Emits `validation_results_<git_sha>.csv` with one row per session and the columns above.
- Emits the metric summary as a markdown table for the PR2 description.

Pin the script behaviour to a specific `ScreeningConfig` snapshot so re-runs after future threshold changes are comparable. The CSV should also include `binaryScreeningThreshold` and `highConfSingleViewThreshold` as columns to make sweeps inspectable.

---

## 5. Rollout plan

1. **PR1 (this PR).** Wording-only fixes — `Uncertain` ≠ `Unknown` user-facing text, *“Confidence”* renamed to *“Label confidence”* in the PDF and detailed results. No risk math changed. ✅
2. **PR2a.** Add `binaryOnlyRiskGrading` flag (default `false`), refactor `outcomeToRiskLevel` and `outcomeToUrgency` to consult the flag. Existing tests remain green; add new tests covering the new branch (toggle the flag, assert Risk and Urgency follow `maxScore`).
3. **PR2b — gated on validation evidence.** Run the script in §4.4, capture the four tables in §4.2, attach to the PR. If §4.3 acceptance criteria are met, flip the default to `true`. Otherwise leave default `false` and document next-step model work.
4. **Optional follow-up PR.** Replace the “Label confidence” headline in the PDF with a **binary-derived** confidence proxy (e.g. `|2·maxScore − 1|` or `1 − 2·|maxScore − 0.5|`) so the headline percentage matches the screening intuition. Out of scope for PR2.

## 6. Out-of-scope but worth noting

- **Calibration of `maxScore`.** Today’s binary score is treated as a probability but isn’t calibrated against ground-truth prevalence in the deployment population. Temperature scaling on TM_v3 would yield a more honest Screening Risk Score. Independent of PR2.
- **Test-time augmentation (TTA) on the 5-class model.** Would raise *Label confidence* on most photos and reduce the rate of `Uncertain` rewrites — but this is a model-side change requiring a re-export, not a config flag.
- **Capture-time content-aware quality.** Running a small OOD head at capture time (instead of waiting for the analysis batch) would prevent the “captured 99 % quality, marked Unknown post-hoc” class of complaints entirely. Separate UX-engineering ticket.

---

## 7. Cross-references

- Clinician-facing wording rules: `docs/APP_CLINICIAN_GUIDE.md` §3.3 (matrix), §3.3.1 (Uncertain vs Unknown), §3.3.2 (Label confidence vs other confidences).
- Threshold reference table: `docs/APP_CLINICIAN_GUIDE.md` §8.
- Patient-wise dataset and TM_v3 split definition: `docs/PATIENTWISE_MODEL_DEVELOPMENT.md`.
- Code touchpoints: `lib/services/screening_config.dart`, `lib/services/model_inference_service.dart` (`_buildV2Result`, `aggregateResults`, `outcomeToRiskLevel`, `outcomeToUrgency`), `lib/l10n/l10n_extensions.dart` (`classLabelFriendly`).
