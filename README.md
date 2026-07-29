# Oral Cavity Classifier (Oral Check Assist)

Flutter app for **AI-assisted oral cavity screening** from phone photos. It produces risk-stratified guidance on whether specialist follow-up may be advisable — especially for people with tobacco or alcohol exposure history.

> **This is a screening aid, not a diagnosis tool.** It does not diagnose oral cancer or any disease. Clinical decisions belong to qualified healthcare professionals.

**License:** [Apache License 2.0](LICENSE)

---

## Features

- Multi-photo screening session (front view, cheeks, tongue, palate)
- On-device dual ensemble (binary referral + 5-class subtype)
- Photo quality checks and retake prompts
- Optional exposure / lifestyle risk context (ERI)
- Offline inference (no network required for prediction)
- Android, iOS, and web (PWA)

---

## Quick start

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (stable; see `pubspec.yaml` for SDK constraint)
- [Git LFS](https://git-lfs.com) — required for model weights in `assets/`
- Android Studio and/or Xcode; Chrome for web

### Clone and run

```bash
git lfs install
git clone https://github.com/3amwave/oral-cavity-classifier.git
cd oral-cavity-classifier
git lfs pull
flutter pub get
flutter run
```

Without Git LFS, files under `assets/` may be tiny pointer stubs and inference will fail. Verify models with:

```bash
bash scripts/verify_model_assets.sh
```

Other useful commands: `flutter test`, `flutter analyze`, `flutter run -d web-server`. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## How screening works (summary)

1. **Binary ensemble** (3 ONNX models) — P(abnormal); drives refer / not-refer.
2. **5-class ensemble** (3 ONNX models) — Healthy, Benign, OPMD, OCA, Unknown; subtype and wording only; does **not** override the binary decision.

Session hybrid rule (usable photos): screen positive if `maxScore ≥ 0.65` **or** `hybridAvg ≥ 0.4735`. Thresholds live in `lib/services/screening_config.dart`.

Full clinical interpretation: [docs/APP_CLINICIAN_GUIDE.md](docs/APP_CLINICIAN_GUIDE.md) and [docs/BINARY_PRIMARY_RISK_GRADING.md](docs/BINARY_PRIMARY_RISK_GRADING.md).

---

## Models

Production weights are **SSL backbone + full fine-tune**, patient-wise splits, under `assets/`:

| Asset pattern | Role |
|---------------|------|
| `binary_ensemble_mode_{1,2,3}.onnx` | Referral decision |
| `ensemble_model_{1,2,3}.onnx` | Lesion subtype (informational) |

Details, registry, and training notebooks: [docs/MODEL_DEVELOPMENT_AND_USAGE.md](docs/MODEL_DEVELOPMENT_AND_USAGE.md) and [docs/PATIENTWISE_MODEL_DEVELOPMENT.md](docs/PATIENTWISE_MODEL_DEVELOPMENT.md).

Training **images are not in this repository**. Dataset sources and local path conventions (including `ORAL_DATA_ROOT`): [docs/TRAINING_DATASET_LOCATIONS.md](docs/TRAINING_DATASET_LOCATIONS.md).

---

## Documentation

| Doc | Purpose |
|-----|---------|
| [docs/MODEL_DEVELOPMENT_AND_USAGE.md](docs/MODEL_DEVELOPMENT_AND_USAGE.md) | Canonical model development & production paths |
| [docs/PATIENTWISE_MODEL_DEVELOPMENT.md](docs/PATIENTWISE_MODEL_DEVELOPMENT.md) | Patient-wise splits and honest metrics |
| [docs/SSL_BACKBONE_MODELS_CREATION_AND_USAGE.md](docs/SSL_BACKBONE_MODELS_CREATION_AND_USAGE.md) | SSL pretrain → fine-tune pipeline |
| [docs/APP_CLINICIAN_GUIDE.md](docs/APP_CLINICIAN_GUIDE.md) | Risk interpretation for clinicians |
| [docs/BINARY_PRIMARY_RISK_GRADING.md](docs/BINARY_PRIMARY_RISK_GRADING.md) | Binary-primary grading rules |
| [docs/TRAINING_DATASET_LOCATIONS.md](docs/TRAINING_DATASET_LOCATIONS.md) | Public dataset URLs & local roots |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting |

Historical / superseded notes: [docs/archive/](docs/archive/) (not authoritative).

---

## Privacy

- Inference runs on-device.
- Images are not uploaded for classification by default.
- Users retain control of captured photos.

Deploy scripts may target maintainer Firebase Hosting; that is optional and not required for local development.

---

## Medical disclaimer

This application provides an AI-assisted **initial visual screening aid** to help determine whether clinical follow-up may be advisable. It does **not** diagnose oral cancer or any other disease. It is not a certified medical device. Clinical decisions must be made by qualified healthcare professionals.

---

## License

Copyright 2024–2026 3AM Wave and contributors.

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
