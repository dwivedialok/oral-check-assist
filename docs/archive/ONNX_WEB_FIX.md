# ONNX Runtime Web Fix

## Problem

The `flutter_onnxruntime` plugin's web assets (JavaScript/WASM files) are not being included in the Flutter web build output. This causes the error:

```
TypeError: null: type 'Null' is not a subtype of type 'JSObject'
```

## Root Cause

After building for web, the `build/web/packages/flutter_onnxruntime/` directory doesn't exist, meaning the plugin's JavaScript dependencies aren't being bundled.

## Solution

Manually add the ONNX Runtime Web JavaScript library to `web/index.html`:

```html
<!-- ONNX Runtime Web - Required for flutter_onnxruntime plugin on web -->
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web@1.19.2/dist/ort.min.js"></script>
```

This script must load **before** Flutter bootstrap (`flutter_bootstrap.js`) to ensure the `ort` global object is available when the plugin tries to initialize.

## Verification

After rebuilding and testing:

1. **Check browser console** - Should see: `ONNX Runtime Web library loaded successfully`
2. **Check for errors** - The `JSObject null` error should be resolved
3. **Test model loading** - Models should load successfully on web

## Alternative: Local Assets (For Production)

For production deployment, consider downloading and hosting the JavaScript file locally instead of using CDN:

1. Download `ort.min.js` from https://cdn.jsdelivr.net/npm/onnxruntime-web@1.19.2/dist/ort.min.js
2. Place it in `web/` directory
3. Update `index.html` to use local path: `<script src="ort.min.js"></script>`

This ensures the app works offline and doesn't depend on external CDN availability.

## Next Steps

1. Rebuild: `flutter build web --release`
2. Test in browser: `flutter run -d chrome --release`
3. Verify model loading works without errors
