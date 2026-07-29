<div class="cover">

![](product_guide_assets/app_icon.png){.logo}

# Oral Check Assist — Clinician guide

<p class="subtitle">How on-device screening works, what patients see, and how to use the app in practice</p>

<p class="meta">Screening adjunct only — not a substitute for clinical examination or histopathology</p>

</div>

This document explains how the app decides **risk level** and **recommendations**, what the AI is validated to do (and what it is not), and how clinicians can use it effectively—including in **controlled validation** settings (for example, studies where examiners who already see tobacco-using patients also run the app and outcomes are compared to clinical judgment). Technical model-training detail is omitted here; this guide is self-contained for clinical and operational use.

---

## 1. Overview

The app runs **entirely on the device**: photos are analyzed locally; there is no cloud inference step in the default screening flow.

It uses **two AI checks** on each photo:

1. **Screening check (binary)**  
   Produces **Screening Risk Score** = P(abnormal). This drives whether the session is **screen-positive** or **screen-negative** at the app’s operating point (see Section 5).

2. **Detail check (5-class)**  
   Predicts a **label**: Healthy, Benign, OPMD, OCA, or Unknown. Used for **subtype** (wording and urgency) and **label confidence**; it does **not** override the binary screening decision.

**Key principle:** The binary model decides **screen-positive vs screen-negative**; the 5-class model supplies **subtype**, **label confidence**, and **safe wording** when the two models disagree. With **multiple photos**, the app applies a **hybrid rule** on binary scores (`maxScore ≥ 0.65` or `hybridAvg ≥ 0.4735` → screen positive) and aggregates 5-class over the photo set defined in Section 5. **Per-photo risk badges** (Low / Moderate / High on each image) follow **binary scores only**; the 5-class label does not raise or lower that badge, but it does change what **text** the user sees alongside it (**Section 3**).

---

## 2. Using the app: walkthrough (what you and the patient do)

Typical flow in the mobile app:

1. **Preparation screen** — The patient (or assistant) confirms simple checks: good lighting (natural light or facing a window), clean mouth, lip products removed if possible, mirror nearby if helpful, and a minute or two set aside. These steps mirror in-app copy and improve focus and framing.

2. **Photo capture (five slots, in order)** — The guided sequence is **Front view** (required) → **Right cheek** → **Left cheek** → **Tongue** → **Palate**. The four non-front slots can be **skipped** if needed. The app uses the device camera with a **simple overlay** (mouth / cheek / tongue / palate outline) to help framing. Each capture gets an on-device **quality** score; capture-time feedback may flag **unclear** images when quality falls below the “clear” band (Section 8).

3. **Review (per photo)** — The user confirms each shot or retakes. Optional tools here:
   - **Crop** — Tighten the frame on the oral area if needed; the app enforces a **minimum crop size** (so the model still receives enough pixels) and may warn on **very small** crops relative to the original. After crop, **quality is re-checked**; a poor result may suggest retaking instead of analyzing.
   - **Photo label (display only)** — The user can pick a **preset anatomical label** (e.g. right buccal mucosa) or a **short custom label** for that slot. This text appears on review and in **reports** so documentation matches what was photographed; **inference and all risk math still use the fixed capture slot** (front vs cheek vs tongue vs palate), not the optional label.

4. **Analyze** — Starts on-device inference on the **final** image for each slot (including any crop). Progress is shown photo-by-photo.

5. **Tobacco / exposure questionnaire (ERI)** — Short questions about tobacco use, answered while analysis runs where possible. Answers feed an **exposure risk level** that can **raise the final communicated risk** when combined with AI (e.g. AI Moderate + high exposure → final **High** with extra messaging). They do **not** change the underlying **binary screen-positive** decision.

6. **Results** — **Risk level** (Low / Moderate / High), **urgency**, **recommendations**, and (when shown) **Screening Risk Score**, **display label**, and explanation text. When ERI elevates risk, the UI reflects **final** risk after the **AI + exposure matrix**. The user can open **detailed / per-photo** information where the product provides it.

