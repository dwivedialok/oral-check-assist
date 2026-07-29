# PWA Deployment Quick Start Guide

## Testing Without Deploying (No Firebase, No Domain)

You do **not** need Firebase, a domain, or to deploy anything to test the PWA locally.

### Option A: Flutter dev server (easiest)

```bash
# From project root
flutter run -d chrome
# or
flutter run -d web-server
```

- **chrome**: Opens the app in Chrome at a URL like `http://localhost:xxxxx`.
- **web-server**: Starts a server and prints the URL; open it in any browser.

**localhost is a secure context**: Camera, storage, and service workers work on `http://localhost`, so you can test everything without HTTPS.

### Option B: Release build + local server

```bash
flutter build web --release
cd build/web
python3 -m http.server 8000
```

Then open **http://localhost:8000** in your browser.

### Option C: Firebase Hosting emulator (optional)

If you want to test the same setup as production without deploying:

```bash
npm install -g firebase-tools
firebase init hosting   # set public directory to build/web
flutter build web --release
firebase emulator:start --only hosting
```

Open the URL shown (e.g. http://localhost:5000). Still no deploy and no domain.

### When you need a real URL / domain

- **Internal testers**: Deploy to Firebase Hosting once; you get `https://your-project-id.web.app` (no custom domain needed).
- **Custom domain**: Only if you want something like `https://yourapp.com`; optional.

---

## Quick Test: Can Your App Run on Web?

### Step 1: Test Flutter Web Build (5 minutes)

```bash
# Build for web
flutter build web --release

# Check for errors
# If successful, you'll see: build/web/ directory created
```

### Step 2: Test Locally (Optional)

```bash
cd build/web
python3 -m http.server 8000
# Visit http://localhost:8000 in your browser
```

**What to check:**
- ✅ App loads without errors
- ✅ UI renders correctly
- ⚠️ Model loading (may fail - that's expected, see below)
- ⚠️ Camera access (test on mobile device or Chrome with camera)

---

## Common Issues & Quick Fixes

### Issue 1: ONNX Runtime Not Found
**Error**: `flutter_onnxruntime` doesn't support web

**Solution**: Check if package supports web:
```bash
flutter pub deps | grep onnx
```

**If not supported**, you'll need to:
- Use `onnxruntime-web` (JavaScript) or `onnxruntime-wasm` (WebAssembly)
- Create web-specific model loading code

**Quick test**: Comment out model loading, see if app runs.

### Issue 2: Camera Not Working
**Error**: Camera permission denied or not available

**Solution**: 
- Test on **HTTPS** (required for camera API)
- Use Firebase Hosting (provides HTTPS)
- Test on mobile device (better camera support)

### Issue 3: File System Errors
**Error**: `path_provider` returns null on web

**Solution**: Use conditional imports:
```dart
import 'package:path_provider/path_provider.dart' 
  if (dart.library.html) 'package:path_provider/path_provider_web.dart';
```

---

## Firebase Hosting Setup (15 minutes)

**Do I need a new Firebase project?** No. If you already have Firebase projects, use one of them. Only create a new project in the [Firebase console](https://console.firebase.google.com/) if you want this PWA in its own project (e.g. separate billing or team).

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Login
```bash
firebase login
```

### 3. Initialize Hosting
```bash
# In your project root
firebase init hosting
```

**Select:**
- ✅ **Use an existing project** — pick one of your current Firebase projects (or "Create a new project" only if you want a dedicated one for this app)
- ✅ Public directory: `build/web`
- ✅ Single-page app: Yes
- ✅ GitHub Actions: No (for now)

### 4. Create `firebase.json` (if not created)
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp|onnx)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000, immutable"
          }
        ]
      }
    ]
  }
}
```

### 5. Deploy
```bash
# Build Flutter web
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

### 6. Access Your PWA
- URL: `https://your-project-id.web.app`
- Or custom domain if configured

