# ONNX Runtime Web Troubleshooting

## Current Issue

ONNX models are failing to load on web with error:
```
TypeError: null: type 'Null' is not a subtype of type 'JSObject'
```

## Root Cause

The error suggests that `flutter_onnxruntime` JavaScript interop is not working correctly on web. This could be due to:

1. **Version incompatibility**: Current version (1.4.3) may not fully support web
2. **Missing WebAssembly files**: ONNX Runtime Web requires WASM files to be properly deployed
3. **Asset loading issues**: Model assets may not be accessible on web

## Solution Steps

### Step 1: Upgrade flutter_onnxruntime

**Updated**: `pubspec.yaml` now uses `flutter_onnxruntime: ^1.6.2` (web support confirmed)

Run:
```bash
flutter pub get
flutter pub upgrade flutter_onnxruntime
```

### Step 2: Verify Web Support

Check if the package supports web:
```bash
flutter pub deps | grep onnx
```

### Step 3: Check Asset Deployment

Ensure model assets are included in web build:
```bash
flutter build web --release
ls -lh build/web/assets/
```

You should see all `.onnx` files listed.

### Step 4: Check WebAssembly Files

ONNX Runtime Web requires WASM files. Check if they're deployed:
```bash
ls -lh build/web/packages/flutter_onnxruntime/
```

If missing, the package may need to be rebuilt or WASM files manually added.

### Step 5: Test Model Loading

After upgrading, test again:
```bash
flutter run -d chrome
```

Watch console logs for:
- `🌐 [BinaryEnsemble] Web platform detected`
- `OnnxRuntime initialized on web`
- Model loading success/failure

## Alternative: Use onnxruntime-web Directly

If `flutter_onnxruntime` continues to fail on web, consider:

1. **Use `onnxruntime-web` JavaScript package** directly via `dart:js_interop`
2. **Load models as ArrayBuffer/Uint8List** instead of assets
3. **Create web-specific model loading code** using conditional imports

## Debug Logs Added

The code now includes detailed web-specific debug logs:
- Platform detection (`kIsWeb`)
- Initialization status
- Detailed error messages with stack traces
- Troubleshooting hints when models fail to load

## Next Steps

1. **Upgrade package**: `flutter pub upgrade flutter_onnxruntime`
2. **Rebuild**: `flutter clean && flutter pub get`
3. **Test**: `flutter run -d chrome`
4. **Check logs**: Look for web-specific debug messages
5. **If still failing**: Consider alternative approach (onnxruntime-web JS)
