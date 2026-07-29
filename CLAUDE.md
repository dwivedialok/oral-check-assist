# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-assisted oral cavity screening mobile/web app built with Flutter. Users capture multi-photo sessions; on-device ONNX ensemble models produce risk-stratified screening recommendations. Not a diagnostic tool — a clinical screening aid.

Current version: `0.1.12+18` (must stay in sync between `pubspec.yaml` and `lib/screens/home_screen.dart`).

## Commands

```bash
# Setup (Git LFS required for assets/*.onnx)
git lfs install && git lfs pull
flutter pub get
bash scripts/fresh_install.sh        # Clean install on connected Android device

# Development
flutter run                           # Run on connected device/emulator
flutter run -d web-server            # Web PWA dev server

# Testing & Linting
flutter test                          # Unit + widget tests
bash scripts/run_e2e_tests.sh        # E2E integration tests (Chrome PWA)
flutter analyze                       # Static analysis / lint

# Build
flutter build apk                     # Android release APK
flutter build ios                     # iOS release
flutter build web                     # Web PWA

# Utilities
bash scripts/verify_model_assets.sh  # Verify required ONNX filenames exist (run before web deploy)
python3 ml/training/notebooks/model_registry.py  # Print canonical training/production paths
```

## Architecture

### State Management

Single `ScreeningProvider` (Provider/ChangeNotifier) owns the entire session lifecycle. Screens consume it via `Consumer<ScreeningProvider>`. There is no other state management layer — keep all session state in this provider.

### Screening Session Data Flow

1. `ScreeningSession.create()` → 5 named photo slots (frontView, rightCheek, leftCheek, tongue, palate)
2. Per-photo capture → `PhotoQualityService` scores brightness/sharpness/contrast (0–1); quality < 0.5 triggers retake prompt
3. Session is analyzable when: frontView is acceptable AND ≥2 other photos are acceptable
4. `ModelInferenceService` runs inference in an Isolate (never on main thread)
5. V2 aggregation logic → `ScreeningResult` → displayed in `ResultsScreen` / `DetailedResultsScreen`

### V2 Dual-Ensemble Model Logic

**Authoritative references:** `docs/APP_CLINICIAN_GUIDE.md`, `docs/BINARY_PRIMARY_RISK_GRADING.md`, and `lib/services/screening_config.dart` — always consult these before changing any threshold or decision rule.

- **Binary ensemble (3 ONNX models):** drives the final referral decision
  - Screen positive if: `maxScore ≥ 0.65` OR `hybridAvg ≥ 0.4735`
  - Retake band: hybridAvg in `[0.45, 0.50)` when screen-negative
- **5-class ensemble (3 ONNX models):** classifies lesion subtype (Healthy, Benign, OCA, OPMD, Unknown) — informational only, never overrides binary decision
  - Aggregated only on photos where binary score ≥ 0.4735 (abnormal photos)
  - Weighted vote: OCA 1.5×, OPMD 1.2×, others 1.0×; confidence < 0.5 → label "Uncertain"
- **ERI (Exposure Risk Index):** optional tobacco/alcohol questionnaire that can elevate risk tier post-inference (`lib/services/eri_service.dart`)

All thresholds live in `lib/services/screening_config.dart`. Do not hardcode thresholds elsewhere.

### Key Directories

| Path | Responsibility |
|------|---------------|
| `lib/models/` | Immutable data models: `PhotoCapture`, `ScreeningSession`, `ScreeningResult`, `ExposureData` |
| `lib/services/` | Business logic singletons: inference, quality, ERI, history (Hive), PDF reports, notifications |
| `lib/providers/` | `ScreeningProvider` — sole state manager |
| `lib/screens/` | One file per screen; `onboarding/` is a multi-step sub-flow |
| `lib/presentation/` | Maps model outputs to display text/urgency labels |
| `lib/l10n/` | 8 ARB localization files (EN, ES, HI, BN, GU, MR, TA, TE) |
| `assets/` | ONNX model files (`ensemble_model_*.onnx`, `binary_ensemble_mode_*.onnx`) |

### Image Preprocessing (must match training export)

Resize to 224×224 → normalize per ImageNet mean/std → `Float32List`. Any change here invalidates model outputs.

### Platform Stubs

- `lib/io_stub.dart` — replaces `dart:io` `File` with web-safe `Uint8List` path
- `lib/html_stub.dart` — replaces `dart:html` for non-web builds
- Web uses `ort.min.js` (ONNX Runtime Web/WASM); mobile uses the native `flutter_onnxruntime` plugin

