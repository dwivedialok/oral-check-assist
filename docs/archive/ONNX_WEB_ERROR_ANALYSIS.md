# ONNX Runtime Web Error Analysis

## Error Details

```
TypeError: null: type 'Null' is not a subtype of type 'JSObject'
Location: package:flutter_onnxruntime/web/flutter_onnxruntime_web_plugin.dart:112
```

## Root Cause Analysis

The error occurs when `createSessionFromAsset()` tries to call JavaScript code, but the JavaScript interop returns `null` instead of a `JSObject`. This indicates:

1. **✅ Version is correct**: `pubspec.lock` shows `flutter_onnxruntime: 1.6.2` (web-supported version)
2. **✅ Dart initialization works**: "OnnxRuntime initialized on web" is printed
3. **❌ JavaScript library not loaded**: The underlying `onnxruntime-web` JavaScript library isn't available when the plugin tries to use it

## Why This Happens

`flutter_onnxruntime` on web uses `onnxruntime-web` JavaScript library under the hood. The plugin expects:
- The JavaScript library to be loaded and available as a global object
- WebAssembly files (.wasm) to be accessible
- Proper initialization before creating sessions

The error suggests the JavaScript library isn't loaded when the plugin tries to create a session.

## Possible Solutions

### Option 1: Check if Package Auto-Loads JavaScript (Most Likely)

`flutter_onnxruntime` should automatically include the JavaScript dependencies when building for web. However, there might be an initialization timing issue.

**Check**: After `flutter build web`, verify:
```bash
ls -lh build/web/packages/flutter_onnxruntime/
```

Look for:
- JavaScript files (.js)
- WebAssembly files (.wasm)
- Any initialization scripts

### Option 2: Manual JavaScript Loading (If Needed)

If the package doesn't auto-load, we may need to add script tags to `web/index.html`:

```html
<!-- ONNX Runtime Web (if not auto-loaded by plugin) -->
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web/dist/ort.min.js"></script>
```

**However**, this should NOT be necessary if the plugin handles it automatically.

### Option 3: Build Configuration Issue

The Flutter web build might not be including the plugin's web assets correctly.

**Try**:
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Option 4: Plugin Bug or Missing Dependency

This could be a bug in `flutter_onnxruntime` 1.6.2 web implementation, or the package might require additional setup.

**Check**: Visit the package's GitHub issues:
- https://github.com/masicai/flutter_onnxruntime/issues
- Search for "web" or "JSObject null" errors

## Immediate Next Steps

1. **Clean rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter build web --release
   ```

2. **Check build output**:
   ```bash
   ls -lh build/web/packages/flutter_onnxruntime/
   ```

3. **Test in release mode** (not debug):
   ```bash
   flutter run -d chrome --release
   ```

4. **Check browser console** for JavaScript errors:
   - Open DevTools → Console
   - Look for missing script errors or WASM loading failures

## Alternative: Use onnxruntime-web Directly

If `flutter_onnxruntime` continues to fail, we can:

1. **Use `onnxruntime-web` JavaScript directly** via `dart:js_interop`
2. **Load models as Uint8List** (read from assets, pass to JS)
3. **Create web-specific inference service** using conditional imports

This would require:
- Adding `onnxruntime-web` script tag to `index.html`
- Creating web-specific model loading code
- Using `dart:js_interop` to call JavaScript APIs

**Trade-off**: More code to maintain, but full control over web implementation.

## Recommendation

**First, try**:
1. Clean rebuild (`flutter clean && flutter pub get && flutter build web`)
2. Test in release mode
3. Check if JavaScript files are in build output

**If still failing**:
- Check GitHub issues for `flutter_onnxruntime` web support
- Consider filing a bug report with the package maintainers
- As last resort, implement web-specific code using `onnxruntime-web` directly

## No Separate Library Needed

**Good news**: You don't need a completely separate library. The same `flutter_onnxruntime` package should work on both mobile and web. The issue is likely:
- Build configuration
- Missing JavaScript assets
- Plugin initialization timing

The code path is the same (after preprocessing), so once models load, inference should work identically.
