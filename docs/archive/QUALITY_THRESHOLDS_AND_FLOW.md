# Quality Thresholds and Analysis Flow

## Quality Thresholds

There are **TWO different thresholds** used at different stages:

### 1. **Capture/UI Threshold: 60% (0.6)**
- **Location**: `lib/services/photo_quality_service.dart` → `minAcceptableQuality = 0.6`
- **Used for**: 
  - Showing "Ready to capture" vs "Adjust position" during capture
  - Marking photos as "acceptable" vs needing "Retake" in review screen
  - `PhotoQualityMetrics.isAcceptable` getter checks `overall >= 0.6`
- **Purpose**: User-facing quality gate - photos below 60% are marked for retake

### 2. **Model Analysis Threshold: 50% (0.5)**
- **Location**: `lib/services/model_inference_service.dart` → `_qualityMin = 0.5`
- **Used for**: 
  - Determining if a photo is "usable" for aggregation in multi-photo analysis
  - Line 1148: `final bool usable = result.isValidOralPhoto && result.qualityScore >= _qualityMin;`
- **Purpose**: Lower threshold allows analysis of borderline photos (50-60% quality)

### Issue: Inconsistency
- Photos with 50-60% quality are marked "Retake" in UI but can still be analyzed
- Error message should use **0.6** (capture threshold) since that's what users see

---

## Complete Code Flow: Photo Capture → Analysis

### Step 1: Photo Capture (Web & Mobile)

**File**: `lib/screens/photo_capture_screen.dart`

```dart
// Camera or Gallery pick
final XFile? image = await _picker.pickImage(...);
final bytes = await image.readAsBytes();

// Quality assessment (same for web & mobile)
final quality = kIsWeb
    ? await provider.assessQualityFromBytes(bytes)  // Web: uses bytes
    : await provider.assessQuality(io.File(image.path));  // Mobile: uses File

// Store preview
_previewImage = io.File(image.path);  // Stub on web, real File on mobile
_previewImageBytes = kIsWeb ? bytes : null;  // Only on web
_currentQuality = quality;
```

**Key Point**: Quality is assessed **before** confirming the photo.

---

### Step 2: Confirm Photo → Store in Session

**File**: `lib/screens/photo_capture_screen.dart` → `_confirmPhoto()`

```dart
if (kIsWeb && _previewImageBytes != null) {
  await provider.capturePhoto(
    widget.photoType,
    _previewImage!,
    knownQuality: _currentQuality,  // Pass pre-computed quality
    imageBytes: _previewImageBytes,  // Pass bytes for web inference
  );
}
```

**File**: `lib/providers/screening_provider.dart` → `capturePhoto()`

```dart
final capture = PhotoCapture(
  type: type,
  image: imageFile,  // Stub on web, real File on mobile
  qualityMetrics: qualityMetrics,  // From capture assessment
  imageBytes: imageBytes,  // Only on web
);
_currentSession = _currentSession!.updatePhoto(capture);
```

---

### Step 3: Start Analysis

**File**: `lib/providers/screening_provider.dart` → `analyzePhotos()`

```dart
final capturedPhotos = _currentSession!.photos.where((p) => p.isCaptured).toList();

final result = await _inferenceService.inferMultiPhoto(
  capturedPhotos,
  onPhotoProgress: updateAnalyzingProgress,  // Updates UI progress (P1..P5)
);
```

---

### Step 4: Analyze Each Photo (SAME CODE PATH for Web & Mobile!)

**File**: `lib/services/model_inference_service.dart` → `analyzePhoto()`

```dart
Future<PhotoResult> analyzePhoto(PhotoCapture photo) async {
  final useBytes = photo.imageBytes != null;  // true on web, false on mobile
  
  Map<String, dynamic>? result;
  
  if (dualEnsembleReady) {
    // DUAL-ENSEMBLE PATH (binary + 5-class)
    if (useBytes) {
      // WEB: Uses bytes directly
      result = await inferDualEnsembleFromBytes(photo.imageBytes!);
    } else {
      // MOBILE: Reads File to bytes internally
      result = await inferDualEnsemble(
        photo.image!,
        qualityScore: photo.qualityMetrics.overall,
        isValidOralPhoto: true,
      );
    }
  } else {
    // 5-CLASS ONLY PATH
    if (useBytes) {
      result = await infer5ClassEnsembleFromBytes(photo.imageBytes!);
    } else {
      result = await inferWithProbabilities(photo.image!);
    }
  }
  
  // Extract probabilities, risk level, etc.
  return PhotoResult(...);
}
```

**Key Point**: After determining `useBytes`, both paths converge:
- **Web**: `inferDualEnsembleFromBytes()` → `_preprocessImageFromBytes()` → ONNX inference
- **Mobile**: `inferDualEnsemble()` → reads File → `_preprocessImageForONNX()` → ONNX inference

Both use **identical preprocessing** (ImageNet normalization, 224x224 resize) and **same ONNX models**.

---

### Step 5: Preprocessing (Web vs Mobile - Same Logic!)

**Web Path**: `_preprocessImageFromBytes(Uint8List raw)`
```dart
final decoded = img.decodeImage(raw);  // Decode bytes
final resized = img.copyResize(decoded, width: 224, height: 224);
// ImageNet normalization: (pixel/255 - mean) / std
// Returns Float32List[1, 3, 224, 224] for ONNX
```

**Mobile Path**: `_preprocessImageForONNX(io.File imageFile)`
```dart
final raw = await imageFile.readAsBytes();  // Read File to bytes
final decoded = img.decodeImage(raw);  // Same decode
final resized = img.copyResize(decoded, width: 224, height: 224);
// Same ImageNet normalization
// Returns Float32List[1, 3, 224, 224] for ONNX
```

**Result**: Both produce **identical input tensors** for ONNX models.

---

### Step 6: ONNX Inference

**Same for both paths**: 
- Binary ensemble: 3 models → average → cancer probability
- 5-class ensemble: 5 models → weighted average → class probabilities
- Dual-ensemble fusion: combines binary + 5-class → final risk level

---

## Testing on Local Chrome with Gallery Photos

**Yes, this is the right approach!** The code path is identical after preprocessing:

1. **Pick from gallery** → `XFile.readAsBytes()` → bytes
2. **Quality assessment** → `assessQualityFromBytes(bytes)`
3. **Analysis** → `inferDualEnsembleFromBytes(bytes)` → same ONNX inference as mobile

**To test locally:**

```bash
# Run Flutter web locally
flutter run -d chrome --web-hostname 0.0.0.0

# Or build and serve
flutter build web --release
cd build/web
python3 -m http.server 8000
# Open http://localhost:8000 in Chrome
```

**Debug logs to add:**

1. In `analyzePhoto()` - log when analysis starts/fails
2. In `inferDualEnsembleFromBytes()` - log preprocessing success/failure
3. In `_preprocessImageFromBytes()` - log decoded image dimensions
4. In ONNX inference - log model outputs

---

## Recommended Fixes

1. **Use consistent threshold (0.6) for error messages** ✅ (already fixed)
2. **Add comprehensive debug logs** (see below)
3. **Consider**: Should model analysis threshold be 0.6 too? (Currently 0.5 allows borderline photos)