**Clinician tip:** For validation or audit, note the **time order** you prefer (exam first vs. images first) in your protocol; the app does not enforce clinical examination, but your workflow should make clear whether images are independent of your verbal impression.

---

## 3. What the user sees (single photo)

Each analyzed photo combines **one binary output** and **one 5-class output** (each from small on-device **ensembles**). Think of it as a small **decision table**: the **badge** comes from the binary score; the **wording** comes from the 5-class label, with extra rows for uncertainty and disagreement.

### 3.1 Screening Risk Score (always binary)

**Screening Risk Score** on a photo is **always** P(abnormal) from the **binary** ensemble for that image (shown as a percentage). It is the same quantity that feeds the **hybrid session rule** when the photo is **usable** (oral, analyzed, quality ≥ minimum in Section 8).

### 3.2 Risk badge on that photo (binary thresholds)

For a photo that is treated as a **valid oral** image (not dropped as likely non-oral):

- **Low** — P(abnormal) **below** the binary operating point (**0.4735** in current configuration).
- **Moderate** — P(abnormal) **≥ 0.4735** and **below** the single-view high band (**0.65**).
- **High** — P(abnormal) **≥ 0.65**.

If the image is classified as **likely non-oral** (5-class **Unknown** with high **Unknown** probability), the app may treat it as **not usable** for aggregation and the per-photo risk can be **unassessable** in the UI—clinically, that means “do not interpret this frame for screening; retake a clear oral view.”

**Important:** The 5-class label **does not** change this Low / Moderate / High badge. OPMD or OCA on the detail model **do not** upgrade a binary-Low photo to Moderate or High; they only affect **labels**, **session subtype** after screen-positive aggregation, and **messaging** (see below).

### 3.3 Display label and “matrix” behaviour (binary × 5-class)

| 5-class side | Typical user-facing behaviour |
|--------------|--------------------------------|
| **Top class** | Shown as the **display label** (Healthy, Benign, OPMD, OCA, or Unknown) when the largest class probability is **high enough**; otherwise the app shows **Uncertain** instead of forcing a subtype name. |
| **Binary negative + 5-class Healthy** | May show a concise **Healthy** line where the product aligns the two. |
| **Binary positive + 5-class Healthy or Benign** | **Retake or further analysis needed** — the app avoids telling the user a **benign-looking** subtype while the screening score is in the **refer** band. The **badge** and **Screening Risk Score** still reflect the binary side. |

Other combinations show the display label together with the badge and score as appropriate.

#### 3.3.1 “Uncertain” vs “Unknown” — two distinct states with distinct wording

These two technical labels look superficially similar but mean different things and produce different user-facing text:

| Technical label | When it appears | User-facing wording | Photo used in aggregation? | Per-photo Risk badge |
|---|---|---|---|---|
| **Unknown** (true OOD) | 5-class top class is `Unknown` **and** P(Unknown) > **0.6** — the model thinks the image is **not an oral view**. | *“Image unclear or not suitable for assessment (Unknown)”* | **No** — excluded. | **N/A** (unassessable). |
| **Uncertain** (low label confidence) | 5-class top probability is **< 0.5** across all five classes — the model could not pick any single class with confidence, but the image **is** still treated as an oral view. | *“Awaiting clinical verification (Uncertain)”* | **Yes** — fully used. | Comes from the **binary** model (Low / Moderate / High), unchanged. |

This distinction matters because clinicians have reported confusion when the camera quality reads near 100 % but a per-photo label says “Image unclear”. In almost every such case the image was *not* technically poor — the **5-class detail model** simply couldn’t commit to a class. Wording the two states differently makes that explicit:

- **Unknown** = *“the AI doesn’t think this is an oral image; please retake.”*
- **Uncertain** = *“the AI saw an oral image but couldn’t classify the tissue pattern. The screening signal is still trusted; clinical confirmation is recommended.”*

