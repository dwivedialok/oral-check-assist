# Requirements: Disagreement Matrix + 3-Level Urgency Ladder + Improved Confidence Display (Web + Inference Service)

## 0. Goal

Implement a clinically defensible, user-friendly **3-level urgency ladder** and a **detailed disagreement handling matrix** across:
- Inference Service (core logic)
- Web UI (result cards + detailed explanation)
- Automated tests (unit + widget + golden/integration)

This change must reduce panic in benign disagreement cases (Type A), while preserving safety for suspicious cases.

Project context:
- Dual ensemble: Binary + 5-class
- Existing thresholds + decision matrix already exist and are used in app logic :contentReference[oaicite:2]{index=2}
- Current UI may show “Moderate Risk + SOON” even when 5-class is strongly Benign and only disagreement triggered escalation (Type A).

## 1. Definitions

### 1.1 Binary bands (from current decision matrix thresholds)
Use these fixed thresholds unless already configurable:
- B0 (LOW): pCancer < 0.31
- B1 (MODERATE): 0.31 <= pCancer < 0.54
- B2 (HIGH): pCancer >= 0.54
Source: model development docs :contentReference[oaicite:3]{index=3}

### 1.2 5-class elevation bands (based on OCA/OPMD thresholds)
- F0 (NOT elevated): pOCA < 0.40 AND pOPMD < 0.45
- F1 (OPMD elevated): pOPMD >= 0.45 AND pOCA < 0.55
- F2 (OCA elevated): pOCA >= 0.55
Additionally: “OCA mixed-elevation” if (pOCA >= 0.40 AND binary is B1) => treat as F2 for urgency.

Thresholds are per existing design :contentReference[oaicite:4]{index=4}.

### 1.3 Disagreement types (existing concept)
Maintain or refine the existing disagreement detection:
- Type A: Binary indicates referral (B1/B2) but 5-class top label is Benign/Healthy and no elevation (F0)
- Type B: Binary indicates low (B0) but 5-class indicates suspicious elevation (F1/F2)
- Type C: Low reliability / low confidence / poor photo quality / too many skipped photos (implementation-defined)

## 2. Urgency Ladder (3 levels only)

Replace “SOON” (ambiguous) with:
- ROUTINE: “Routine (2–4 weeks)”
- PROMPT: “Prompt (1–2 weeks)”
- URGENT: “Urgent (within 1 week)”
Additional internal status:
- RETAKE: “Retake photos” (used for Type C / insufficient reliability)

### 2.1 Urgency determination rules (authoritative)

Implement as a pure function in inference service:

Inputs (session-aggregated):
- pCancer (binary aggregated)
- pOCA, pOPMD (5-class aggregated)
- top5ClassLabel + top5ClassProb
- benignHealthyProb = pBenign + pHealthy (aggregated)
- reliability summary: photosCaptured, photosUsed, skippedDueToUnknown, skippedDueToQuality (or equivalent)

Rules:
1) URGENT if:
   - pCancer >= 0.54 OR
   - pOCA >= 0.55 OR
   - (pOCA >= 0.40 AND pCancer >= 0.31)

2) PROMPT if:
   - (0.31 <= pCancer < 0.54) OR
   - (pOPMD >= 0.45 AND pOCA < 0.55)

3) ROUTINE otherwise (default)

4) RETAKE overrides all if Type C / insufficient reliability:
   - photosUsed < MIN_USED_PHOTOS (use current pipeline; if top-K=3 then MIN_USED_PHOTOS=2 or 3)
   OR
   - too many photos filtered due to UNKNOWN/quality
   OR
   - overall action confidence is “Low” (see §3) and disagreement is strong.

Note: Rule ordering matters (RETAKE override, then URGENT, then PROMPT, then ROUTINE).

## 3. Result Messaging Policy (Disagreement Matrix)

### 3.1 New “Action Summary” fields (output of inference service)

Extend the inference result object returned to UI with these fields:

- overallAssessmentTitle: short text label (no medical terminology)
  Examples:
  - “Low Risk”
  - “Moderate – Please Review”
  - “Moderate – Needs Attention”
  - “High Risk”
  - “Result Unclear – Retake Photos”

- overallAssessmentMessage: 1–2 sentence user-friendly message

- urgencyLevel: enum { ROUTINE, PROMPT, URGENT, RETAKE }
- urgencyText: user-facing string derived from urgencyLevel

