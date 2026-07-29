# Model Size & Lazy Loading Explained

## The Problem: 72-78 MB Model Size

### Current Situation

Your app currently loads **all 6 models immediately** when the app starts:

```dart
// In lib/main.dart - _initializeApp()
await inferenceService.initializeEnsemble(); // Loads ALL 6 models at once
```

**What happens:**
- **Mobile app**: Models are bundled in the APK/IPA (~72-78 MB larger app)
- **PWA/Web**: All 6 models must be downloaded from the server before the app can start
- **User experience**: Long loading time, especially on slow networks

### Model Breakdown

```
Total: ~72-78 MB
├── 5-class ensemble models (3 models × ~12-13 MB each)
│   ├── ensemble_model_1.onnx (~12-13 MB)
│   ├── ensemble_model_2.onnx (~12-13 MB)
│   └── ensemble_model_3.onnx (~12-13 MB)
└── Binary ensemble models (3 models × ~12-13 MB each)
    ├── binary_ensemble_mode_1.onnx (~12-13 MB)
    ├── binary_ensemble_mode_2.onnx (~12-13 MB)
    └── binary_ensemble_mode_3.onnx (~12-13 MB)
```

### Impact on Web/PWA

**Without lazy loading:**
- User visits your PWA → Downloads 72-78 MB → Waits 30-60 seconds (on 4G) → App starts
- **Problem**: User might leave before app loads

**With lazy loading:**
- User visits your PWA → Downloads app shell (~2-5 MB) → App starts immediately → Models load in background
- **Benefit**: App is usable immediately, models load when needed

---

## Solution 1: Lazy Loading (Load Models On Demand)

### What is Lazy Loading?

**Lazy loading** means loading models **only when they're actually needed**, not all at once at startup.

### Current Flow (Eager Loading)
```
App Starts → Load ALL 6 models → App Ready
            ⏱️ 30-60 seconds wait
```

### Proposed Flow (Lazy Loading)
```
App Starts → App Ready (immediate)
            ↓
User clicks "Start Screening" → Load binary models (for quick check)
            ↓
User takes photo → Load 5-class models (for detailed analysis)
```

### Implementation Strategy

#### Option A: Load by Feature (Recommended)

**Load binary models first** (for quick referral decision), then load 5-class models when needed:

```dart
class ModelInferenceService {
  // Track what's loaded
  bool _binaryModelsLoaded = false;
  bool _fiveClassModelsLoaded = false;
  
  /// Load only binary models (smaller, faster initial load)
  Future<void> loadBinaryModels() async {
    if (_binaryModelsLoaded) return;
    
    debugPrint('🔄 Loading binary models...');
    // Load only 3 binary models (~36-39 MB)
    for (String modelName in _binaryModelNames) {
      final session = await ort.createSessionFromAsset('assets/$modelName.onnx');
      _binaryEnsembleSessions[modelName] = session;
    }
    _binaryModelsLoaded = true;
  }
  
  /// Load 5-class models when needed (for detailed analysis)
  Future<void> loadFiveClassModels() async {
    if (_fiveClassModelsLoaded) return;
    
    debugPrint('🔄 Loading 5-class models...');
    // Load only 3 five-class models (~36-39 MB)
    for (String modelName in _fiveClassModelNames) {
      final session = await ort.createSessionFromAsset('assets/$modelName.onnx');
      _ensembleSessions[modelName] = session;
    }
    _fiveClassModelsLoaded = true;
  }
  
  /// Smart initialization: Load binary first, 5-class later
  Future<void> initializeEnsemble({bool loadFiveClass = false}) async {
    // Always load binary first (for quick referral)
    await loadBinaryModels();
    
    // Load 5-class only if requested (for detailed analysis)
    if (loadFiveClass) {
      await loadFiveClassModels();
    }
  }
}
```

**Usage:**
```dart
// In main.dart - Fast startup
await inferenceService.initializeEnsemble(loadFiveClass: false); // Only binary models

// Later, when user starts screening
await inferenceService.loadFiveClassModels(); // Load detailed models
```

#### Option B: Load One Model at a Time

Load models progressively as user interacts:

