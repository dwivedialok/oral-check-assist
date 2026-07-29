# UNKNOWN Photo Filtering & Label-to-Text Conversion

## Overview

This document explains how non-oral photos are detected using the UNKNOWN label and where model predictions are converted to user-facing text.

---

## 🔍 UNKNOWN Label Check for Non-Oral Photos

### Current Implementation

**Location**: `lib/services/model_inference_service.dart`

#### 1. UNKNOWN Threshold Definition
```dart
// Line ~671
/// Threshold for UNKNOWN probability to consider photo as non-oral
/// Photo is marked as non-oral ONLY if:
/// 1. UNKNOWN is the predicted class (highest probability), AND
/// 2. UNKNOWN probability > this threshold
static const double _unknownThreshold = 0.6;  // 60% threshold
```

#### 2. Check in `analyzePhoto()` Method
```dart
// Lines ~847-854
// Check if photo is likely non-oral (high UNKNOWN probability)
// UNKNOWN class indicates the image is not of oral cavity
bool isValidOralPhoto = true;
if (classProbs != null && classProbs.unknown > _unknownThreshold) {
  isValidOralPhoto = false;
  debugPrint('⚠️ [MultiPhoto] Photo ${photo.type.displayName} likely non-oral (UNKNOWN prob: ${(classProbs.unknown * 100).toStringAsFixed(1)}%)');
}
```

**Logic**: If UNKNOWN probability > 70%, the photo is marked as non-oral (`isValidOralPhoto = false`).

#### 3. Filtering in Multi-Photo Aggregation
```dart
// Lines ~888-892
final result = await analyzePhoto(photo);
photoResults.add(result);

// Skip non-oral photos (high UNKNOWN probability indicates non-oral image)
if (!result.isValidOralPhoto) {
  debugPrint('⏭️ [MultiPhoto] Skipping non-oral photo: ${photo.type.displayName}');
  continue;  // Skip this photo from aggregation
}
```

**Effect**: Non-oral photos are excluded from risk aggregation but still shown in results with a warning.

---

## 📝 Model Output to Text Conversion

### Where Labels Come From

#### 1. Class Labels Array
**Location**: `lib/services/model_inference_service.dart` (Line 55)
```dart
final List<String> _classLabels = ['Benign', 'Healthy', 'OCA', 'OPMD', 'Unknown'];
```

**Order**: Matches model output indices:
- Index 0: Benign
- Index 1: Healthy
- Index 2: OCA
- Index 3: OPMD
- Index 4: Unknown

#### 2. Model Inference → Label Conversion

**TFLite Inference** (Lines ~350-356):
```dart
// Get max probability index
int maxIdx = 0;
double maxVal = probs[0];
for (int i = 1; i < probs.length; i++) {
  if (probs[i] > maxVal) {
    maxVal = probs[i];
    maxIdx = i;
  }
}

// Convert index to label text
final predicted = (maxIdx < labels.length) ? labels[maxIdx] : 'Unknown';
final confidence = maxVal * 100.0;

return {'label': predicted, 'confidence': confidence};
```

**ONNX Inference** (Lines ~476-484):
```dart
// Same argmax logic
final predicted = (maxIdx < labels.length) ? labels[maxIdx] : 'Unknown';
final confidence = maxVal * 100.0;

return {'label': predicted, 'confidence': confidence};
```

**Ensemble Inference** (Lines ~568-575):
```dart
final predictedClass = _classLabels[maxIdx] ?? 'Unknown';

final result = {
  'class': predictedClass,
  'confidence': maxVal,
  'probabilities': probabilities,
  'modelName': modelName,
};
```

#### 3. ClassProbabilities → Predicted Class Text

**Location**: `lib/models/screening_result.dart` (Lines 89-95)
```dart
/// Get the predicted class name
String get predictedClass {
  final maxProb = [healthy, benign, opmd, oca, unknown].reduce((a, b) => a > b ? a : b);
  if (maxProb == healthy) return 'Healthy';
  if (maxProb == benign) return 'Benign';
  if (maxProb == opmd) return 'OPMD';
  if (maxProb == oca) return 'OCA';
  return 'Unknown';
}
```