- labelConfidence: show top class probability (5-class top probability)
  Example: 96.8% (Benign)
  NOTE: This is “label confidence” not clinical certainty.

- actionConfidence: enum { HIGH, MODERATE, LOW }
  This is derived from agreement & stability (see §3.2)

- disagreementType: enum { NONE, A, B, C }
- howWeDecidedBullets: list of strings
  Should include:
  - binary band summary (e.g., “Check 1 (referral): Refer (41% fused risk)” or equivalent)
  - 5-class label summary (e.g., “Check 2 (detail): Benign (97%)”)
  - agreement statement (e.g., “Checks disagreed; we recommend follow-up”)
  - photo usage statement (e.g., “Used 3 of 5 photos (best quality)”)

### 3.2 Disagreement matrix mapping (authoritative)

Compute a “case” using (Binary band, 5-class band, disagreement type).

Policy table:

Case 1: B0 + F0 + NONE
- overallAssessmentTitle: “Low Risk”
- urgencyLevel: ROUTINE
- actionConfidence: HIGH (if photosUsed >= 3 else MODERATE)
- message: “No concerning signs detected in these photos.”

Case 2: B1 + F0 + Type A
- overallAssessmentTitle: “Moderate – Review Suggested”
- urgencyLevel: ROUTINE (IMPORTANT: not PROMPT)
- actionConfidence: MODERATE
- message: “Most signs look non-concerning. One check suggested follow-up, so a routine dental review is recommended.”

Case 3: B0 + F1 + Type B
- overallAssessmentTitle: “Moderate – Needs Attention”
- urgencyLevel: PROMPT
- actionConfidence: MODERATE
- message: “Some changes may need follow-up. Please arrange a dental review within 1–2 weeks.”

Case 4: B1 + F1 (agreement or mild mismatch)
- overallAssessmentTitle: “Moderate – Needs Review”
- urgencyLevel: PROMPT
- actionConfidence: MODERATE
- message: “Some changes may need professional review. Please arrange a review within 1–2 weeks.”

Case 5: Any with F2 (or pOCA>=0.55) OR B2
- overallAssessmentTitle: “High Risk”
- urgencyLevel: URGENT
- actionConfidence: HIGH if agreement else MODERATE
- message: “Findings may require urgent professional evaluation. Please consult a dentist/oral specialist within one week.”

Case 6: Type C / insufficient reliability
- overallAssessmentTitle: “Inconclusive – Retake Photos”
- urgencyLevel: RETAKE
- actionConfidence: LOW
- message: “Photos were not clear/consistent enough to give a reliable result. Please retake in good light. If you have symptoms (pain, ulcer >2 weeks, bleeding), consult a clinician.”

Notes:
- Do NOT show “SOON” anywhere in UI.
- Ensure Type A (benign disagreement) is ROUTINE to avoid panic.
- Keep clinical disclaimer unchanged.

## 4. Confidence Display Requirements

### 4.1 Separate “Label confidence” vs “Action confidence”
UI must display:
- Label confidence: top5ClassProb (e.g., 96.8%)
- Action confidence: derived category (HIGH/MODERATE/LOW)
  Example text:
  - “Action confidence: Moderate (checks disagreed)”

### 4.2 How to compute label confidence
Use the aggregated 5-class probability of the predicted label (top class).
This matches current report behavior (e.g., Benign 96.8%) :contentReference[oaicite:5]{index=5}.

### 4.3 How to compute action confidence
Heuristic:
- HIGH if:
  - disagreementType == NONE AND photosUsed >= 3 AND (top5ClassProb >= 0.80 OR pCancer far from thresholds)
- MODERATE if:
  - disagreementType in {A,B} OR photosUsed == 2 OR top5ClassProb in 0.60–0.80
- LOW if:
  - disagreementType == C OR photosUsed < 2 OR large instability (optional)

## 5. Photo Count Reporting Enhancements

UI should show:
- photosCaptured (e.g., 5)
- photosUsed (e.g., 3)
Optional:
- skippedDueToUnknown count
- skippedDueToQuality count

Add these to “How we decided” panel.

## 6. Implementation Tasks

### 6.1 Inference Service (core logic)
File: model_inference_service.dart :contentReference[oaicite:6]{index=6}

Tasks:
1) Introduce enums/types:
   - UrgencyLevel { routine, prompt, urgent, retake }
   - DisagreementType { none, typeA, typeB, typeC }
   - ActionConfidence { high, moderate, low }
