# Contributing

Thanks for your interest in improving this project. This is an AI-assisted **oral screening aid**, not a diagnostic device — keep that framing in docs, UI copy, and discussions.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (stable; see `pubspec.yaml` for Dart SDK constraint)
- [Git LFS](https://git-lfs.com) — **required** to fetch ONNX/TFLite weights under `assets/`
- Platform tooling for your target (Android SDK and/or Xcode; Chrome for web)

```bash
git lfs install
git clone <repo-url>
cd oral-cavity-classifier
git lfs pull
flutter pub get
```

Without Git LFS, files in `assets/` may be tiny pointer stubs and inference will fail.

## Development

```bash
flutter run                 # device / emulator
flutter run -d web-server   # web
flutter test
flutter analyze
bash scripts/verify_model_assets.sh
```

## What lives in this repo

| Included | Not included |
|----------|----------------|
| Flutter app, ONNX assets (via LFS), training notebooks | Training images / patient datasets |
| Docs under `docs/*.md` (canonical) | Secrets, keystores, private Drive archives |

Training datasets must be obtained from their public sources (see `docs/TRAINING_DATASET_LOCATIONS.md`). Frozen test manifests may contain machine-local paths; set data roots via `~/dev/...` conventions or an `ORAL_DATA_ROOT` override as documented in `ml/training/notebooks/frozen_test_sets.py`.

## Documentation

- **Canonical:** markdown files directly under `docs/` (especially `MODEL_DEVELOPMENT_AND_USAGE.md` and `PATIENTWISE_MODEL_DEVELOPMENT.md`).
- **Historical:** `docs/archive/` — superseded notes; do not treat as current.
- Screening thresholds: `docs/APP_CLINICIAN_GUIDE.md` and `lib/services/screening_config.dart`.

## Pull requests

- Keep changes focused; do not mix model-accuracy experiments with docs/legal cleanup unless necessary.
- Do not hardcode personal emails, absolute home-directory paths, or signing secrets.
- Run `flutter analyze` and relevant tests before requesting review.
- For threshold or decision-rule changes, update `screening_config.dart` and the clinician guide together.

## License

By contributing, you agree that your contributions are licensed under the Apache License, Version 2.0 (see `LICENSE`).
