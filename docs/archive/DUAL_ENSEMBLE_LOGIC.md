# Dual-ensemble logic: matrix (binary + 5-class) and 5-photo combination

## 0. Two model sets (what runs where)

There are **two separate model sets**. “Dual ensemble” means **run both and merge**, not “only binary.”

| What | Where on disk | Output | Log tag when loading / running |
|------|----------------|--------|----------------------------------|
| **5-class ensemble** | `assets/ensemble_model_1.onnx`, `_2`, `_3` | One of: Healthy, Benign, OPMD, OCA, Unknown + 5 probabilities | `[Ensemble]` (per-model predictions and combined result) |
| **Binary ensemble** | `assets/binary_ensemble/ensemble_model_1.onnx`, `_2`, `_3` | Refer vs no-refer: one number P(cancer/refer) | `[BinaryEnsemble]` (load only); result appears as “Ensemble 1 (Referral)” inside `[DualEnsemble]` |

When the app uses **dual-ensemble** (screening flow):

1. **Binary ensemble** runs on the image → “Check 1 (Referral)”: Low risk vs Refer (P(refer)).
2. **5-class ensemble** runs on the **same** image → “Check 2 (Detail)”: label + 5 probabilities (Benign, Healthy, OCA, OPMD, Unknown).
3. **Dual-ensemble** code merges them: risk from binary, then matrix (e.g. elevate if 5-class has high OCA/OPMD), and sets `displayLabel` / `disagreementNote`.

So the **label and probabilities** you see in the `[DualEnsemble]` log under “Ensemble 2 (Detail)” come from the **5-class** models in `assets/`, not from the binary models. The binary ensemble only ever outputs a single referral probability; it has no “labels” or 5-way probabilities.

**Log naming in code:** The 5-class path uses the tag `[Ensemble]`; the binary path uses `[BinaryEnsemble]` when loading and on errors. In the dual flow, `[DualEnsemble]` prints “Ensemble 1 (Referral)” = binary result and “Ensemble 2 (Detail)” = 5-class result. Renaming `[Ensemble]` → `[5ClassEnsemble]` in code would make the two model sets easier to tell apart in logs.

---

## 1. Where the matrix is used (single photo)

**File:** `lib/services/model_inference_service.dart`

### 1.1 Dual-ensemble entry: `inferDualEnsemble` (lines ~708–776)

- Runs **binary ensemble** → `isCancer`, `cancerProbability`.
- Runs **5-class ensemble** → `fiveClassLabel` (Healthy, Benign, OPMD, OCA, Unknown), `confidence`, `probabilities`.

### 1.2 Risk from binary (referral decision)

```dart
// Risk from binary (referral decision)
RiskLevel riskLevel;
if (!isCancer) {
  riskLevel = RiskLevel.low;
} else if (cancerProb < _highRiskThreshold) {
  riskLevel = RiskLevel.moderate;
} else {
  riskLevel = RiskLevel.high;
}
```

### 1.3 Matrix: elevate risk when 5-class label is suspicious

So **OPMD** never shows as “Low Risk”, **OCA** never shows below “High Risk”:

```dart
// Matrix: elevate risk when 5-class label is suspicious (OPMD/OCA must not show as Low Risk)
if (fiveClassLabel == 'OCA' && riskLevel.index < RiskLevel.high.index) {
  riskLevel = RiskLevel.high;
} else if (fiveClassLabel == 'OPMD' && riskLevel == RiskLevel.low) {
  riskLevel = RiskLevel.moderate;
}
```

### 1.4 Matrix: display label and disagreement note

- **displayLabel** = 5-class label (shown in UI).
- **disagreementNote** when binary and 5-class disagree (e.g. binary “no cancer” but 5-class “OPMD” → “Detailed label: OPMD – consider follow-up”).

```dart
String displayLabel = fiveClassLabel;
String? disagreementNote;
final bool fiveClassIsSuspicious = fiveClassLabel == 'OCA' || fiveClassLabel == 'OPMD';

if (fiveClassLabel == 'Unknown') {
  disagreementNote = 'Unclear – consider follow-up. Binary result: ...';
} else if (!isCancer && fiveClassIsSuspicious) {
  disagreementNote = 'Detailed label: $fiveClassLabel – consider follow-up';
} else if (isCancer && !fiveClassIsSuspicious) {
  disagreementNote = 'Refer recommended. Model detail: $fiveClassLabel';
}
```

### 1.5 Returned map (used per photo)

- `binaryReferral`, `displayLabel`, `disagreementNote`, `riskLevel`, `confidence`, `probabilities` / `classProbs`.

---

## 2. How it’s used for each of the 5 photos

**File:** `lib/services/model_inference_service.dart`

### 2.1 Per-photo analysis: `analyzePhoto` (lines ~913–1023)

- For **Ensemble + dual-ensemble ready**: calls `inferDualEnsemble(photo.image!)` → gets the matrix output above.
- Otherwise: calls `inferWithProbabilities` (5-class only).
- Builds a **PhotoResult** with `riskLevel`, `binaryReferral`, `displayLabel`, `disagreementNote`, `classProbabilities`, etc.

### 2.2 Multi-photo loop: `inferMultiPhoto` (lines ~1025–1140)

- For each captured photo:
  1. `analyzePhoto(photo)` → one **PhotoResult** (with matrix-based `riskLevel` when dual-ensemble is used).
  2. If photo is valid (oral), its probabilities are added to `validPredictions` and weights to `validWeights`.
- **Per-photo risk** is the `riskLevel` from the matrix (binary + 5-class elevation) for that photo.

### 2.3 Combining the 5 photos: overall risk

- **Aggregation of probabilities:** `_aggregatePredictions(validPredictions, validWeights)` → weighted average of 5-class probabilities across valid photos → `aggregatedClassProbs`.
- **Overall risk:** **max** of the per-photo risk levels (from the matrix):

```dart
final photosWithRisk = photoResults.where((r) => r.riskLevel != null).toList();
RiskLevel overallRisk;
if (photosWithRisk.isNotEmpty) {
  overallRisk = photosWithRisk.map((r) => r.riskLevel!).reduce((a, b) =>
      a.index >= b.index ? a : b);  // max risk across photos
} else {
  // fallback: from max suspicious probability (5-class only)
  ...
}
```

So:
- Each of the 5 photos gets a **risk level from the matrix** (binary + 5-class OPMD/OCA elevation).
- **Overall risk** = **maximum** of those 5 risk levels (and recommendations use this overall risk).

---

## Summary

| Step | Where | What |
|------|--------|------|
| Binary + 5-class run | `inferDualEnsemble` | Binary → referral; 5-class → label & probs |
| Risk from binary | `inferDualEnsemble` | low / moderate / high by `isCancer` and `cancerProb` |
| Matrix elevation | `inferDualEnsemble` | OPMD → at least Moderate; OCA → High |
| Display / disagreement | `inferDualEnsemble` | `displayLabel`, `disagreementNote` |
| Per-photo result | `analyzePhoto` | Calls `inferDualEnsemble`, builds `PhotoResult` with `riskLevel` |
| 5-photo loop | `inferMultiPhoto` | For each photo: `analyzePhoto` → list of `PhotoResult` |
| Combine 5 photos | `inferMultiPhoto` | Overall risk = **max**(per-photo `riskLevel`); probs = weighted average |