---

## 🔄 Complete Flow: Model Output → User Text

### Step-by-Step Flow

1. **Model Inference** (`inferTFLite()`, `inferONNX()`, `infer5ClassEnsemble()`)
   - Model outputs: `[prob_benign, prob_healthy, prob_oca, prob_opmd, prob_unknown]`
   - Example: `[0.1, 0.2, 0.05, 0.03, 0.62]` → max index = 4 (Unknown)

2. **Index to Label** (Line 353, 479, 568)
   - `maxIdx = 4` → `_classLabels[4]` → `'Unknown'`
   - Returns: `{'label': 'Unknown', 'confidence': 62.0}`

3. **Probability Extraction** (`inferWithProbabilities()`)
   - Extracts full probability array
   - Creates `ClassProbabilities` object

4. **Non-Oral Check** (`analyzePhoto()`)
   - Checks: `classProbs.unknown > 0.7` → `isValidOralPhoto = false`
   - Example: `0.62 < 0.7` → Still valid (borderline)
   - Example: `0.75 > 0.7` → Non-oral, skip from aggregation

5. **Display Text** (`PhotoResult.statusMessage`, `ClassProbabilities.predictedClass`)
   - Non-oral photos show: `"Not an oral photo"`
   - Valid photos show: `"Low Risk"`, `"Moderate Risk"`, `"High Risk"`, or `"Unknown"`

---

## 📍 Where Text is Shown to Users

### 1. Results Screen
**File**: `lib/screens/results_screen.dart`
- Uses `result.overallRisk.displayName` → `"Low Risk"`, `"Moderate Risk"`, `"High Risk"`
- Uses `result.recommendations` → List of recommendation strings

### 2. Detailed Results Screen
**File**: `lib/screens/detailed_results_screen.dart`
- Uses `photo.statusMessage` → Shows `"Not an oral photo"` for non-oral photos
- Uses `photo.classProbabilities.predictedClass` → `"Healthy"`, `"Benign"`, `"OPMD"`, `"OCA"`, `"Unknown"`

### 3. Photo Status Display
**File**: `lib/models/screening_result.dart` (Lines 156-162)
```dart
String get statusMessage {
  if (!isValidOralPhoto) return 'Not an oral photo';
  if (!isAnalyzed) return 'Quality issue - could not analyze';
  return riskLevel?.displayName ?? 'Analyzed';
}
```

### 4. Risk Level Display Names
**File**: `lib/models/screening_result.dart` (Lines 10-18)
```dart
String get displayName {
  switch (this) {
    case RiskLevel.low: return 'Low Risk';
    case RiskLevel.moderate: return 'Moderate Risk';
    case RiskLevel.high: return 'High Risk';
  }
}
```

---

## ⚠️ Current Limitations

### 1. UNKNOWN Threshold is Fixed
- Currently hardcoded at 70% (`_unknownThreshold = 0.7`)
- May need tuning based on model performance
- **Future**: Make configurable or learn from validation data

### 2. No Multi-Head Oral Filter Yet
- Current models only have 5-class output (including Unknown)
- Multi-head model (when trained) will have dedicated `Head C` for oral vs not-oral
- **Future**: Use `oralProb` from multi-head model instead of UNKNOWN probability

### 3. Non-Oral Photos Still Shown in Results
- Non-oral photos are excluded from aggregation but still displayed
- User sees warning: `"Not an oral photo"` in detailed results
- **Future**: Option to hide non-oral photos or show separate section

---

## 🎯 Recommended Improvements

### 1. Adjustable Threshold
```dart
// Make threshold configurable
static double unknownThreshold = 0.7;

// Or use model-specific thresholds
final Map<ModelType, double> unknownThresholds = {
  ModelType.tflite: 0.65,
  ModelType.onnx: 0.70,
  ModelType.ensemble: 0.75,
};
```

### 2. Better User Feedback
```dart
// In PhotoResult
String get userFriendlyMessage {
  if (!isValidOralPhoto) {
    return 'This photo doesn\'t appear to be of your mouth. Please retake.';
  }
  // ... rest of logic
}
```