### Do I need to add Firebase config (apiKey, projectId, etc.)?
**No, not for Hosting only.** That config is for Firebase client features (Auth, Firestore, Analytics). Serving the PWA via Firebase Hosting does not require it.  
If you later add Auth or Firestore, use [FlutterFire](https://firebase.flutter.dev/) and run `flutterfire configure`; it will generate `lib/firebase_options.dart` for you — don’t paste the web config into the app.

---

## Testing Checklist

### Before Deployment
- [ ] Flutter web builds without errors
- [ ] App UI renders correctly
- [ ] No console errors (check browser DevTools)
- [ ] Models load (or graceful error handling)

### After Deployment
- [ ] PWA installs on mobile (Add to Home Screen)
- [ ] Camera access works (test on device)
- [ ] Gallery/file picker works
- [ ] History saves correctly
- [ ] PDF generation works
- [ ] Works offline (with service worker)

---

## Quick Fixes for Common Web Issues

### Fix 1: Conditional Imports for Platform-Specific Code

**File**: `lib/services/history_service.dart`
```dart
import 'package:path_provider/path_provider.dart' 
  if (dart.library.html) 'package:path_provider/path_provider_web.dart';
```

### Fix 2: Web-Specific PDF Download

**File**: `lib/services/report_service.dart`
```dart
import 'package:flutter/foundation.dart';

Future<void> shareReport(ScreeningResult result, [AppLocalizations? l10n]) async {
  final file = await generatePDFReport(result, l10n);
  
  if (kIsWeb) {
    // Web: Download PDF
    final bytes = await file.readAsBytes();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'oral_screening_report.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    // Mobile: Use share_plus
    await Share.shareXFiles([XFile(file.path)]);
  }
}
```

**Add import**:
```dart
import 'dart:html' as html;
```

### Fix 3: Web-Specific Photo Storage

**File**: `lib/services/history_service.dart`
```dart
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

Future<void> saveScreening(ScreeningResult result, [List<PhotoCapture>? photos]) async {
  // ... existing code ...
  
  if (photos != null && photos.isNotEmpty) {
    if (kIsWeb) {
      // Web: Store as bytes in Hive
      savedPhotoPaths = {};
      for (final capture in photos) {
        if (capture.image != null) {
          final bytes = await capture.image!.readAsBytes();
          final key = 'photo_${id}_${capture.type.name}';
          await _box!.put(key, bytes);
          savedPhotoPaths[capture.type.name] = key; // Store key instead of path
        }
      }
    } else {
      // Mobile: Copy to file system
      // ... existing code ...
    }
  }
}
```

---

## Minimal Viable PWA (MVP) Approach

If you want to deploy quickly with minimal changes:

1. **Disable model loading temporarily** (for testing)
   - Comment out `initializeEnsemble()` call
   - Show "Models loading..." message

2. **Disable PDF sharing** (use download only)
   - Remove `share_plus` dependency for web
   - Implement simple download

3. **Use Hive as-is** (should work on web)
   - Test history saving
   - If photos don't work, disable photo persistence temporarily

4. **Deploy and test**
   - Get basic PWA working first
   - Iterate on improvements

---

## Need Help?

### Check These Resources:
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [Firebase Hosting Guide](https://firebase.google.com/docs/hosting)
- [PWA Best Practices](https://web.dev/progressive-web-apps/)

### Debug Tips:
1. **Check browser console** for errors
2. **Test on mobile device** (better than desktop for camera)
3. **Use HTTPS** (required for camera API)
4. **Check network tab** for failed asset loads

---

## Next Steps After Basic Deployment

1. ✅ Get basic PWA working
2. ✅ Test on real devices
3. ⚠️ Fix model loading (if needed)
4. ⚠️ Fix photo storage
5. ⚠️ Implement PDF download
6. ✅ Add service worker for offline support
7. ✅ Optimize loading performance

---

**Estimated Time**: 
- Basic deployment: 1-2 hours
- Full feature parity: 1-2 weeks