### Local Persistence

- Session history: Hive (`hive_flutter`)
- Settings/preferences: `shared_preferences`
- No remote backend; all inference is on-device

## ML Model Development Context

Understanding this section is critical before touching inference thresholds, model assets, or training notebooks.

### Current production models in `assets/`

Both ensembles are **SSL backbone + full fine-tune**, patient-wise, from a **single training run** in `ssl_multitask_ensembles_patientwise.ipynb` (Stage 2; backbone from `ssl_caries_tmv3_pretrain_then_finetune.ipynb`).

| App asset | Training ONNX (same run) | Role in app |
|-----------|--------------------------|-------------|
| `binary_ensemble_mode_{1,2,3}.onnx` | `binary_ssl_fullft_model_{1,2,3}.onnx` | Referral decision (V2 binary ensemble) |
| `ensemble_model_{1,2,3}.onnx` | `class5_ssl_fullft_model_{1,2,3}.onnx` | Lesion subtype — informational only |

- **Run ID:** `ssl_multitask_ensembles/ssl_multitask_ensembles_20260303_120722`
- **Training ONNX dir:** `ml/training/notebooks/results/ssl_multitask_ensembles/ssl_multitask_ensembles_20260303_120722/onnx/`
- **Registry:** `model_registry.py` — `BINARY_PRODUCTION_RUN` / `FIVECLASS_PRODUCTION_RUN`; history in `production_model_registry.csv`
- **Provenance & SHA256:** `docs/MODEL_DEVELOPMENT_AND_USAGE.md` (§ Current Production Models)
- **Git:** binary ONNX since `0e82dfc`; 5-class ONNX since `1573cf4` (v0.1.11+17)
- **Filename note:** Keep `binary_ensemble_mode_*` spelling in assets (historical typo); do not rename in production.

**TM_v3 metrics (patient-wise, honest):** binary AUC **0.9202**, sens **0.8315** @ 80% spec (thr 0.4735); 5-class binary-view AUC **0.7367** (subtype only). Details: `docs/PATIENTWISE_MODEL_DEVELOPMENT.md` §6.

Superseded in app (archived): Feb 2026 image-wise full-finetune (`improved_binary_training.ipynb`, `production_oral_cavity_classifier.ipynb`).

### Data leakage discovery (patient-wise splits)

The original train/test splits were **image-wise**, which allowed multiple photos of the same patient to appear in both training and test sets. Models learned patient anatomy (lip shape, teeth) rather than pathology, inflating reported metrics. After switching to strict **patient-wise** splits (`GroupShuffleSplit` on demographic IDs):

- Binary model T5 AUC dropped from ~0.977 → **0.774** (the true generalizability baseline)
- High performance on external holdouts TB (0.992) and TC (0.950) was retained, confirming those sets were never leaked
- **0.77 AUC / 83.1% sensitivity @ 80% specificity is the honest real-world baseline**

All future model evaluations must use `TM_v3` (the patient-wise frozen test master from `frozen_test_sets.py` v3).

### Training strategy findings

Binary ensemble generations (evaluate on **TM_v3** for honest comparison):

| Generation | Strategy | TM AUC | Notes |
|------------|----------|--------|-------|
| **Production (current in app)** | SSL + full fine-tune, patient-wise | **0.9202** | `ssl_multitask_ensembles_patientwise.ipynb`; 83.15% sens @ 80% spec |
| Full fine-tune (superseded) | Image-wise splits | 0.9277 | Inflated — patient leakage; was in app pre-Mar 2026 |
| progressive_K5 (image-wise) | Head warmup → unfreeze last 5 blocks | 0.9291 | Never deployed; best image-wise strategy |
| PatientWise (ImageNet backbone) | progressive_K5, patient-wise | **0.774** | True ImageNet baseline; 83.1% sens @ 80% spec on TM_v3 |

`progressive_K5` wins on image-wise data. For patient-wise data, **SSL backbone + full fine-tune** is production.

### SSL backbone pipeline (two stages)

1. **Stage 1 — SimSiam pre-training** (`ssl_caries_tmv3_pretrain_then_finetune.ipynb`): adapts MobileNetV3-Large to oral pathology domain using unlabeled dental/oral images (dental caries dataset + TM_v3 training pool). Produces `ssl_backbone_state_dict.pth`.
2. **Stage 2 — Supervised ensembles** (`ssl_multitask_ensembles_patientwise.ipynb`): trains binary, 3-class, and 5-class ensembles on patient-wise splits using the SSL backbone. **Binary and 5-class ONNX from this notebook are deployed in `assets/`** (3-class trained but not used in the app).

