# Download ONNX Runtime Web Library

## Quick Setup

Download `ort.min.js` and place it in the `web/` directory:

```bash
cd web
curl -L -o ort.min.js https://cdn.jsdelivr.net/npm/onnxruntime-web@1.19.2/dist/ort.min.js
```

Or download manually:
1. Visit: https://cdn.jsdelivr.net/npm/onnxruntime-web@1.19.2/dist/ort.min.js
2. Save the file as `web/ort.min.js`

## Verify

After downloading, verify the file exists:
```bash
ls -lh web/ort.min.js
```

Expected size: ~2-3 MB (minified JavaScript)

## Git

**Yes, commit this file to git** - it's a dependency that should be version-controlled:
```bash
git add web/ort.min.js
git commit -m "Add ONNX Runtime Web library for flutter_onnxruntime plugin"
```

## Why Local Instead of CDN?

- ✅ Works offline (important for PWA)
- ✅ No external dependency
- ✅ Faster (no network request)
- ✅ Version-controlled (consistent across deployments)
- ✅ Works behind firewalls/corporate networks