```dart
/// Load models one by one, starting with most important
Future<void> initializeEnsembleProgressive() async {
  // 1. Load first binary model (for quick check)
  await _loadModel('binary_ensemble_mode_2'); // Best performer
  
  // 2. Load first 5-class model
  await _loadModel('ensemble_model_2'); // Best performer
  
  // 3. Load remaining models in background
  _loadRemainingModelsInBackground();
}
```

#### Option C: Load on First Use

Load models only when user actually needs inference:

```dart
Future<Map<String, dynamic>?> infer(File imageFile) async {
  // Check if models are loaded
  if (!_ensembleReady) {
    // Load models now (first inference)
    await initializeEnsemble();
  }
  
  // Proceed with inference
  return await infer5ClassEnsemble(imageFile);
}
```

---

## Solution 2: IndexedDB for Persistent Model Storage

### What is IndexedDB?

**IndexedDB** is a browser database that can store large files (like your models) locally in the user's browser.

### Why Use IndexedDB?

**Current approach (assets):**
- Models downloaded from server every time app loads
- No caching between sessions
- Slow on every visit

**With IndexedDB:**
- Models downloaded **once** → Stored in browser → Loaded from local storage next time
- **First visit**: Download 72-78 MB (one-time)
- **Subsequent visits**: Load from IndexedDB (instant)

### How It Works

```
First Visit:
User → Download models from server → Store in IndexedDB → Use models
         ⏱️ 30-60 seconds (one time)

Next Visits:
User → Load models from IndexedDB → Use models
         ⏱️ 1-2 seconds (instant!)
```

### Implementation

#### Step 1: Store Models in IndexedDB After Download

```dart
import 'package:hive_flutter/hive_flutter.dart';

class ModelInferenceService {
  static const String _modelBoxName = 'onnx_models';
  Box<Uint8List>? _modelBox;
  
  Future<void> _initModelStorage() async {
    _modelBox = await Hive.openBox<Uint8List>(_modelBoxName);
  }
  
  /// Load model from IndexedDB or download from assets
  Future<dynamic> _loadModelWithCache(String modelName) async {
    // Check if model exists in IndexedDB
    final cachedModel = _modelBox?.get(modelName);
    if (cachedModel != null) {
      debugPrint('✅ Loaded $modelName from IndexedDB cache');
      // Create session from cached bytes
      final ort = OnnxRuntime();
      return await ort.createSessionFromList(cachedModel);
    }
    
    // Not cached - load from assets
    debugPrint('📥 Downloading $modelName from assets...');
    final ort = OnnxRuntime();
    final session = await ort.createSessionFromAsset('assets/$modelName.onnx');
    
    // Cache for next time (store model bytes in IndexedDB)
    // Note: You'll need to get the model bytes first
    // This is a simplified example - actual implementation depends on flutter_onnxruntime API
    final modelBytes = await _getModelBytes(modelName);
    await _modelBox?.put(modelName, modelBytes);
    
    return session;
  }
}
```

#### Step 2: Check Cache Before Downloading

```dart
Future<void> initializeEnsemble() async {
  // Initialize storage
  await _initModelStorage();
  
  // Load models (will use cache if available)
  for (String modelName in _fiveClassModelNames) {
    final session = await _loadModelWithCache(modelName);
    _ensembleSessions[modelName] = session;
  }
}
```

### Benefits

1. **Faster subsequent loads**: Models load from local storage (1-2 seconds vs 30-60 seconds)
2. **Offline support**: Models available even without internet (after first download)
3. **Reduced server load**: Models downloaded once per user
4. **Better UX**: App starts faster on repeat visits

---

## Combined Approach: Lazy Loading + IndexedDB

### Best Strategy

Combine both approaches for optimal performance:

```dart
class ModelInferenceService {
  /// Initialize with lazy loading + caching
  Future<void> initializeEnsemble({bool loadFiveClass = false}) async {
    // 1. Initialize IndexedDB storage
    await _initModelStorage();
    
    // 2. Load binary models (smaller, faster)
    await loadBinaryModels(); // Uses IndexedDB cache if available
    
    // 3. Load 5-class models only if requested
    if (loadFiveClass) {
      await loadFiveClassModels(); // Uses IndexedDB cache if available
    }
  }
  
  /// Load binary models (with caching)
  Future<void> loadBinaryModels() async {
    if (_binaryModelsLoaded) return;
    
    for (String modelName in _binaryModelNames) {
      // This will check IndexedDB first, then download if needed
      final session = await _loadModelWithCache(modelName);
      _binaryEnsembleSessions[modelName] = session;
    }
    _binaryModelsLoaded = true;
  }
}
```