The **binary screening decision and per-photo Risk badge** are independent of this distinction. A photo can be labelled `Uncertain` and still carry a `High` binary Risk badge with an 80 %+ Screening Risk Score — the AI is decisive about *“something abnormal”* and indecisive about *“what kind”* simultaneously, which is consistent with a **screening-first** product.

#### 3.3.2 “Label confidence” vs other confidences

The number labelled **“Label confidence”** in the results screen and PDF (e.g. *“Label confidence: 28.0 %”*) is the **maximum aggregated 5-class probability** — i.e. how strongly the detail model favours a single class **after** weighted aggregation across usable photos. It is **not** a calibrated probability of disease and **not** a confidence in the screening decision. It is renamed from the older *“Confidence”* wording to make this scope explicit; the underlying number is the same.

A low Label confidence (e.g. 28 %) next to a **High Risk** session is **not** internally inconsistent: the binary model can be confident that something abnormal is present (drives the badge and risk level) while the 5-class detail model cannot decide *which* abnormal class fits best (drives Label confidence). When in doubt, prioritise the **binary Screening Risk Score** and the **session Risk Level** over Label confidence for clinical interpretation.

### 3.4 Per-photo panel (what appears in detailed results)

| Item | Meaning |
|------|--------|
| **Risk level** | **Low**, **Moderate**, or **High** from **binary** thresholds on that photo (Section 3.2), not from the 5-class name alone. |
| **Display label** | 5-class–driven label, or **Uncertain** / **Unknown** (Section 3.3.1). |
| **Label confidence** | Top 5-class probability for that photo (Section 3.3.2). Not the screening confidence. |
| **Screening Risk Score** | Binary P(abnormal) for that photo (Section 3.1). |
| **Summary line** | When binary and 5-class **conflict** as above, **Retake or further analysis needed**; when aligned, short summary text may appear. |
| **Slot / label** | **Capture slot** (e.g. Tongue) is fixed for ordering; optional **user label** is for documentation only. |
| **Verdict explanation** | Session-level and per-photo plain-language text and next steps. |

---

## 4. How risk and urgency are decided (current screening policy)

**Screen-positive vs screen-negative** is driven **only by the binary model** (the 5-class model does not flip a negative session to positive or the reverse). Per-photo badges and scores are covered in **Section 3**; this section describes **session-level** mapping to overall risk and urgency.

### Session (single or multi-photo)

- **Hybrid rule (binary only):** Among **usable** photos (Section 5), take **maxScore** = highest binary P(abnormal), **secondScore** = second highest (or zero if only one usable photo), **hybridAvg** = (maxScore + secondScore) / 2.
- **Screen positive** if **maxScore ≥ 0.65** *or* **hybridAvg ≥ 0.4735**; otherwise **screen negative**.
- **Three outcomes** after that:
  - **Review recommended** — screen positive.
  - **Retake suggested** — screen negative but the session is **near the boundary**, **too few usable** photos for a reliable call, and/or **quality** is broadly weak (see Section 5).
  - **Low risk** — screen negative and none of the retake triggers apply.

**Overall risk (Low / Moderate / High)** is **not** the maximum of per-photo badges. It is derived from the **session outcome** plus **subtype guidance** from aggregated 5-class probabilities: e.g. **Review recommended** + OCA-dominant aggregated pattern → **High** overall; **Review recommended** + OPMD-dominant / benign-dominant / no clear subtype → **Moderate** overall; **Low risk** outcome → **Low** overall; **Retake suggested** → **Moderate** overall with **retake** urgency so the user does not read “Low” while being asked to repeat images.

**Urgency:** Low-risk outcome → Routine; Retake outcome → Retake photos; Review + OCA-dominant pattern → Urgent (within about 1 week); Review + other → Prompt (about 1–2 weeks).

The **5-class model** supplies **subtype titles/messages**, **label confidence** (strength of the aggregated winning class), and the **soft borderline note** on some low-risk sessions when OPMD+OCA probability is elevated but binary stayed negative. When **screen-positive** but aggregated 5-class points to **Healthy or Benign**, **lesion-style subtype messaging** is suppressed so patients are not shown a benign subtype name alongside a positive screen.

---

