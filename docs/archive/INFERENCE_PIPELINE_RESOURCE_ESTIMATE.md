# Inference Service & Multi-Photo Pipeline Analysis

## Scope
This document analyzes:
1. How inference is implemented in `ModelInferenceService`.
2. How the 5-photo pipeline works end-to-end.
3. A theoretical (paper) RAM floor estimate before runtime profiling.

---

## 1) Inference architecture in app code

### 1.1 Model sets and load strategy
- The app defines two model ensembles:
  - **Ensemble A (5-class)**: `ensemble_model_1/2/3`.
  - **Ensemble B (binary referral)**: `binary_ensemble_mode_1/2/3`.
- Binary models are loaded first (lazy startup); 5-class models are loaded lazily before first screening.
- Dual-ensemble readiness requires both sets loaded.

### 1.2 Per-image inference path
- Input image is decoded, resized to **224x224**, normalized to ImageNet stats, and converted to NCHW float32 tensor.
- For dual-ensemble inference, app computes:
  1. Binary cancer probability from 3 binary models (weighted average: 0.30/0.40/0.30).
  2. 5-class probabilities from 3 class models (weighted + class-priority adjustments).
- Risk fusion uses:
  - `fusedRisk = max(binaryCancerProb, p(OCA)+p(OPMD))`
  - Risk levels by gated thresholds:
    - low: `< 0.35`
    - moderate: `0.35-<0.54`
    - high: `>= 0.54`
  - Unknown/OOD gate: if label is Unknown and `p(Unknown) > 0.6`, classify as unclear/moderate and suggest retake.

### 1.3 Multi-photo pipeline (5-photo session)
- `ScreeningProvider.analyzePhotos()` gathers captured photos and invokes `inferMultiPhoto(...)` with progress callback.
- `inferMultiPhoto(...)` loops captured photos, calling `analyzePhoto(...)` per photo.
- `analyzePhoto(...)` selects dual-ensemble if available; otherwise 5-class-only fallback.
- Non-oral filtering:
  - If class `Unknown` is top class AND `p(Unknown) > 0.6`, photo is excluded from aggregation.
- Photo weighting for aggregation:
  - `weight = quality * (0.6*binary_confidence + 0.4*five_class_confidence)`
- Top-K logic:
  - Keeps top 3 usable photos (quality >= 0.5) for weighted probability aggregation.
- Final session risk:
  - **Overall risk = max(per-photo risk level)** across analyzed photos.
  - Aggregated class probabilities are still computed using weighted averaging.

---

## 2) Part 1: Theoretical Resource Estimation (paper floor)

## 2.1 Inputs used for calculations

### 2.1.1 Observed ONNX file sizes (used as practical proxy for fp32 weights)
- Ensemble A (5-class):
  - `ensemble_model_1.onnx` = **12.2765 MiB**
  - `ensemble_model_2.onnx` = **12.2765 MiB**
  - `ensemble_model_3.onnx` = **13.2199 MiB**
  - **Total A = 37.7729 MiB**
- Ensemble B (binary):
  - `binary_ensemble_mode_1.onnx` = **12.6121 MiB**
  - `binary_ensemble_mode_2.onnx` = **12.6121 MiB**
  - `binary_ensemble_mode_3.onnx` = **13.5525 MiB**
  - **Total B = 38.7766 MiB**

### 2.1.2 Parameter estimate
Using `N_params ~= size_bytes / 4` (fp32 equivalent payload proxy):
- Ensemble A: `~9.90M params`
- Ensemble B: `~10.17M params`

> Note: ONNX files include metadata/graph structure, so this is an approximation suitable for paper-level capacity planning.

## 2.2 Static Memory Footprint (model weights)

Formula: `Size = N_params * precision_bytes`

### 2.2.1 By precision
| Ensemble | Float32 (4B) | Float16 (2B) | Uint8 (1B) |
|---|---:|---:|---:|
| Ensemble A (3 models) | 37.77 MiB | 18.89 MiB | 9.44 MiB |
| Ensemble B (3 models) | 38.78 MiB | 19.39 MiB | 9.69 MiB |

### 2.2.2 Required scenarios
- **Scenario A (Serial load)**: `max(A, B)` = **38.78 MiB** (fp32 basis)
- **Scenario B (Parallel load)**: `A + B` = **76.55 MiB** (fp32 basis)

---

## 2.3 Dynamic Memory Footprint (single-image spike)

### 2.3.1 Input tensor
App preprocesses to 224x224x3 float32:
- `224*224*3*4 = 602,112 bytes = 0.57 MiB`

Requested planning assumption (high-res in-memory image tensor):
- `1024*1024*3*4 = 12.00 MiB` per image

### 2.3.2 Activation/buffer memory
Planning heuristic from prompt for CNNs:
- **2x to 3x model weight size** during inference.

For floor calculations below, we use the lower bound:
- Activation floor = `2x * max(Ensemble A, Ensemble B)` = `2 * 38.78 = 77.55 MiB`

### 2.3.3 Browser overhead
- Floor overhead from prompt: **50 MiB** (lower bound of 50-100 range).

---

## 2.4 Deliverable table: Minimum RAM required (1 image vs 5 images held)

Assumptions for table below:
- Image holding cost uses requested 1024 tensor assumption: **12 MiB/image**.
- Activation uses floor multiplier **2x**.
- Browser overhead uses floor **50 MiB**.

### 2.4.1 Formula used
`MinRAM = StaticModels + ActivationFloor + BrowserFloor + ImagesHeld*12`

### 2.4.2 Results
| Scenario | Static models | Activation floor | Browser floor | Images held | Minimum RAM required |
|---|---:|---:|---:|---:|---:|
| Serial models, 1 image | 38.78 | 77.55 | 50 | 12 | **178.33 MiB** |
| Serial models, 5 images | 38.78 | 77.55 | 50 | 60 | **226.33 MiB** |
| Parallel models, 1 image | 76.55 | 77.55 | 50 | 12 | **216.10 MiB** |
| Parallel models, 5 images | 76.55 | 77.55 | 50 | 60 | **264.10 MiB** |

### 2.4.3 Practical note
A more realistic planning envelope should additionally consider:
- Activation closer to 3x instead of 2x,
- Browser overhead closer to 100 MiB on mobile tabs,
which can push required RAM materially higher than the floor values above.