2) Add pure functions:
   - computeBinaryBand(pCancer) -> B0/B1/B2
   - computeFiveClassBand(pOCA, pOPMD, pCancer) -> F0/F1/F2
   - computeDisagreementType(binaryBand, fiveBand, topLabel, reliability) -> DisagreementType
   - determineUrgency(...) -> UrgencyLevel (per §2.1)
   - buildAssessmentMessage(...) -> {title, message, howWeDecidedBullets}
3) Ensure the service returns a richer result object to UI including:
   - urgencyLevel + urgencyText
   - labelConfidence (double)
   - actionConfidence (enum + UI string)
   - disagreementType
   - photosCaptured/photosUsed and skip counts
4) Ensure existing behavior of decision matrix remains compatible; only messaging/urgency mapping changes per spec.
5) Ensure backward compatibility: If UI expects older fields, provide fallbacks until UI is updated.

### 6.2 Web UI (result screens)
Tasks:
1) Replace “SOON” with urgencyText derived from urgencyLevel.
2) Add “Action confidence” display when disagreementType != NONE.
3) “How we decided” panel:
   - Show 2 checks summary (binary + 5-class)
   - Show disagreement explanation sentence
   - Show photo usage stats (captured/used)
4) Ensure color coding:
   - ROUTINE: neutral/greenish
   - PROMPT: amber
   - URGENT: red
   - RETAKE: gray/blue
5) Ensure PDF report generation (if present) uses same strings:
   - urgencyText
   - assessment title/message

## 7. Automated Testing Requirements (Flutter)

### 7.1 Unit tests (core logic) — MUST HAVE
Create pure Dart unit tests for:
- determineUrgency()
- computeDisagreementType()
- buildAssessmentMessage()

Approach:
- Mock the model outputs by directly calling these pure functions with synthetic probabilities.
- No ONNX/TFLite inference in unit tests.

Test cases (minimum):
1) Case 1: B0 + F0 -> Low Risk, ROUTINE, disagreement NONE
2) Case 2: Type A benign disagreement -> Moderate – Review Suggested, ROUTINE (not PROMPT/URGENT)
3) Case 3: Type B OPMD -> Moderate – Possible OPMD, PROMPT
4) Case 5: OCA elevated -> High Risk, URGENT
5) Type C: photosUsed < MIN_USED_PHOTOS -> RETAKE

Assertions:
- urgencyLevel matches spec
- title/message match expected templates
- actionConfidence matches expected categories

### 7.2 Service-level tests (mock inference) — SHOULD HAVE
Refactor inference service to allow dependency injection:
- An interface like `EnsemblePredictor` returning:
  - pCancer
  - 5-class probabilities
  - per-photo quality/unknown flags
Then test the full service aggregation + policy mapping without real models.

### 7.3 Widget tests (simulate UI) — SHOULD HAVE
Flutter widget tests can render UI with a fake result model:
- Build the ResultCard widget using a synthetic `ScreeningResult`.
- Verify:
  - urgencyText displayed correctly
  - assessmentTitle displayed
  - action confidence line appears only when disagreementType != NONE
  - “How we decided” contains expected bullets

### 7.4 Golden tests (UI snapshots) — NICE TO HAVE
Use golden tests for:
- Low Risk screen
- Moderate Type A screen (should show ROUTINE)
- Moderate Type B screen (PROMPT)
- High Risk screen (URGENT)
- Retake screen (RETAKE)

### 7.5 Integration tests — OPTIONAL
If web app is Flutter web:
- Use `integration_test` to navigate:
  - upload/select photos (or bypass by injecting a debug-mode fake inference result)
  - verify final screen outputs

Recommendation:
- Add a debug-only route or flag to inject a canned `ScreeningResult` for deterministic UI integration testing.

## 8. Acceptance Criteria

1) No UI displays the word “SOON”.
2) Type A disagreement (binary refer but 5-class benign) results in:
   - assessmentTitle = “Moderate – Review Suggested”
   - urgency = ROUTINE (2–4 weeks)
   - actionConfidence = MODERATE
   - labelConfidence still shows high benign probability when applicable
3) OCA elevation or binary high triggers URGENT.
4) Poor reliability triggers RETAKE.
5) Unit tests cover at least the 5 mandatory cases and pass in CI.
6) Widget tests validate correct text/visibility for urgency and confidence.

## 9. Notes / Non-Goals

- Do not change model files, thresholds, or training.
- Do not change medical disclaimer text.
- Do not introduce network calls.
- Keep messages short and localizable (i18n-ready).