## 5. Multiple photos (two or more)

When the user submits more than one captured view (front, cheeks, tongue, palate):

1. **Usable photos** — Each frame must be **oral** (not treated as strong **Unknown** / non-oral), **successfully analyzed**, and have **quality ≥ 0.5** to count as **usable** for the hybrid binary rule and for 5-class aggregation. Sub-threshold quality can still contribute to **skipped** counts and may contribute to a **retake** path when the session is unreliable.

2. **Minimum usable count** — If the user attempted at least **two** captures but **fewer than two** end up usable, the app treats the session as **Retake suggested** (insufficient reliable coverage)—even when binary scores are low.

3. **Hybrid rule** — Over usable photos only: **maxScore** = highest binary score, **secondScore** = second highest (or **zero** if only **one** usable photo remains), **hybridAvg** = (maxScore + secondScore) / 2. **Screen positive** if maxScore ≥ 0.65 or hybridAvg ≥ 0.4735.

   **Edge case (only one usable photo):** With a single usable frame, **secondScore** is **0**, so **hybridAvg** is **half** of the top score. Then **hybridAvg ≥ 0.4735** would require roughly **≥ 0.95** on that one image—so, in practice, **session review recommended** from the hybrid branch almost always means **maxScore ≥ 0.65** until at least **two** usable views exist. A single photo can still show a **Moderate** per-photo badge in the **0.4735–0.65** band while the **session** stays screen-negative—clinically, treat that as “weak evidence until another view confirms or refutes.”

4. **Retake when screen-negative** — If **not** screen positive, the app may still choose **Retake suggested** when **hybridAvg** falls in the **retake band** (about **0.45–0.50**), when **usable count** is too low (item 2), or when **any** analyzed photo has **quality** below the “unclear” band (Section 8)—so borderline scores or weak imagery are not silently read as reassuring.

5. **Weighted 5-class aggregation** — For each usable photo, the app computes a **weight** from **image quality** and a blend of **binary** and **5-class** certainty (so sharper, clearer views count more in the average). When **screen positive**, only photos with binary **≥ 0.4735** feed the aggregate used for **subtype** and **label confidence**; when **screen negative**, **all** usable photos feed that aggregate (including for the borderline OPMD+OCA note).

6. **Session-level suppression** — If screen positive but aggregated 5-class is **Healthy or Benign**, the app does **not** show **lesion subtype**-style detail or the **label confidence** statistic, consistent with Section 3.3.

**Net result:** one **overall risk**, **urgency**, **subtype messaging** when appropriate, **probabilities / label confidence** when shown, and **recommendations**—with optional **per-photo** detail (Section 3).

---

## 6. Recommendations and urgency

Recommendations are generated from **AI overall risk** (Sections 4–5), then **merged** with ERI outputs when the questionnaire is completed. The **final communicated risk** on results (and in the report) is **at least** the AI risk: **high AI risk stays high** regardless of exposure. For **moderate AI risk**, **high tobacco-exposure tier** can **raise the final level to High** and append exposure-specific counselling lines; lower exposure tiers keep or nuance moderate messaging. For **low AI risk**, exposure data mainly affects **rescreen interval** and contextual notes rather than inventing a positive screen from images alone.

Typical recommendation bands tied to the **final** risk level:

- **Low risk** — No concerning signs detected; routine oral hygiene and dental check-up; rescreen in about 3 months (as shown in app; ERI may shorten rescreen for heavy exposure).
- **Moderate risk** — Changes need attention; see dentist within about 2–4 weeks; avoid tobacco/alcohol; monitor.
- **High risk** — Concerning changes; urgent evaluation by oral surgeon or oncologist within about 1 week; bring the report.

**Urgency** follows the **AI** outcome and subtype (Section 4), not the ERI-adjusted headline alone. The app may add notes (e.g. highlighting **Front view**) when certain capture slots had **Moderate** or **High** per-photo binary bands (Section 3.2).

---

## 7. Evidence, limitations, and why binary screening leads

