# Archived documentation

These files are **historical / superseded**. They are kept for context only.

**Do not use them** for current production model paths, screening thresholds, or app behavior.

## Canonical docs (use these instead)

| Topic | Document |
|-------|----------|
| Model development & production assets | [`../MODEL_DEVELOPMENT_AND_USAGE.md`](../MODEL_DEVELOPMENT_AND_USAGE.md) |
| Patient-wise splits & honest metrics | [`../PATIENTWISE_MODEL_DEVELOPMENT.md`](../PATIENTWISE_MODEL_DEVELOPMENT.md) |
| SSL backbone pipeline | [`../SSL_BACKBONE_MODELS_CREATION_AND_USAGE.md`](../SSL_BACKBONE_MODELS_CREATION_AND_USAGE.md) |
| Screening / risk interpretation | [`../APP_CLINICIAN_GUIDE.md`](../APP_CLINICIAN_GUIDE.md) |
| Binary-primary risk grading | [`../BINARY_PRIMARY_RISK_GRADING.md`](../BINARY_PRIMARY_RISK_GRADING.md) |
| Dataset sources & local path conventions | [`../TRAINING_DATASET_LOCATIONS.md`](../TRAINING_DATASET_LOCATIONS.md) |
| Threshold constants in code | `lib/services/screening_config.dart` |

Older drafts (for example former V2 inference writeups or architecture history notes) may disagree with the documents above. When in doubt, trust `docs/*.md` at the parent level and the Dart config.
