# Screening Model: Calculation Reference

---

## 1. Overall Assessment (Screening Decision)

Driven **only by the binary model** (no 5-class override).

### Per Photo
Each usable photo has a **Screening Risk Score** = binary model output (probability of abnormal).

> **Usable** = oral, analyzed, quality ≥ qualityMin (0.5).

### Patient-Level Binary Rule (Hybrid)

Over all usable photos:

- `maxScore` = max of those binary scores
- `secondScore` = second highest
- `hybridAvg` = (maxScore + secondScore) / 2

**Then:**

| Condition | Result |
|-----------|--------|
| `maxScore ≥ 0.65` | Screen **positive** (single strong view is enough) |
| `hybridAvg ≥ 0.4735` | Screen **positive** |
| Otherwise | Screen **negative** |

### Screening Outcome

- **Screen positive** → *Review recommended*
- **Screen negative** → then check retake band (e.g. hybridAvg in [0.45, 0.50)), low quality, or too few photos → *Retake suggested*, else *Low risk*

### What You See as "Overall Assessment"

- **Title/message** (e.g. *"Moderate to High Risk – Specialist Review Recommended"*) comes from screening outcome + subtype (see below).
- **AI Image Risk** in the Risk Summary = `overallRisk` from this flow (low / moderate / high).
- **Final recommendation** can be elevated by ERI (exposure risk); e.g. AI moderate + exposure high → final "High risk".

> **Summary:** Overall assessment is the binary-based screening outcome (and ERI if present), not a direct average of per-photo labels.

---

## 2. Label Confidence (e.g. "50.0% (OPMD)")

**Source:** The aggregated 5-class probabilities used for the session-level summary.

### When Screen Positive
Only 5-class results from **abnormal photos** are aggregated — those with binary score ≥ 0.4735. So "label confidence" is based only on photos that triggered referral from the binary model.

### When Screen Negative
5-class results from **all usable photos** are aggregated (for the "borderline" note and the single summary).

### Aggregation

For the chosen set (positive-only or all), each photo's 5-class vector is taken:

```
[benign, healthy, oca, opmd, unknown]
```

**Weight per photo** = `qualityScore × (0.6 × confB + 0.4 × conf5)`, where:

- `confB` = `|binaryScore − 0.5| × 2`
- `conf5` = max of that photo's 5-class probs

Weights are normalized to sum to 1, then a weighted average of the 5-class vectors is taken across the set → one **aggregated 5-class distribution** for the session.

### Label Confidence and "(OPMD)"

- **Label confidence** = `effectiveClassProbs.confidence` = max of that aggregated distribution (e.g. 0.50)
- **(OPMD)** = `predictedClass` = the class with that max (e.g. OPMD)

> **Example:** "50.0% (OPMD)" means: in the aggregated 5-class distribution (over abnormal photos when screen positive), the highest probability is 50% and it belongs to the OPMD class.

---

## 3. Urgency (e.g. "Prompt (1–2 weeks)")

**Source:** Screening outcome + subtype guidance (no separate "urgency model").

| Outcome | Urgency |
|---------|---------|
| Low risk | Routine (2–4 weeks) |
| Retake suggested | Retake photos |
| Review recommended + subtype = OCA dominant | Urgent (within 1 week) |
| Review recommended + subtype = OPMD dominant, benign dominant, or none | Prompt (1–2 weeks) |

> Urgency is **not** computed from a score — it is a fixed mapping from (outcome, subtype).

---

## 4. Class Probabilities (the Four Bars: Healthy, Benign, OPMD, OCA)

Uses the **same aggregated 5-class distribution** as label confidence:

| Bar | Source |
|-----|--------|
| Healthy | aggregated `healthy` |
| Benign | aggregated `benign` |
| OPMD | aggregated `opmd` |
| OCA | aggregated `oca` |

> *Note: `unknown` is not shown in the UI bars.*

**When screen positive**, the bars are the weighted average of 5-class outputs only from **abnormal photos** (binary ≥ 0.4735).

**When screen negative**, they are the weighted average over **all usable photos**.

The weight formula is the same as above (`quality × (0.6 × confB + 0.4 × conf5)`), so photos with clearer binary and 5-class signals count more. This is why you can see something like 50% OPMD in the overall class probabilities even when only some photos are OPMD — it's the weighted mix over the qualifying set that drives the summary.

---

## 5. Summary Table

| Item | How It's Calculated |
|------|---------------------|
| **Screening decision** | Binary only: max and second-highest binary score across all usable photos → hybrid rule (0.65 / 0.4735) → screen positive/negative → outcome (low risk / retake / review) |
| **Overall assessment title/message** | Outcome + subtype (e.g. *"Moderate to High Risk – Specialist Review Recommended"* for review + OPMD) |
| **AI Image Risk** | `overallRisk` = outcome + subtype (e.g. review + OPMD → moderate; review + OCA → high) |
| **Final recommendation** | Can be raised by ERI (exposure risk); otherwise same as AI image risk |
| **Label confidence (e.g. 50.0% (OPMD))** | From aggregated 5-class over abnormal photos (if screen positive) or all photos (if screen negative). Confidence = max of that distribution; (OPMD) = class with that max |
| **Urgency** | From outcome + subtype: low risk → routine; retake → retake; review + OCA → urgent; review + other → prompt |
| **Class probabilities (bars)** | Same aggregated 5-class distribution (healthy, benign, opmd, oca) used for label confidence |

---

## 6. Session-Level Disagreement Suppression

When screen-positive but the aggregated 5-class label is **Healthy** or **Benign** (non-concerning), the `benignDominant` subtype guidance is suppressed to `none`. This prevents confusing displays like "Lesion Detected" with "50.4% (Benign)" in a screen-positive session.

- **Subtype title/message** falls back to the generic "Review Recommended" / "Changes detected..." text.
- **Label confidence stat** (e.g. "50.4% (Benign)") is hidden from the UI.

This only affects `benignDominant` with Healthy/Benign labels. OCA and OPMD subtypes are never suppressed.

---

## 7. Per-Photo Disagreement Display

When binary and 5-class disagree for a single photo (binary says positive, 5-class says Healthy or Benign), the per-photo card shows a simplified display:

| Element | Shown |
|---------|-------|
| Badge | Risk level (e.g. High Risk) |
| Screening Risk Score | e.g. 85.7% |
| Summary | "Retake or further analysis needed" |
| Visual Detail | **Hidden** |
| Disagreement Note / Amber Box | **Hidden** |

When there is **no disagreement** (binary and 5-class agree), the full visual detail line is shown as before.

In the PDF report, the Label column shows "Retake or further analysis needed" when there is a disagreement, instead of the 5-class friendly label.

---

> **Key Principle:** The binary model decides if the session is positive and drives outcome/urgency. The 5-class model is only used to aggregate label confidence and class probability bars, and to pick subtype (OCA/OPMD/benign), which then refines the wording and urgency.