**Patient-wise evaluation (why older “accuracy” figures can mislead):**  
Models were re-trained and tested with **patient-level splits**: images from the **same person** do not appear in both training and test. Older **image-wise** splits allowed the same patient in train and test, so metrics could be **inflated** (lighting, anatomy, camera habits). **Patient-wise** metrics are a more honest guide to **new patients**.

**What that means in practice:**

- **Binary screening** is the main, calibrated lever for “refer vs not” at fixed thresholds. The **0.4735** hybrid threshold is chosen as an **~80% specificity** operating point on an internal pooled frozen test set (**TM_v3**); **0.65** catches a single very confident positive view. These values are **configuration**, not universal clinical truth—they should be reviewed when models or datasets change.
- **5-class** detail is **more sensitive to domain shift** (different cameras, sites, or labeling styles). The app uses it for **interpretability and urgency wording**, not to overturn binary screening.
- Some builds use an **SSL-enhanced** backbone (extra oral-related pretraining); deployment still relies on **calibrated thresholds**, not a raw 0.5 cutoff alone.

The app is a **screening adjunct**, not a substitute for clinical examination, histopathology, or specialist diagnosis.

---

## 8. Thresholds and quality rules (reference)

All of the following live in app configuration (`lib/services/screening_config.dart`, class `ScreeningConfig`) and may change with a release:

| Topic | Typical values | Role |
|--------|----------------|------|
| **Binary operating point** | **0.4735** | Same constant as **per-photo** “refer” band and **hybridAvg** session positive threshold. |
| **Hybrid screen-positive** | hybridAvg ≥ **0.4735** | Session positive when the average of the top two binary scores is high enough. |
| **Single strong positive** | maxScore ≥ **0.65** | Session positive regardless of second photo; per-photo **High** badge in the same band. |
| **Per-photo “abnormal” for 5-class aggregation** | binary ≥ **0.4735** | When screen-positive, only these photos contribute to **subtype** / aggregated label stats. |
| **Retake band (session, screen-negative)** | hybridAvg in **[0.45, 0.50)** | Near-boundary scores trigger **Retake suggested** together with quality / count rules (Section 5). |
| **Minimum usable photos** | **2** | If the user captured ≥ 2 frames but **< 2** are usable → **Retake suggested**. |
| **Minimum quality for “usable”** | **0.5** | Below this, a photo is not counted as usable for hybrid aggregation. |
| **Strong “unknown / non-oral”** | Unknown class probability > **0.6** (when Unknown is top) | Excludes that frame from oral aggregation. |
| **Unclear image quality** | quality < **0.6** | May be flagged at capture; any analyzed photo below this can contribute to session **retake** when screen-negative. |
| **Display “Uncertain” label** | max 5-class probability < **0.5** | Per-photo display label becomes **Uncertain** instead of forcing a class name. |
| **Subtype / dominance** | max(OPMD, OCA, Benign) ≥ **0.40** | Needed before OCA- / OPMD- / benign-dominant subtype messaging applies. |
| **Low-risk borderline note** | OPMD + OCA aggregate probability > **0.35** | Soft “minor irregular patterns” wording on some negative sessions. |
| **Architecture** | MobileNetV3-Large–class backbones | Binary + 5-class **ensembles** as shipped in the build. |

> **Engineering note.** A proposal to make session **Risk Level** and **Urgency** entirely binary-driven (removing the `OCA-dominant` 5-class subtype lever from the headline) is documented in `docs/BINARY_PRIMARY_RISK_GRADING.md`, together with the validation-set evidence required from **TM_v3** before flipping the default. Until that change ships, current behaviour matches this section exactly.

---

## 9. How clinicians can use the app (including tobacco-exposed patients)

1. **Complete the oral exam you would normally perform** first or in parallel, per your protocol—then capture images that **represent** the areas you assessed (buccal mucosa, tongue, floor of mouth, palate, etc.). The app is only as good as the **views and quality** of the photos.

2. **Follow in-app guidance** on lighting, focus, and number of views. Poorly lit or out-of-frame images may be excluded or down-weighted.