### User Experience Flow

**First Visit:**
```
1. App loads quickly (no models yet)
2. User sees "Loading models..." indicator
3. Binary models download (~36 MB, 15-30 seconds)
4. App ready for quick screening
5. 5-class models download in background (~36 MB)
6. Full features available
```

**Subsequent Visits:**
```
1. App loads quickly
2. Models load from IndexedDB (1-2 seconds)
3. App ready immediately
```

---

## Implementation Priority

### Phase 1: Basic Lazy Loading (Quick Win)
**Effort**: 2-4 hours
**Impact**: High - App starts immediately

```dart
// Simple change: Don't load 5-class models at startup
await inferenceService.initializeEnsemble(loadFiveClass: false);

// Load when user starts screening
await inferenceService.loadFiveClassModels();
```

### Phase 2: IndexedDB Caching (Better UX)
**Effort**: 4-8 hours
**Impact**: High - Faster repeat visits

- Implement model caching in IndexedDB
- Check cache before downloading
- Store models after download

### Phase 3: Progressive Loading (Optimization)
**Effort**: 4-8 hours
**Impact**: Medium - Better perceived performance

- Load models one at a time
- Show progress indicator
- Prioritize most important models first

---

## Code Example: Simple Lazy Loading

Here's a minimal change to your current code:

```dart
// lib/main.dart - Modified initialization
Future<void> _initializeApp() async {
  try {
    final onboardingComplete = await isOnboardingComplete();
    final inferenceService = ModelInferenceService();
    
    await inferenceService.loadLabels(labelsData);
    
    // ✅ CHANGE: Load only binary models at startup
    await inferenceService.loadBinaryModels(); // New method - loads only binary
    
    // Don't load 5-class models yet - load them when user starts screening
    
    await HistoryService().initialize();
    
    setState(() {
      _isLoading = false;
      _showOnboarding = !onboardingComplete;
    });
  } catch (e) {
    // Error handling
  }
}

// lib/services/model_inference_service.dart - Add new method
Future<void> loadBinaryModels() async {
  if (_binaryEnsembleReady) return; // Already loaded
  
  debugPrint('🔄 Loading binary models (lazy load)...');
  for (String modelName in _binaryModelNames) {
    try {
      final ort = OnnxRuntime();
      final session = await ort.createSessionFromAsset('assets/$modelName.onnx');
      _binaryEnsembleSessions[modelName] = session;
      _binaryEnsembleLoaded[modelName] = true;
    } catch (e) {
      debugPrint('❌ Failed to load $modelName: $e');
    }
  }
  _binaryEnsembleReady = _binaryEnsembleSessions.isNotEmpty;
}

// When user starts screening, load 5-class models
Future<void> loadFiveClassModels() async {
  if (_ensembleReady) return; // Already loaded
  
  debugPrint('🔄 Loading 5-class models (lazy load)...');
  for (String modelName in _fiveClassModelNames) {
    try {
      final ort = OnnxRuntime();
      final session = await ort.createSessionFromAsset('assets/$modelName.onnx');
      _ensembleSessions[modelName] = session;
      _ensembleLoaded[modelName] = true;
    } catch (e) {
      debugPrint('❌ Failed to load $modelName: $e');
    }
  }
  _ensembleReady = _ensembleSessions.isNotEmpty;
}
```

---

## Summary

**Problem**: 72-78 MB models = slow app startup

**Solution 1 - Lazy Loading**: 
- Load models only when needed
- App starts immediately
- Models load in background

**Solution 2 - IndexedDB Caching**:
- Store models locally after first download
- Subsequent visits load instantly
- Works offline after first download

**Combined**: Best user experience - fast startup + instant repeat visits

**Next Step**: Start with simple lazy loading (Phase 1), then add caching (Phase 2).
