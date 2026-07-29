# ONNX Runtime Web WASM Files Fix

## Problem

After adding `ort.min.js` locally, ONNX Runtime Web is trying to load WASM files dynamically but can't find them:

```
Failed to fetch dynamically imported module: http://0.0.0.0:49245/ort-wasm-simd-threaded.mjs
```

## Root Cause

`onnxruntime-web` requires additional WebAssembly (WASM) files to run:
- `ort-wasm-simd-threaded.wasm` (or `.mjs` module)
- `ort-wasm-simd-threaded.worker.js` (for threading)
- Other WASM variants

When using a local `ort.min.js`, these files need to be:
1. Downloaded and placed in the web directory
2. Configured via `ort.env.wasm.wasmPaths`

## Solution: Use CDN (Temporary Fix)

For now, switching back to CDN version which automatically handles WASM file loading:

```html
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web@1.19.2/dist/ort.min.js"></script>
```

The CDN version automatically resolves WASM file paths correctly.

## Alternative: Local WASM Files (For Production)

To use local files for offline support:

### Step 1: Download Required Files

Download from CDN:
- `ort.min.js` → `web/ort.min.js`
- `ort-wasm-simd-threaded.wasm` → `web/ort-wasm-simd-threaded.wasm`
- `ort-wasm-simd-threaded.mjs` → `web/ort-wasm-simd-threaded.mjs`
- `ort-wasm-simd-threaded.worker.js` → `web/ort-wasm-simd-threaded.worker.js`

Or use npm:
```bash
npm install onnxruntime-web
cp node_modules/onnxruntime-web/dist/*.wasm web/
cp node_modules/onnxruntime-web/dist/*.mjs web/
cp node_modules/onnxruntime-web/dist/*.worker.js web/
```

### Step 2: Configure WASM Paths

Update `web/index.html`:

```html
<script src="ort.min.js"></script>
<script>
  if (typeof ort !== 'undefined' && ort.env && ort.env.wasm) {
    // Point to local WASM files
    ort.env.wasm.wasmPaths = './';
    console.log('ONNX Runtime Web configured to use local WASM files');
  }
</script>
```

### Step 3: Ensure Files Are Copied to Build

Add to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - web/ort.min.js
    - web/ort-wasm-simd-threaded.wasm
    - web/ort-wasm-simd-threaded.mjs
    - web/ort-wasm-simd-threaded.worker.js
```

Or manually copy to `build/web/` after build.

## Current Status

Using CDN version for now to unblock development. Switch to local files before production deployment for offline support.