3. **Treat binary screen-positive / risk level as a screening signal**, not a diagnosis. Discordance (app positive, you low concern—or the reverse) is **expected sometimes** and is what validation studies measure.

4. **Use 5-class labels cautiously** for patient communication; they are **subordinate** to binary screening and can disagree when anatomy or image domain differs from training data.

5. **Document tobacco exposure** in the app if your study uses it (ERI), so recommendations stay aligned with the intended workflow.

6. **For retake or uncertain states**, follow your clinical safety net: **clinical findings override the app** when they conflict.

---

## 10. Validation against clinician judgment (hospital / controlled studies)

If your institution runs a **prospective validation**—clinicians who routinely examine **tobacco-using** patients also use the app and you analyze **agreement** with clinical decisions—consider:

| Aim | Practical approach |
|-----|---------------------|
| **Compare screening disposition** | Record your **binary** decision (e.g. reassure vs refer / biopsy / specialist) on the **same visit** as the app session; compare to app screen-positive vs screen-negative. |
| **Compare risk gradation** | Optionally map your impression to Low / Moderate / High concern and compare to app **risk level** (scales are not identical). If ERI was completed, record both **AI-only** and **final** risk so exposure-driven elevation is traceable. |
| **Handle disagreement** | Predefine that **clinical judgment** governs patient management; the app is under evaluation. Capture disagreements for analysis, not as isolated “errors.” |
| **Reduce bias** | Decide whether image capture is **independent** of your verbal result (e.g. assistant captures before you state conclusion) if the study requires it. |
| **Correlation metrics** | Agreement (kappa), sensitivity/specificity of app vs clinician **as one reference** (neither is a gold standard without pathology), calibration of **Screening Risk Score** vs your ordinal concern. |
| **Case mix** | Record exposures (tobacco type, pack-years if used), sites photographed, and reason for visit. |

Framing validation around **binary agreement** under **patient-wise** model behaviour matches how the product is designed: binary screening is the robust layer; 5-class is auxiliary for wording and subtype.

---

## 11. Summary for clinicians

| Question | Answer |
|----------|--------|
| What is the main "result"? | **Risk level** (Low / Moderate / High), **urgency**, and **recommendations**; optional **ERI-adjusted final risk**; 5-class **label** when shown; explicit handling when binary and 5-class conflict (Section 3.3). |
| What is the Screening Risk Score? | **Binary** P(abnormal) per photo (ensemble), also fed into the **hybrid** session rule for usable photos. |
| How is the per-photo badge set? | **Binary thresholds only** (below **0.4735** → Low; **0.4735** up to but not including **0.65** → Moderate; **0.65** and above → High). The 5-class name does **not** raise or lower that badge. |
| How is overall session risk set? | **Not** the max of per-photo badges. **Binary hybrid** → screen positive/negative → outcome (review / retake / low); then **aggregated 5-class** refines **subtype** and overall **High vs Moderate** when review is recommended. |
| How is risk computed? | **Binary** drives screen-positive (hybrid: maxScore ≥ 0.65 or hybridAvg ≥ 0.4735). **5-class** is aggregated with quality-weighting (Section 5). **ERI** can elevate **communicated** risk when AI is moderate and exposure is high. |
| Why two checks? | Binary is tuned for refer vs not; 5-class gives interpretable labels and subtype for wording/urgency. The binary **is not** overridden by the 5-class. |
| What if the two checks disagree? | Example: binary in refer band but 5-class Healthy/Benign → **badge + score** still reflect binary; summary avoids implying a benign subtype (**Retake or further analysis needed**). |
| Is the AI diagnostic? | **No**—screening adjunct; clinical examination and standard pathways remain authoritative. |
| Why trust patient-wise development? | Train/test splits avoid **same-patient leakage**, so reported performance is closer to **new-patient** behaviour than older image-wise figures. |
| Do thresholds ever change? | Yes—thresholds are **versioned configuration** (`ScreeningConfig`). After model or app updates, confirm behaviour against **release notes** or your institution’s validation SOP. |
