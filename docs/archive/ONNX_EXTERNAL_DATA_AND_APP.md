# ONNX external data and app deployment

## What are `.onnx.data` files?

ONNX can export models in two ways:

1. **Single file** – Graph and all weights are stored in one `.onnx` file.
2. **External data** – The `.onnx` file holds the graph (ops, shapes, tensor names) and **references** large tensors stored in a separate file, usually `<model>.onnx.data`.

External data is used when:
- The model is **larger than the protobuf limit** (~2 GB) for a single file, or
- The exporter is configured to keep weights in a separate file (e.g. for smaller `.onnx` diffs when only weights change).

So in your training output you see:
- `ensemble_model_1.onnx` (~400 KB) – graph and possibly small constants.
- `ensemble_model_1.onnx.data` (~12 MB) – large weight tensors.

Together they form the **full** model (~12 MB+).

## Do we need them at inference time?

**Yes.** If the model was exported **with** external data:

- The runtime (e.g. ONNX Runtime) must load **both** the `.onnx` and the `.onnx.data` file.
- The `.onnx` file contains paths/references to the external file (same base name, same directory by convention).
- Without the `.data` file, loading can fail or the model will have missing/empty weights (wrong or undefined behavior).

So for inference you need either:
- **Both** `.onnx` and `.onnx.data` in the same relative path, or
- A **single-file** export (no external data) that contains graph + all weights in one `.onnx`.

## Why are the app models only 400 KB?

The app’s `assets/binary_ensemble/` currently contains **only** the three `.onnx` files (~400 KB each). The `.onnx.data` files are **not** in `pubspec.yaml` or in assets.

So either:

1. **Different export** – The 400 KB files in the app were produced by a **different** export (e.g. “save with inlined data” or a smaller/quantized model) so that a single `.onnx` is self-contained. Then no `.data` file is needed and 400 KB can be correct.
2. **Missing external data** – The 400 KB files were copied from the training output **without** the `.onnx.data` files. In that case the runtime may fail to load, or may load a graph that references missing weights (unsafe). You should either add the `.data` files to the app or re-export as a single file.

## Recommendation for this repo

- **If** the training pipeline exports with external data (you see `.onnx` + `.onnx.data`):
  - **Option A:** Add the `.data` files to the app:
    - Copy each `ensemble_model_*.onnx.data` into `assets/binary_ensemble/`.
    - Add them to `pubspec.yaml` under `assets`, e.g.  
      `- assets/binary_ensemble/ensemble_model_1.onnx.data` (and same for 2 and 3).
    - Ensure the runtime loads the `.onnx` from a path where it can find the same-named `.onnx.data` (flutter_onnxruntime loads from assets; verify it resolves external data next to the `.onnx`).
  - **Option B:** Re-export for the app as a **single file** (no external data):
    - In Python: e.g. `onnx.save_model(onnx_model, path, save_as_external_data=False)` or use the ONNX helper to convert external → inlined.
    - Put the resulting single `.onnx` in `assets/binary_ensemble/` and list only that in `pubspec.yaml`.

- **If** the 400 KB app models are already a dedicated single-file export (e.g. quantized or inlined), then no `.data` files are needed; the small size is expected.

## Quick check

- Run the app and trigger binary ensemble inference. If loading fails with an error about “external data” or “tensor not found”, the app is using graph-only `.onnx` and needs the `.data` files or a single-file re-export.
- If inference runs and results look reasonable, the 400 KB assets are likely a valid single-file (or inlined) export; no change required unless you want to switch to the exact training-checkpoint export (with `.data` or a combined export).