### 3. Multi-Head Model Support
```dart
// When multi-head model is available
if (hasMultiHeadModel) {
  final oralProb = result['oralProb'] as double;
  isValidOralPhoto = oralProb >= 0.8;  // Use dedicated oral filter
} else {
  // Fallback to UNKNOWN check
  isValidOralPhoto = classProbs.unknown <= _unknownThreshold;
}
```

---

## 📊 Example Scenarios

### Scenario 1: Clear Non-Oral Photo
```
Model Output: [0.02, 0.05, 0.01, 0.02, 0.90]
              [Benign, Healthy, OCA, OPMD, Unknown]

Check: predictedClass = Unknown (max = 0.90)
       unknown = 0.90 > 0.60 (threshold) → NON-ORAL
Result: isValidOralPhoto = false
Display: "Not an oral photo" in detailed results
Aggregation: Photo skipped from risk calculation
```

### Scenario 2: Borderline Non-Oral (UNKNOWN is max but moderate)
```
Model Output: [0.08, 0.12, 0.05, 0.07, 0.68]
              [Benign, Healthy, OCA, OPMD, Unknown]

Check: predictedClass = Unknown (max = 0.68)
       unknown = 0.68 > 0.60 (threshold) → NON-ORAL
Result: isValidOralPhoto = false
Display: "Not an oral photo" - photo likely not of oral cavity
Aggregation: Photo skipped from risk calculation
```

### Scenario 3: UNKNOWN is max but below threshold (treated as valid)
```
Model Output: [0.15, 0.18, 0.08, 0.09, 0.50]
              [Benign, Healthy, OCA, OPMD, Unknown]

Check: predictedClass = Unknown (max = 0.50)
       unknown = 0.50 < 0.60 (threshold) → VALID (borderline)
Result: isValidOralPhoto = true
Display: Risk level based on OPMD+OCA probability
Note: Model is uncertain but we still analyze it
```

### Scenario 4: UNKNOWN is high but NOT the max class (valid oral)
```
Model Output: [0.10, 0.45, 0.05, 0.05, 0.35]
              [Benign, Healthy, OCA, OPMD, Unknown]

Check: predictedClass = Healthy (max = 0.45)
       UNKNOWN is NOT the max → VALID ORAL
Result: isValidOralPhoto = true
Display: "Low Risk" (Healthy detected)
Note: Even though UNKNOWN is 35%, Healthy is higher so it's valid
```

### Scenario 5: Clear Oral Photo
```
Model Output: [0.60, 0.25, 0.05, 0.08, 0.02]
              [Benign, Healthy, OCA, OPMD, Unknown]

Check: predictedClass = Benign (max = 0.60)
       UNKNOWN is NOT the max → VALID ORAL
Result: isValidOralPhoto = true
Predicted: "Benign" (max probability)
Display: "Low Risk" (OPMD+OCA = 0.13 < 0.3 threshold)
Aggregation: Photo included in risk calculation
```

---

## 🔗 Related Code Locations

| Feature | File | Lines |
|---------|------|-------|
| UNKNOWN threshold | `lib/services/model_inference_service.dart` | ~671 |
| Non-oral check | `lib/services/model_inference_service.dart` | ~847-854 |
| Filtering in aggregation | `lib/services/model_inference_service.dart` | ~888-892 |
| Class labels array | `lib/services/model_inference_service.dart` | ~55 |
| Label conversion (TFLite) | `lib/services/model_inference_service.dart` | ~350-356 |
| Label conversion (ONNX) | `lib/services/model_inference_service.dart` | ~476-484 |
| Label conversion (Ensemble) | `lib/services/model_inference_service.dart` | ~568-575 |
| Predicted class getter | `lib/models/screening_result.dart` | ~89-95 |
| Status message | `lib/models/screening_result.dart` | ~156-162 |
| Risk level display | `lib/models/screening_result.dart` | ~10-18 |

---

**Last Updated**: January 2026
**Status**: UNKNOWN filtering implemented, ready for multi-head model integration