Key finding: with the SSL backbone, full fine-tune (all 17 blocks trainable from epoch 1) is stronger than progressive_K5 — opposite of the ImageNet-backbone result. App screening uses calibrated thresholds in `screening_config.dart` (e.g. hybridAvg ≥ 0.4735), not raw 0.5.

### Model registry and paths

Never hardcode model paths in training notebooks — always import from `ml/training/notebooks/model_registry.py`. Run `python3 ml/training/notebooks/model_registry.py` for a path summary.

Key constants: `SSL_MULTITASK_ENSEMBLES_RUN`, `BINARY_PRODUCTION_RUN` (= SSL run), `FIVECLASS_PRODUCTION_RUN` (= SSL run), `BINARY_LEGACY_FULL_FINETUNE_RUN` (archived). Helpers: `get_binary_production_onnx_paths(app_assets=True)`, `get_fiveclass_production_onnx_paths(app_assets=True)`.

Production model archives (extra ONNX copies) are in Google Drive under `oral-cavity-production-models/`. `ml/training/notebooks/production_model_registry.csv` tracks production history (SSL rows current as of Apr 2026).

### Frozen test sets

All evaluation must use frozen manifests in `ml/training/notebooks/frozen_test_sets/`. Never evaluate on images from training manifests.

| Set | N | Description |
|-----|---|-------------|
| T5 | 534 | 5-class dataset test folder (patient-wise v3: re-split by patient ID) |
| TB | 246 | Binary dataset 15% holdout (seed=42) |
| TC | 49 | Small binary dataset 15% holdout (seed=42) |
| TM / TM_v3 | 779+ | Merged: T5+TB+TC; v3 is patient-wise clean |

Key function: `build_and_save_frozen_sets_v3()` in `frozen_test_sets.py` (v3) creates the patient-wise TM_v3 master.

### Training notebooks (ML, not Flutter)

| Notebook | Purpose |
|----------|---------|
| **`ssl_multitask_ensembles_patientwise.ipynb`** | **Current app production:** binary + 5-class SSL ensembles (patient-wise) |
| `ssl_caries_tmv3_pretrain_then_finetune.ipynb` | Stage 1: SimSiam SSL pre-training (backbone for above) |
| `improved_binary_training.ipynb` | Superseded binary (full fine-tune, image-wise) |
| `production_oral_cavity_classifier.ipynb` | Superseded 5-class (full fine-tune, image-wise) |
| `pytorch_to_onnx_ensemble.ipynb` | Convert legacy 5-class `.pth` → ONNX |
| `freeze_strategy_comparison.ipynb` | Binary freeze strategy comparison; winner: progressive_K5 |
| `improved_5class_ensemble.ipynb` | 5-class progressive_K5 + agreement analysis |
| `rebuild_T5_dataset_patientwise.ipynb` | Rebuild T5 with patient-wise splits |
| `rebuild_SMART_dataset_patientwise.ipynb` | Rebuild SMART-II with patient-wise splits |
| `train_binary_ensemble_patientwise.ipynb` | Binary patient-wise ensemble (ImageNet backbone) |
| `train_5class_ensemble_patientwise.ipynb` | 5-class patient-wise ensemble (ImageNet backbone) |

## Key Reference Documents

Canonical docs are markdown files **directly under `docs/`** (not `docs/archive/`):

- `docs/APP_CLINICIAN_GUIDE.md` — screening decision, risk, urgency, multi-photo aggregation
- `docs/BINARY_PRIMARY_RISK_GRADING.md` — binary-primary grading rules
- `docs/MODEL_DEVELOPMENT_AND_USAGE.md` — training pipelines, freeze strategy results, model registry
- `docs/PATIENTWISE_MODEL_DEVELOPMENT.md` — patient-wise leakage proof and true baseline metrics
- `docs/SSL_BACKBONE_MODELS_CREATION_AND_USAGE.md` — SSL pipeline architecture and SSL ensemble results
- `docs/TRAINING_DATASET_LOCATIONS.md` — public dataset URLs and `ORAL_DATA_ROOT` / `~/dev` conventions
- `lib/services/screening_config.dart` — threshold constants in code

Historical notes only: `docs/archive/` (superseded; do not treat as current).
