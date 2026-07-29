import 'dart:async';
import 'dart:io'
    if (dart.library.html) 'package:oral_cavity_classifier_app/io_stub.dart'
    as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import '../models/photo_capture.dart';
import '../models/screening_result.dart';
import 'screening_config.dart';

/// Top-level function for compute() - runs image preprocessing in a background
/// isolate to avoid blocking the main thread (keeps questionnaire responsive).
Float32List? _preprocessImageFromBytesIsolate(Uint8List raw) {
  try {
    const batch = 1;
    const channels = 3;
    const height = 224;
    const width = 224;
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;
    final resized = img.copyResize(decoded, width: width, height: height);
    final inputBuffer = Float32List(batch * channels * height * width);
    int idx = 0;
    const double meanR = 0.485, meanG = 0.456, meanB = 0.406;
    const double stdR = 0.229, stdG = 0.224, stdB = 0.225;
    for (int c = 0; c < channels; c++) {
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          final pixel = resized.getPixelSafe(w, h);
          final r = pixel.r.toDouble() / 255.0;
          final g = pixel.g.toDouble() / 255.0;
          final b = pixel.b.toDouble() / 255.0;
          double normalizedValue;
          if (c == 0)
            normalizedValue = (r - meanR) / stdR;
          else if (c == 1)
            normalizedValue = (g - meanG) / stdG;
          else
            normalizedValue = (b - meanB) / stdB;
          inputBuffer[idx++] = normalizedValue;
        }
      }
    }
    return inputBuffer;
  } catch (_) {
    return null;
  }
}

enum ModelType { ensemble, ensembleDual }

class ModelInfo {
  final String name;
  final double accuracy;
  final String size;
  final bool isLoaded;
  final String? error;

  ModelInfo({
    required this.name,
    required this.accuracy,
    required this.size,
    required this.isLoaded,
    this.error,
  });
}

class ModelInferenceService {
  static final ModelInferenceService _instance =
      ModelInferenceService._internal();
  factory ModelInferenceService() => _instance;
  ModelInferenceService._internal();

  // 5-class ensemble components
  final Map<String, dynamic> _ensembleSessions = {};
  final Map<String, bool> _ensembleLoaded = {};
  final Map<String, String?> _ensembleErrors = {};
  bool _ensembleReady = false;

  // Binary ensemble components (for dual-ensemble: referral decision)
  final Map<String, dynamic> _binaryEnsembleSessions = {};
  final Map<String, bool> _binaryEnsembleLoaded = {};
  final Map<String, String?> _binaryEnsembleErrors = {};
  bool _binaryEnsembleReady = false;

  // Current model type (default to ensemble / dual-ensemble when available)
  ModelType _currentModelType = ModelType.ensemble;

  // Labels
  List<String> _labels = [];
  final List<String> _classLabels = [
    'Benign',
    'Healthy',
    'OCA',
    'OPMD',
    'Unknown',
  ];

  // Ensemble configuration: 5-class only (keyed by 5-class asset names)
  final Map<String, double> _modelWeights = {
    'ensemble_model_1': 0.30,
    'ensemble_model_2': 0.40,
    'ensemble_model_3': 0.30,
  };

  /// 5-class model asset names (assets/ensemble_model_*.onnx)
  static const List<String> _fiveClassModelNames = [
    'ensemble_model_1',
    'ensemble_model_2',
    'ensemble_model_3',
  ];

  /// Binary model asset names (assets/binary_ensemble_mode_*.onnx) — distinct from 5-class to avoid loading wrong ONNX
  static const List<String> _binaryModelNames = [
    'binary_ensemble_mode_1',
    'binary_ensemble_mode_2',
    'binary_ensemble_mode_3',
  ];

  /// Weights for binary ensemble (same order as _binaryModelNames)
  static const Map<String, double> _binaryModelWeights = {
    'binary_ensemble_mode_1': 0.30,
    'binary_ensemble_mode_2': 0.40,
    'binary_ensemble_mode_3': 0.30,
  };

  final Map<String, double> _classWeights = {
    'OCA': 1.5, // Most critical - 50% higher weight
    'OPMD': 1.2, // High importance - 20% higher weight
    'Benign': 1.0, // Standard weight
    'Healthy': 1.0, // Standard weight
    'Unknown': 0.8, // Lower weight - 20% reduction
  };

  // Getters
  ModelType get currentModelType => _currentModelType;
  List<String> get labels => _labels.isNotEmpty ? _labels : _classLabels;

  // Model info (Debug UI: 5-class only and dual ensemble)
  ModelInfo get ensembleInfo => ModelInfo(
    name: '5-class Ensemble',
    accuracy: 76.36,
    size: '36.9 MB', // 3 × 12.3 MB
    isLoaded: _ensembleReady,
    error: _ensembleErrors.values.any((e) => e != null)
        ? 'Some models failed to load'
        : null,
  );

  ModelInfo get ensembleDualInfo => ModelInfo(
    name: 'Dual Ensemble (Binary + 5-class)',
    accuracy: 84.11,
    size: '36.9 MB', // 5-class + binary ensemble
    isLoaded: dualEnsembleReady,
    error:
        (_ensembleErrors.values.any((e) => e != null) ||
            _binaryEnsembleErrors.values.any((e) => e != null))
        ? 'Some models failed to load'
        : null,
  );

  /// Whether dual-ensemble (binary + 5-class) is available
  bool get dualEnsembleReady => _ensembleReady && _binaryEnsembleReady;

  /// Whether binary models only are loaded (used for lazy-load UX).
  bool get binaryEnsembleReady => _binaryEnsembleReady;

  /// Whether 5-class models are loaded (for showing "Loading detailed models" when false).
  bool get isFiveClassModelsLoaded => _ensembleReady;

  /// Set to false to skip loading binary ensemble (e.g. if it causes native crash on device).
  static const bool _loadBinaryEnsemble = true;

  /// Load only binary models (~36 MB). Used for fast startup (lazy loading).
  Future<void> loadBinaryModels() async {
    if (_binaryEnsembleReady) return;
    if (!_loadBinaryEnsemble) return;

    debugPrint('🔄 [BinaryEnsemble] Loading binary models (lazy)...');
    if (kIsWeb) {
      debugPrint(
        '🌐 [BinaryEnsemble] Web platform detected - using WebAssembly backend',
      );
      debugPrint(
        '   User Agent: ${kIsWeb ? (identical(0, 0.0) ? "Unknown" : "") : ""}',
      );
    }
    try {
      for (String modelName in _binaryModelNames) {
        try {
          // On web, Flutter builds assets to assets/assets/ path
          final assetPath = kIsWeb
              ? 'assets/assets/$modelName.onnx'
              : 'assets/$modelName.onnx';
          debugPrint('   Attempting to load: $assetPath');
          final ort = OnnxRuntime();
          if (kIsWeb) {
            debugPrint('   OnnxRuntime initialized on web');
            // Add a small delay on web to ensure WASM is ready (especially for mobile)
            await Future.delayed(const Duration(milliseconds: 100));
          }
          final session = await ort
              .createSessionFromAsset(assetPath)
              .timeout(
                const Duration(
                  seconds: 60,
                ), // Longer timeout for mobile browsers
                onTimeout: () {
                  debugPrint(
                    '⏱️ [BinaryEnsemble] Timeout loading $modelName (60s) - may be mobile browser WASM issue',
                  );
                  throw TimeoutException(
                    'Model loading timeout - mobile browser may have WASM loading issues',
                  );
                },
              );
          _binaryEnsembleSessions[modelName] = session;
          _binaryEnsembleLoaded[modelName] = true;
          _binaryEnsembleErrors[modelName] = null;
          debugPrint('✅ [BinaryEnsemble] Loaded $modelName');
        } catch (e, st) {
          _binaryEnsembleLoaded[modelName] = false;
          _binaryEnsembleErrors[modelName] = e.toString();
          debugPrint('❌ [BinaryEnsemble] Failed to load $modelName: $e');
          if (kIsWeb) {
            debugPrint('   Stack trace: $st');
            debugPrint(
              '   ⚠️ [Web] ONNX Runtime may not be properly initialized on web. Check if assets are accessible.',
            );
          }
        }
      }
    } catch (e, st) {
      debugPrint('❌ [BinaryEnsemble] Error during binary load: $e\n$st');
    }
    _binaryEnsembleReady = _binaryEnsembleSessions.isNotEmpty;
    debugPrint(
      '📊 [BinaryEnsemble] Loaded ${_binaryEnsembleSessions.length}/3 binary models',
    );
    if (kIsWeb && !_binaryEnsembleReady) {
      debugPrint('⚠️ [Web] Binary models failed to load. This may indicate:');
      debugPrint(
        '   1. flutter_onnxruntime version may not support web (upgrade to 1.6.2+)',
      );
      debugPrint('   2. Model assets may not be accessible on web');
      debugPrint('   3. WebAssembly files may be missing');
    }
  }

  /// Load only 5-class models (~36 MB). Used for lazy loading when screening starts.
  Future<void> loadFiveClassModels() async {
    if (_ensembleReady) return;

    debugPrint('🔄 [5ClassEnsemble] Loading 5-class models (lazy)...');
    if (kIsWeb) {
      debugPrint(
        '🌐 [5ClassEnsemble] Web platform detected - using WebAssembly backend',
      );
    }
    for (String modelName in _fiveClassModelNames) {
      try {
        // On web, Flutter builds assets to assets/assets/ path
        final assetPath = kIsWeb
            ? 'assets/assets/$modelName.onnx'
            : 'assets/$modelName.onnx';
        debugPrint('   Attempting to load: $assetPath');
        final ort = OnnxRuntime();
        if (kIsWeb) {
          debugPrint('   OnnxRuntime initialized on web');
          // Add a small delay on web to ensure WASM is ready (especially for mobile)
          await Future.delayed(const Duration(milliseconds: 100));
        }
        final session = await ort
            .createSessionFromAsset(assetPath)
            .timeout(
              const Duration(seconds: 60), // Longer timeout for mobile browsers
              onTimeout: () {
                debugPrint(
                  '⏱️ [5ClassEnsemble] Timeout loading $modelName (60s) - may be mobile browser WASM issue',
                );
                throw TimeoutException(
                  'Model loading timeout - mobile browser may have WASM loading issues',
                );
              },
            );
        _ensembleSessions[modelName] = session;
        _ensembleLoaded[modelName] = true;
        _ensembleErrors[modelName] = null;
        debugPrint('✅ [5ClassEnsemble] Loaded $modelName');
      } catch (e, st) {
        _ensembleLoaded[modelName] = false;
        _ensembleErrors[modelName] = e.toString();
        debugPrint('❌ [5ClassEnsemble] Failed to load $modelName: $e');
        if (kIsWeb) {
          debugPrint('   Stack trace: $st');
          debugPrint(
            '   ⚠️ [Web] ONNX Runtime may not be properly initialized on web.',
          );
        }
      }
    }
    _ensembleReady = _ensembleSessions.isNotEmpty;
    debugPrint(
      '📊 [5ClassEnsemble] Loaded ${_ensembleSessions.length}/3 5-class models',
    );
    if (_binaryEnsembleReady && _ensembleReady) {
      debugPrint('🎯 [DualEnsemble] Dual-ensemble ready (binary + 5-class)');
    }
    debugPrint(
      '🎯 [5ClassEnsemble] Class weights: OCA=${_classWeights['OCA']}, OPMD=${_classWeights['OPMD']}',
    );
    if (kIsWeb && !_ensembleReady) {
      debugPrint('⚠️ [Web] 5-class models failed to load. This may indicate:');
      debugPrint(
        '   1. flutter_onnxruntime version may not support web (upgrade to 1.6.2+)',
      );
      debugPrint('   2. Model assets may not be accessible on web');
      debugPrint('   3. WebAssembly files may be missing');
    }
  }

  /// Ensure 5-class models are loaded (lazy load on first inference).
  Future<void> ensureFiveClassModelsLoaded() async {
    if (_ensembleReady) return;
    await loadFiveClassModels();
  }

  /// Initialize ensemble: load binary at minimum; optionally load 5-class (set [loadFiveClass] false for lazy loading).
  Future<bool> initializeEnsemble({bool loadFiveClass = false}) async {
    await loadBinaryModels();

    if (loadFiveClass) {
      await loadFiveClassModels();
    } else {
      debugPrint('⏭️ [LazyLoad] 5-class models will load on first screening');
    }

    return _ensembleReady;
  }

  /// Load labels
  Future<void> loadLabels(String labelsData) async {
    _labels = labelsData
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    debugPrint('✅ [Labels] Loaded ${_labels.length} labels');
  }

  /// Set current model type
  void setModelType(ModelType modelType) {
    _currentModelType = modelType;
    debugPrint('🔄 [Model] Switched to ${modelType.name}');
  }

  /// Preprocess image for ONNX (ImageNet norm, NCHW). Session-independent; used by ensemble and binary.
  Future<Float32List?> _preprocessImageForONNX(io.File imageFile) async {
    try {
      const batch = 1;
      const channels = 3;
      const height = 224;
      const width = 224;

      final raw = await imageFile.readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) return null;

      final resized = img.copyResize(decoded, width: width, height: height);
      final inputBuffer = Float32List(batch * channels * height * width);
      int idx = 0;

      const double meanR = 0.485, meanG = 0.456, meanB = 0.406;
      const double stdR = 0.229, stdG = 0.224, stdB = 0.225;

      for (int c = 0; c < channels; c++) {
        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            final pixel = resized.getPixelSafe(w, h);
            final r = pixel.r.toDouble() / 255.0;
            final g = pixel.g.toDouble() / 255.0;
            final b = pixel.b.toDouble() / 255.0;
            double normalizedValue;
            if (c == 0)
              normalizedValue = (r - meanR) / stdR;
            else if (c == 1)
              normalizedValue = (g - meanG) / stdG;
            else
              normalizedValue = (b - meanB) / stdB;
            inputBuffer[idx++] = normalizedValue;
          }
        }
      }
      debugPrint(
        '✅ [Preprocess] Preprocessing complete, buffer size: ${inputBuffer.length}',
      );
      return inputBuffer;
    } catch (e, st) {
      debugPrint('❌ [Preprocess] ONNX preprocess error: $e\n$st');
      return null;
    }
  }

  /// Preprocess image bytes for ONNX (web-safe; no File). Runs in a background
  /// isolate on mobile/desktop to avoid blocking the main thread and keep the
  /// questionnaire responsive during parallel analysis.
  Future<Float32List?> _preprocessImageFromBytesAsync(Uint8List raw) async {
    debugPrint(
      '🖼️ [Preprocess] Starting bytes preprocessing (size: ${raw.length} bytes)',
    );
    Float32List? result;
    if (kIsWeb) {
      result = _preprocessImageFromBytesIsolate(raw);
    } else {
      result = await compute(_preprocessImageFromBytesIsolate, raw);
    }
    if (result != null) {
      debugPrint(
        '✅ [Preprocess] Bytes preprocessing complete, buffer size: ${result.length}',
      );
    } else {
      debugPrint('❌ [Preprocess] Failed to preprocess image from bytes');
    }
    return result;
  }

  /// On web, explicitly yield to the browser event loop between heavy WASM
  /// inference chunks so input/pointer events are not starved.
  Future<void> _yieldUiFrameIfWeb() async {
    if (!kIsWeb) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }

  /// Run Ensemble inference
  Future<Map<String, dynamic>?> infer5ClassEnsemble(io.File imageFile) async {
    await ensureFiveClassModelsLoaded();
    if (!_ensembleReady) {
      debugPrint('❌ [5ClassEnsemble] Ensemble not ready');
      return null;
    }

    try {
      // Get predictions from all loaded models
      final predictions = <Map<String, dynamic>>[];

      for (String modelName in _ensembleSessions.keys) {
        final prediction = await _predictSingleEnsembleModel(
          modelName,
          imageFile,
        );
        if (prediction != null) {
          predictions.add(prediction);
        }
      }

      if (predictions.isEmpty) {
        debugPrint('❌ [5ClassEnsemble] No valid predictions');
        return null;
      }

      debugPrint('🔍 [5ClassEnsemble] Got ${predictions.length} predictions');

      // Combine predictions using weighted average
      final combinedResult = _combineEnsemblePredictions(predictions);

      debugPrint(
        '🎯 [5ClassEnsemble] Final prediction: ${combinedResult['label']} (${(combinedResult['confidence'] * 100).toStringAsFixed(1)}%)',
      );

      return combinedResult;
    } catch (e, st) {
      debugPrint('❌ [5ClassEnsemble] Inference error: $e\n$st');
      return null;
    }
  }

  /// Get prediction from a single 5-class ensemble model (ensemble_model_1/2/3)
  Future<Map<String, dynamic>?> _predictSingleEnsembleModel(
    String modelName,
    io.File imageFile,
  ) async {
    if (!_ensembleLoaded[modelName]!) {
      debugPrint('❌ [5ClassEnsemble] Model $modelName not loaded');
      return null;
    }

    try {
      final inputData = await _preprocessImageForONNX(imageFile);
      if (inputData == null) return null;

      final session = _ensembleSessions[modelName];
      final inputTensor = await OrtValue.fromList(inputData, [1, 3, 224, 224]);

      final outputs = await session.run({'input': inputTensor});
      final outputTensor = outputs['output'];
      // 5-class ensemble must have exactly 5 outputs: Benign, Healthy, OCA, OPMD, Unknown
      final outputShape = outputTensor.shape;
      final numClasses = outputShape.isNotEmpty ? outputShape.last : 0;
      if (numClasses != 5) {
        debugPrint(
          '❌ [5ClassEnsemble] $modelName output shape=$outputShape (expected 5); skipping — use 5-class ONNX',
        );
        return null;
      }
      final rawOutput = await outputTensor.asList();
      // Handle nested list output
      List<dynamic> logitsList;
      if (rawOutput.isNotEmpty && rawOutput[0] is List) {
        logitsList = rawOutput[0] as List<dynamic>;
      } else {
        logitsList = rawOutput;
      }
      final logits = logitsList.map<double>((e) => e.toDouble()).toList();
      if (logits.length != 5) {
        debugPrint(
          '❌ [5ClassEnsemble] $modelName has ${logits.length} outputs (expected 5); skipping',
        );
        return null;
      }
      final probabilities = _softmax(logits);
      int maxIdx = 0;
      double maxVal = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxVal) {
          maxVal = probabilities[i];
          maxIdx = i;
        }
      }
      final predictedClass = _classLabels[maxIdx];

      final result = {
        'class': predictedClass,
        'confidence': maxVal,
        'probabilities': probabilities,
        'modelName': modelName,
      };

      debugPrint(
        '🔍 [5ClassEnsemble] Prediction for $modelName: $predictedClass (${(maxVal * 100).toStringAsFixed(1)}%)',
      );

      return result;
    } catch (e) {
      debugPrint('❌ [5ClassEnsemble] Prediction failed for $modelName: $e');
      return null;
    }
  }

  /// Run single 5-class model with preprocessed input (for web bytes path).
  Future<Map<String, dynamic>?> _predictSingleEnsembleModelWithInput(
    String modelName,
    Float32List inputData,
  ) async {
    if (!_ensembleLoaded[modelName]!) return null;
    try {
      final session = _ensembleSessions[modelName];
      final inputTensor = await OrtValue.fromList(inputData, [1, 3, 224, 224]);
      final outputs = await session.run({'input': inputTensor});
      final outputTensor = outputs['output'];
      final outputShape = outputTensor.shape;
      final numClasses = outputShape.isNotEmpty ? outputShape.last : 0;
      if (numClasses != 5) return null;
      final rawOutput = await outputTensor.asList();
      List<dynamic> logitsList = rawOutput.isNotEmpty && rawOutput[0] is List
          ? rawOutput[0] as List<dynamic>
          : rawOutput;
      final logits = logitsList.map<double>((e) => e.toDouble()).toList();
      if (logits.length != 5) return null;
      final probabilities = _softmax(logits);
      int maxIdx = 0;
      double maxVal = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxVal) {
          maxVal = probabilities[i];
          maxIdx = i;
        }
      }
      return {
        'class': _classLabels[maxIdx],
        'confidence': maxVal,
        'probabilities': probabilities,
        'modelName': modelName,
      };
    } catch (e) {
      debugPrint('❌ [5ClassEnsemble] WithInput failed for $modelName: $e');
      return null;
    }
  }

  /// 5-class ensemble from preprocessed input (no extra preprocessing).
  Future<Map<String, dynamic>?> _infer5ClassEnsembleWithInput(
    Float32List inputData,
  ) async {
    if (!_ensembleReady) return null;
    final predictions = <Map<String, dynamic>>[];
    for (String modelName in _ensembleSessions.keys) {
      await _yieldUiFrameIfWeb();
      final p = await _predictSingleEnsembleModelWithInput(
        modelName,
        inputData,
      );
      if (p != null) predictions.add(p);
    }
    if (predictions.isEmpty) return null;
    return _combineEnsemblePredictions(predictions);
  }

  /// 5-class ensemble from image bytes (web-safe).
  Future<Map<String, dynamic>?> infer5ClassEnsembleFromBytes(
    Uint8List imageBytes,
  ) async {
    await ensureFiveClassModelsLoaded();
    final inputData = await _preprocessImageFromBytesAsync(imageBytes);
    if (inputData == null) return null;
    return _infer5ClassEnsembleWithInput(inputData);
  }

  /// Binary ensemble with preprocessed input (for web bytes path).
  Future<Map<String, dynamic>?> _inferBinaryEnsembleWithInput(
    Float32List inputData,
  ) async {
    if (!_binaryEnsembleReady) return null;
    try {
      double sumCancerProb = 0.0;
      double sumWeight = 0.0;
      for (String modelName in _binaryModelNames) {
        await _yieldUiFrameIfWeb();
        if (_binaryEnsembleLoaded[modelName] != true) continue;
        final session = _binaryEnsembleSessions[modelName];
        final inputTensor = await OrtValue.fromList(inputData, [
          1,
          3,
          224,
          224,
        ]);
        final outputs = await session.run({'input': inputTensor});
        final outputTensor = outputs['output'];
        final outputShape = outputTensor.shape;
        if (outputShape.isEmpty || outputShape.last != 2) continue;
        final rawOutput = await outputTensor.asList();
        List<dynamic> logitsList = rawOutput.isNotEmpty && rawOutput[0] is List
            ? rawOutput[0] as List<dynamic>
            : rawOutput;
        final logits = logitsList.map<double>((e) => e.toDouble()).toList();
        if (logits.length != 2) continue;
        final probs = _softmax(logits);
        final weight = _binaryModelWeights[modelName] ?? 1.0 / 3;
        sumCancerProb += probs[1] * weight;
        sumWeight += weight;
      }
      if (sumWeight <= 0) return null;
      final cancerProbability = sumCancerProb / sumWeight;
      return {
        'isCancer':
            cancerProbability >= ScreeningConfig.binaryScreeningThreshold,
        'cancerProbability': cancerProbability,
      };
    } catch (e) {
      debugPrint('❌ [BinaryEnsemble] WithInput error: $e');
      return null;
    }
  }

  /// V2 dual-ensemble from image bytes (web-safe).
  /// Binary model = screening authority. 5-class = informational subtype only.
  Future<Map<String, dynamic>?> inferDualEnsembleFromBytes(
    Uint8List imageBytes, {
    double qualityScore = 1.0,
  }) async {
    debugPrint('🔬 [DualEnsemble] Starting V2 inference from bytes');
    await ensureFiveClassModelsLoaded();
    if (!dualEnsembleReady) {
      debugPrint('❌ [DualEnsemble] Dual ensemble not ready');
      return null;
    }
    final inputData = await _preprocessImageFromBytesAsync(imageBytes);
    if (inputData == null) {
      debugPrint('❌ [DualEnsemble] Preprocessing failed');
      return null;
    }
    await _yieldUiFrameIfWeb();
    final binaryResult = await _inferBinaryEnsembleWithInput(inputData);
    await _yieldUiFrameIfWeb();
    final fiveClassResult = await _infer5ClassEnsembleWithInput(inputData);
    if (binaryResult == null || fiveClassResult == null) {
      debugPrint(
        '❌ [DualEnsemble] Inference failed: binary=${binaryResult != null}, 5-class=${fiveClassResult != null}',
      );
      return null;
    }
    return _buildV2Result(binaryResult, fiveClassResult, qualityScore);
  }

  /// Unified inference from image bytes (web-safe). Use when File is not available (e.g. Flutter web).
  Future<Map<String, dynamic>?> inferFromBytes(Uint8List imageBytes) async {
    switch (_currentModelType) {
      case ModelType.ensemble:
        return await infer5ClassEnsembleFromBytes(imageBytes);
      case ModelType.ensembleDual:
        final result = await inferDualEnsembleFromBytes(imageBytes);
        if (result == null) return null;
        return {
          ...result,
          'label': result['displayLabel'] as String? ?? result['displayLabel'],
          'confidence': result['confidence'],
        };
      default:
        // Fallback so Quick Check always gets a result (e.g. after lazy load)
        if (dualEnsembleReady) {
          final result = await inferDualEnsembleFromBytes(imageBytes);
          if (result == null) return null;
          return {
            ...result,
            'label':
                result['displayLabel'] as String? ?? result['displayLabel'],
            'confidence': result['confidence'],
          };
        }
        return await infer5ClassEnsembleFromBytes(imageBytes);
    }
  }

  /// Combine ensemble predictions with class weights
  Map<String, dynamic> _combineEnsemblePredictions(
    List<Map<String, dynamic>> predictions,
  ) {
    final allProbabilities = <String, double>{};

    // Initialize probability sums
    for (String className in _classLabels) {
      allProbabilities[className] = 0.0;
    }

    // Combine using weighted average
    for (Map<String, dynamic> pred in predictions) {
      final modelName = pred['modelName'] as String;
      final weight = _modelWeights[modelName] ?? 1.0;
      final probs = pred['probabilities'] as List<double>;

      for (int i = 0; i < _classLabels.length; i++) {
        allProbabilities[_classLabels[i]] =
            allProbabilities[_classLabels[i]]! + (probs[i] * weight);
      }
    }

    // Apply class weights for medical importance
    for (String className in _classLabels) {
      final classWeight = _classWeights[className] ?? 1.0;
      allProbabilities[className] = allProbabilities[className]! * classWeight;
    }

    // Find final prediction
    String predictedClass = 'Unknown';
    double maxProb = 0.0;
    for (String className in _classLabels) {
      if (allProbabilities[className]! > maxProb) {
        maxProb = allProbabilities[className]!;
        predictedClass = className;
      }
    }

    // Normalize probabilities
    final totalProb = allProbabilities.values.reduce((a, b) => a + b);
    final normalizedProbs = <String, double>{};
    for (String className in _classLabels) {
      normalizedProbs[className] = allProbabilities[className]! / totalProb;
    }

    final confidence = maxProb / totalProb;

    // Generate reasoning
    final individualPredictions = predictions
        .map((p) => p['class'] as String)
        .toList();
    final agreementCount = individualPredictions
        .where((p) => p == predictedClass)
        .length;
    final reasoning =
        'Ensemble: $agreementCount/${predictions.length} models agree, OCA weight=${_classWeights['OCA']}';

    return {
      'label': predictedClass,
      'confidence': confidence, // Already a percentage (0-1 range)
      'probabilities': normalizedProbs,
      'reasoning': reasoning,
      'individualPredictions': individualPredictions,
    };
  }

  /// Run binary ensemble inference (2 classes: non-cancer, cancer). Returns cancer probability.
  Future<Map<String, dynamic>?> _inferBinaryEnsemble(io.File imageFile) async {
    if (!_binaryEnsembleReady) return null;
    try {
      final inputData = await _preprocessImageForONNX(imageFile);
      if (inputData == null) return null;

      double sumCancerProb = 0.0;
      double sumWeight = 0.0;

      for (String modelName in _binaryModelNames) {
        if (_binaryEnsembleLoaded[modelName] != true) {
          debugPrint(
            '⚠️ [BinaryEnsemble] Model $modelName not loaded, skipping',
          );
          continue;
        }
        final session = _binaryEnsembleSessions[modelName];
        final inputTensor = await OrtValue.fromList(inputData, [
          1,
          3,
          224,
          224,
        ]);
        final outputs = await session.run({'input': inputTensor});
        final outputTensor = outputs['output'];
        // Confirm binary model: output shape should be [batch, 2] (expected classes: non-cancer, cancer)
        final outputShape = outputTensor.shape;
        final numClasses = outputShape.isNotEmpty ? outputShape.last : 0;
        if (numClasses != 2) {
          debugPrint(
            '❌ [BinaryEnsemble] $modelName output shape=$outputShape (expected last dim 2); '
            'skipping — use binary ONNX with num_classes=2',
          );
          continue;
        }
        debugPrint(
          '✅ [BinaryEnsemble] $modelName output shape=$outputShape (expected classes: non-cancer, cancer)',
        );
        final rawOutput = await outputTensor.asList();
        List<dynamic> logitsList;
        if (rawOutput.isNotEmpty && rawOutput[0] is List) {
          logitsList = rawOutput[0] as List<dynamic>;
        } else {
          logitsList = rawOutput;
        }
        final logits = logitsList.map<double>((e) => e.toDouble()).toList();
        if (logits.length != 2) {
          debugPrint(
            '❌ [BinaryEnsemble] $modelName has ${logits.length} outputs (expected 2); skipping — re-export ONNX with num_classes=2',
          );
          continue;
        }
        final probs = _softmax(logits);
        final cancerProb = probs[1]; // index 1 = cancer (refer)
        final weight = _binaryModelWeights[modelName] ?? 1.0 / 3;
        debugPrint(
          '🔍 [BinaryEnsemble] $modelName: P(no-refer)=${((probs[0]) * 100).toStringAsFixed(1)}%, '
          'P(refer)=${(cancerProb * 100).toStringAsFixed(1)}% (w=${weight.toStringAsFixed(2)})',
        );
        sumCancerProb += cancerProb * weight;
        sumWeight += weight;
      }
      if (sumWeight <= 0) return null;
      final cancerProbability = sumCancerProb / sumWeight;
      final isCancer =
          cancerProbability >= ScreeningConfig.binaryScreeningThreshold;
      debugPrint(
        '🎯 [BinaryEnsemble] Combined: Screening risk score=${(cancerProbability * 100).toStringAsFixed(1)}% '
        '→ ${isCancer ? "REFER" : "Low risk"} (threshold=${ScreeningConfig.binaryScreeningThreshold.toStringAsFixed(4)})',
      );
      return {'isCancer': isCancer, 'cancerProbability': cancerProbability};
    } catch (e) {
      debugPrint('❌ [BinaryEnsemble] Inference error: $e');
      return null;
    }
  }

  /// V2 dual-ensemble from file.
  /// Binary model = screening authority. 5-class = informational subtype only.
  Future<Map<String, dynamic>?> inferDualEnsemble(
    io.File imageFile, {
    double qualityScore = 1.0,
    bool isValidOralPhoto = true,
  }) async {
    await ensureFiveClassModelsLoaded();
    if (!dualEnsembleReady) return null;
    debugPrint('📊 [DualEnsemble] === Starting V2 dual-ensemble inference ===');

    final binaryResult = await _inferBinaryEnsemble(imageFile);
    final fiveClassResult = await infer5ClassEnsemble(imageFile);
    if (binaryResult == null || fiveClassResult == null) {
      debugPrint(
        '❌ [DualEnsemble] Missing result: binary=${binaryResult != null}, 5-class=${fiveClassResult != null}',
      );
      return null;
    }
    return _buildV2Result(binaryResult, fiveClassResult, qualityScore);
  }

  /// Shared V2 result builder for both file-based and bytes-based dual-ensemble.
  Map<String, dynamic> _buildV2Result(
    Map<String, dynamic> binaryResult,
    Map<String, dynamic> fiveClassResult,
    double qualityScore,
  ) {
    final cancerProb = binaryResult['cancerProbability'] as double;
    final fiveClassLabel = fiveClassResult['label'] as String;
    final fiveClassProbs =
        fiveClassResult['probabilities'] as Map<String, double>?;
    double confidence = (fiveClassResult['confidence'] as num).toDouble();
    if (confidence > 1.0) confidence = confidence / 100.0;

    final double pUnknown = fiveClassProbs?['Unknown'] ?? 0.0;
    final bool oodUnclear =
        fiveClassLabel == 'Unknown' &&
        pUnknown > ScreeningConfig.oodUnknownThreshold;
    final bool lowQuality =
        qualityScore < ScreeningConfig.qualityUnclearThreshold;

    RiskLevel? riskLevel;
    if (oodUnclear) {
      riskLevel = null;
    } else {
      final isPositive = cancerProb >= ScreeningConfig.binaryScreeningThreshold;
      if (isPositive) {
        riskLevel = cancerProb >= ScreeningConfig.highConfSingleViewThreshold
            ? RiskLevel.high
            : RiskLevel.moderate;
      } else {
        riskLevel = RiskLevel.low;
      }
    }

    double maxProb = 0.0;
    String displayLabel = fiveClassLabel;
    if (fiveClassProbs != null) {
      maxProb = fiveClassProbs.values.fold(0.0, (max, v) => v > max ? v : max);
      if (maxProb < ScreeningConfig.labelConfidenceThreshold)
        displayLabel = 'Uncertain';
    }

    // Per-photo display: resolve binary vs 5-class ambiguity for UI only.
    // When binary says positive but 5-class says Healthy/Benign, flag as disagreement.
    final bool isPositive =
        cancerProb >= ScreeningConfig.binaryScreeningThreshold;
    final bool fiveClassNonConcerning =
        displayLabel == 'Healthy' || displayLabel == 'Benign';
    String? perPhotoSummaryLabel;
    if (isPositive && fiveClassNonConcerning) {
      perPhotoSummaryLabel = 'Retake or further analysis needed';
    } else if (!isPositive && displayLabel == 'Healthy') {
      perPhotoSummaryLabel = 'Healthy';
    }

    List<double>? probabilitiesList;
    if (fiveClassProbs != null) {
      probabilitiesList = [
        fiveClassProbs['Benign'] ?? 0.0,
        fiveClassProbs['Healthy'] ?? 0.0,
        fiveClassProbs['OCA'] ?? 0.0,
        fiveClassProbs['OPMD'] ?? 0.0,
        fiveClassProbs['Unknown'] ?? 0.0,
      ];
    }

    debugPrint(
      '📊 [DualEnsemble] V2 result: P(abnormal)=${(cancerProb * 100).toStringAsFixed(1)}%, '
      'label=$displayLabel, risk=${riskLevel?.displayName ?? "unassessable"}',
    );

    return {
      'displayLabel': displayLabel,
      'riskLevel': riskLevel,
      'confidence': confidence > 1.0 ? confidence / 100.0 : confidence,
      'probabilities': fiveClassProbs,
      'probabilitiesList': probabilitiesList,
      'classProbs': probabilitiesList != null
          ? ClassProbabilities.fromList(probabilitiesList)
          : null,
      'cancerProbability': cancerProb,
      'oodUnclear': oodUnclear,
      'lowQuality': lowQuality,
      'perPhotoSummaryLabel': perPhotoSummaryLabel,
    };
  }

  /// Unified inference method (5-class or dual ensemble).
  /// Used for: single-photo / debug flows (e.g. main.dart pick-and-infer), and by
  /// [inferWithProbabilities]. Multi-photo screening uses [analyzePhoto] -> [inferDualEnsemble] when dual ready.
  Future<Map<String, dynamic>?> infer(io.File imageFile) async {
    switch (_currentModelType) {
      case ModelType.ensemble:
        return await infer5ClassEnsemble(imageFile);
      case ModelType.ensembleDual:
        final result = await inferDualEnsemble(imageFile);
        if (result == null) return null;
        // Debug UI expects 'label' and 'confidence'; dual returns displayLabel
        return {
          ...result,
          'label': result['displayLabel'] as String? ?? result['displayLabel'],
          'confidence': result['confidence'],
        };
    }
  }

  /// Softmax helper
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExps = exps.reduce((a, b) => a + b);
    return exps.map<double>((x) => x / sumExps).toList();
  }

  // ============================================================
  // MULTI-PHOTO INFERENCE METHODS
  // ============================================================

  // ============================================================
  // V2 SCREENING POLICY (all thresholds from ScreeningConfig)
  // ============================================================

  /// Derive [SubtypeGuidance] from aggregated 5-class probabilities.
  SubtypeGuidance deriveSubtypeGuidance(ClassProbabilities probs) {
    final maxSub = math.max(probs.oca, math.max(probs.opmd, probs.benign));
    if (maxSub < ScreeningConfig.subtypeConfidenceThreshold) {
      return SubtypeGuidance.none;
    }
    if (probs.oca >= probs.opmd && probs.oca >= probs.benign) {
      return SubtypeGuidance.ocaDominant;
    }
    if (probs.opmd >= probs.oca && probs.opmd >= probs.benign) {
      return SubtypeGuidance.opmdDominant;
    }
    return SubtypeGuidance.benignDominant;
  }

  /// Build V2 assessment title and message from [ScreeningOutcome] and [SubtypeGuidance].
  ({String title, String message}) buildV2AssessmentMessage({
    required ScreeningOutcome outcome,
    required SubtypeGuidance guidance,
    required int photosUsed,
    required int photosCaptured,
    double? borderlineOpmdPlus,
  }) {
    switch (outcome) {
      case ScreeningOutcome.lowRisk:
        final note =
            (borderlineOpmdPlus != null &&
                borderlineOpmdPlus >
                    ScreeningConfig.borderlineMultiClassThreshold)
            ? ' Some minor irregular patterns detected. Retake clearer photos if concerned.'
            : '';
        return (
          title: 'Low Risk',
          message: 'No concerning signs detected in these photos.$note',
        );
      case ScreeningOutcome.retakeSuggested:
        return (
          title: 'Retake Suggested',
          message:
              'The result is near the decision boundary or image quality was '
              'insufficient. Please retake with better lighting, ensuring full '
              'visibility of all required views.',
        );
      case ScreeningOutcome.reviewRecommended:
        return (
          title: guidance.displayTitle.isNotEmpty
              ? guidance.displayTitle
              : 'Review Recommended',
          message: guidance.displayMessage.isNotEmpty
              ? guidance.displayMessage
              : 'Changes detected that may need professional review. '
                    'Please consult a healthcare provider.',
        );
    }
  }

  /// Map [ScreeningOutcome] + [SubtypeGuidance] to legacy [RiskLevel].
  RiskLevel outcomeToRiskLevel(
    ScreeningOutcome outcome,
    SubtypeGuidance guidance,
  ) {
    switch (outcome) {
      case ScreeningOutcome.lowRisk:
        return RiskLevel.low;
      case ScreeningOutcome.retakeSuggested:
        return RiskLevel.moderate;
      case ScreeningOutcome.reviewRecommended:
        if (guidance == SubtypeGuidance.ocaDominant) return RiskLevel.high;
        return RiskLevel.moderate;
    }
  }

  /// Map [ScreeningOutcome] + [SubtypeGuidance] to [UrgencyLevel].
  UrgencyLevel outcomeToUrgency(
    ScreeningOutcome outcome,
    SubtypeGuidance guidance,
  ) {
    switch (outcome) {
      case ScreeningOutcome.lowRisk:
        return UrgencyLevel.routine;
      case ScreeningOutcome.retakeSuggested:
        return UrgencyLevel.retake;
      case ScreeningOutcome.reviewRecommended:
        if (guidance == SubtypeGuidance.ocaDominant) return UrgencyLevel.urgent;
        return UrgencyLevel.prompt;
    }
  }

  /// Inference with detailed probabilities (for multi-photo aggregation)
  Future<Map<String, dynamic>?> inferWithProbabilities(
    io.File imageFile,
  ) async {
    try {
      final result = await infer(imageFile);
      if (result == null) return null;

      // For ensemble and ensembleDual, probabilities are already included
      if ((_currentModelType == ModelType.ensemble ||
              _currentModelType == ModelType.ensembleDual) &&
          result.containsKey('probabilities')) {
        return result;
      }

      return result;
    } catch (e) {
      debugPrint('❌ [MultiPhoto] Error in inferWithProbabilities: $e');
      return null;
    }
  }

  /// Analyze a single photo and return PhotoResult
  Future<PhotoResult> analyzePhoto(PhotoCapture photo) async {
    debugPrint(
      '🔍 [analyzePhoto] Starting analysis for ${photo.type.displayName}',
    );
    debugPrint(
      '   Quality: ${(photo.qualityMetrics.overall * 100).toStringAsFixed(1)}% (acceptable: ${photo.qualityMetrics.isAcceptable})',
    );
    debugPrint(
      '   Has image: ${photo.image != null}, Has bytes: ${photo.imageBytes != null}',
    );

    final hasImageData = photo.image != null || photo.imageBytes != null;
    if (!hasImageData) {
      debugPrint(
        '❌ [analyzePhoto] No image data for ${photo.type.displayName}',
      );
      return PhotoResult(
        photoType: photo.type,
        classProbabilities: null,
        confidence: 0.0,
        qualityScore: photo.qualityMetrics.overall,
        riskLevel: null,
        isValidOralPhoto: false,
      );
    }

    try {
      Map<String, dynamic>? result;
      final useBytes = photo.imageBytes != null;
      debugPrint(
        '   Using bytes path: $useBytes, Dual ensemble ready: $dualEnsembleReady',
      );

      if ((_currentModelType == ModelType.ensemble ||
              _currentModelType == ModelType.ensembleDual) &&
          dualEnsembleReady) {
        debugPrint(
          '🔍 [DualEnsemble] Using binary + 5-class for ${photo.type.displayName}',
        );
        if (useBytes) {
          result = await inferDualEnsembleFromBytes(
            photo.imageBytes!,
            qualityScore: photo.qualityMetrics.overall,
          );
        } else {
          result = await inferDualEnsemble(
            photo.image!,
            qualityScore: photo.qualityMetrics.overall,
            isValidOralPhoto: true,
          );
        }
      } else {
        if (useBytes) {
          result = await infer5ClassEnsembleFromBytes(photo.imageBytes!);
        } else {
          result = await inferWithProbabilities(photo.image!);
        }
      }

      if (result == null) {
        debugPrint(
          '❌ [analyzePhoto] Inference returned null for ${photo.type.displayName}',
        );
        return PhotoResult(
          photoType: photo.type,
          classProbabilities: null,
          confidence: 0.0,
          qualityScore: photo.qualityMetrics.overall,
          riskLevel: null,
          isValidOralPhoto: true,
        );
      }

      debugPrint(
        '✅ [analyzePhoto] Got inference result for ${photo.type.displayName}',
      );

      // Extract probabilities (dual-ensemble may already have classProbs)
      ClassProbabilities? classProbs =
          result['classProbs'] as ClassProbabilities?;
      if (classProbs == null) {
        if (result.containsKey('probabilitiesList')) {
          classProbs = ClassProbabilities.fromList(
            result['probabilitiesList'] as List<double>,
          );
        } else if (result.containsKey('probabilities')) {
          final probMap = result['probabilities'] as Map<String, double>;
          classProbs = ClassProbabilities(
            healthy: probMap['Healthy'] ?? 0.0,
            benign: probMap['Benign'] ?? 0.0,
            opmd: probMap['OPMD'] ?? 0.0,
            oca: probMap['OCA'] ?? 0.0,
            unknown: probMap['Unknown'] ?? 0.0,
          );
        }
      }

      RiskLevel? riskLevel = result['riskLevel'] as RiskLevel?;
      if (riskLevel == null && classProbs != null) {
        final pCancer =
            (result['cancerProbability'] as num?)?.toDouble() ?? 0.0;
        if (pCancer >= ScreeningConfig.binaryScreeningThreshold) {
          riskLevel = pCancer >= ScreeningConfig.highConfSingleViewThreshold
              ? RiskLevel.high
              : RiskLevel.moderate;
        } else {
          riskLevel = RiskLevel.low;
        }
      }

      double confidence = 0.0;
      if (result.containsKey('confidence')) {
        final conf = result['confidence'];
        confidence = conf is double ? conf : (conf as num).toDouble();
        if (confidence > 1.0) confidence /= 100.0;
      }

      bool isValidOralPhoto = true;
      if (classProbs != null) {
        final isUnknownPredicted = classProbs.predictedClass == 'Unknown';
        final unknownProb = classProbs.unknown;
        debugPrint(
          '🔍 [MultiPhoto] ${photo.type.displayName}: predicted=${classProbs.predictedClass}, UNKNOWN=${(unknownProb * 100).toStringAsFixed(1)}%',
        );
        if (isUnknownPredicted &&
            unknownProb > ScreeningConfig.oodUnknownThreshold) {
          isValidOralPhoto = false;
          debugPrint(
            '❌ [MultiPhoto] Photo ${photo.type.displayName} marked as NON-ORAL',
          );
        }
      }

      final String? displayLabel = result['displayLabel'] as String?;
      final double? cancerProbability = (result['cancerProbability'] as num?)
          ?.toDouble();
      final String? perPhotoSummaryLabel =
          result['perPhotoSummaryLabel'] as String?;

      return PhotoResult(
        photoType: photo.type,
        classProbabilities: classProbs,
        confidence: confidence,
        qualityScore: photo.qualityMetrics.overall,
        riskLevel: riskLevel,
        isValidOralPhoto: isValidOralPhoto,
        displayLabel: displayLabel,
        cancerProbability: cancerProbability,
        perPhotoSummaryLabel: perPhotoSummaryLabel,
      );
    } catch (e) {
      debugPrint(
        '❌ [MultiPhoto] Error analyzing photo ${photo.type.displayName}: $e',
      );
      return PhotoResult(
        photoType: photo.type,
        classProbabilities: null,
        confidence: 0.0,
        qualityScore: photo.qualityMetrics.overall,
        riskLevel: null,
        isValidOralPhoto: true,
      );
    }
  }

  /// Perform multi-photo inference on a screening session.
  /// [onPhotoProgress] is called with the current captured-photo index (0-based); call with 0 before first, then 1, 2, ... after each photo so UI can show P1..P5 progress.
  Future<ScreeningResult> inferMultiPhoto(
    List<PhotoCapture> photos, {
    void Function(int photoIndex)? onPhotoProgress,
  }) async {
    debugPrint(
      '🔄 [MultiPhoto] Starting multi-photo inference on ${photos.length} photos',
    );

    final photoResults = <PhotoResult>[];
    int capturedIndex = 0;

    for (final photo in photos) {
      if (!photo.isCaptured) continue;

      await _yieldUiFrameIfWeb();
      onPhotoProgress?.call(capturedIndex);
      final result = await analyzePhoto(photo);
      await _yieldUiFrameIfWeb();
      capturedIndex++;
      onPhotoProgress?.call(capturedIndex);
      photoResults.add(result);
    }

    return aggregateResults(photoResults, photosCaptured: capturedIndex);
  }

  /// V2 pure-logic aggregation with hybrid patient-level binary aggregation.
  ///
  /// Binary model is the sole screening authority.
  /// Multi-class model is informational (subtype guidance) only.
  ScreeningResult aggregateResults(
    List<PhotoResult> photoResults, {
    int? photosCaptured,
  }) {
    final capturedCount = photosCaptured ?? photoResults.length;
    final validPredictions = <List<double>>[];
    final validWeights = <double>[];
    final usableCandidates = <Map<String, dynamic>>[];
    int skippedDueToUnknown = 0;
    int skippedDueToQuality = 0;

    for (final result in photoResults) {
      if (!result.isValidOralPhoto) {
        skippedDueToUnknown++;
        continue;
      }

      if (!result.isAnalyzed || result.classProbabilities == null) {
        skippedDueToQuality++;
        continue;
      }

      final probs = [
        result.classProbabilities!.benign,
        result.classProbabilities!.healthy,
        result.classProbabilities!.oca,
        result.classProbabilities!.opmd,
        result.classProbabilities!.unknown,
      ];

      final pC = result.cancerProbability ?? 0.5;
      final confB = (pC - 0.5).abs() * 2.0;
      final conf5 = result.classProbabilities!.confidence;
      final weight = result.qualityScore * (0.6 * confB + 0.4 * conf5);
      validPredictions.add(probs);
      validWeights.add(weight);

      final bool usable = result.qualityScore >= ScreeningConfig.qualityMin;
      if (usable) {
        usableCandidates.add({
          'photoResult': result,
          'probs': probs,
          'weight': weight,
        });
      } else {
        skippedDueToQuality++;
      }
    }

    // No usable photos → retake
    if (usableCandidates.isEmpty) {
      return _buildRetakeResult(
        photoResults,
        capturedCount: capturedCount,
        photosUsed: 0,
        skippedDueToUnknown: skippedDueToUnknown,
        skippedDueToQuality: skippedDueToQuality,
      );
    }

    final photosUsed = usableCandidates.length;

    // ------------------------------------------------------------------
    // Hybrid Patient-Level Binary Aggregation
    // Uses ALL usable photos (not top-K) so no clinically relevant photo
    // is excluded by the confidence-based weight formula.
    // ------------------------------------------------------------------
    final binaryScores =
        usableCandidates
            .map(
              (c) => (c['photoResult'] as PhotoResult).cancerProbability ?? 0.0,
            )
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final double maxScore = binaryScores.isNotEmpty ? binaryScores.first : 0.0;
    final double secondScore = binaryScores.length > 1 ? binaryScores[1] : 0.0;
    final double hybridAvg = (maxScore + secondScore) / 2.0;

    bool screenPositive;
    if (maxScore >= ScreeningConfig.highConfSingleViewThreshold) {
      screenPositive = true;
    } else if (hybridAvg >= ScreeningConfig.binaryScreeningThreshold) {
      screenPositive = true;
    } else {
      screenPositive = false;
    }

    debugPrint(
      '📊 [Aggregation] V2 hybrid: maxScore=${maxScore.toStringAsFixed(4)}, '
      'secondScore=${secondScore.toStringAsFixed(4)}, hybridAvg=${hybridAvg.toStringAsFixed(4)}, '
      'screenPositive=$screenPositive',
    );

    // ------------------------------------------------------------------
    // Determine ScreeningOutcome
    // ------------------------------------------------------------------
    ScreeningOutcome outcome;
    if (screenPositive) {
      outcome = ScreeningOutcome.reviewRecommended;
    } else {
      final effectiveScore = hybridAvg;
      final hasLowQualityPhotos = photoResults.any(
        (r) =>
            r.isValidOralPhoto &&
            r.isAnalyzed &&
            r.qualityScore < ScreeningConfig.qualityUnclearThreshold,
      );
      if ((effectiveScore >= ScreeningConfig.retakeLowerBound &&
              effectiveScore < ScreeningConfig.retakeUpperBound) ||
          (photosUsed < ScreeningConfig.minUsedPhotos &&
              capturedCount >= ScreeningConfig.minUsedPhotos) ||
          hasLowQualityPhotos) {
        outcome = ScreeningOutcome.retakeSuggested;
      } else {
        outcome = ScreeningOutcome.lowRisk;
      }
    }

    // ------------------------------------------------------------------
    // 5-class aggregation: two separate aggregates
    //   - positiveClassProbs: only from photos where binary >= threshold
    //     (used for subtype guidance when screen-positive)
    //   - allClassProbs: all usable photos (used for borderline note,
    //     label confidence when screen-negative)
    // ------------------------------------------------------------------
    final positivePhotos = usableCandidates.where((c) {
      final pC = (c['photoResult'] as PhotoResult).cancerProbability ?? 0.0;
      return pC >= ScreeningConfig.binaryScreeningThreshold;
    }).toList();

    final ClassProbabilities positiveClassProbs;
    if (positivePhotos.isNotEmpty) {
      final posPreds = positivePhotos
          .map((c) => c['probs'] as List<double>)
          .toList();
      final posWeights = positivePhotos
          .map((c) => c['weight'] as double)
          .toList();
      positiveClassProbs = ClassProbabilities.fromList(
        _aggregatePredictions(posPreds, posWeights),
      );
    } else {
      positiveClassProbs = const ClassProbabilities(
        healthy: 0,
        benign: 0,
        opmd: 0,
        oca: 0,
      );
    }

    final allPreds = usableCandidates
        .map((c) => c['probs'] as List<double>)
        .toList();
    final allWeights = usableCandidates
        .map((c) => c['weight'] as double)
        .toList();
    final allClassProbs = ClassProbabilities.fromList(
      _aggregatePredictions(allPreds, allWeights),
    );

    // When screen-positive, subtype and label confidence come from positive photos only
    final ClassProbabilities effectiveClassProbs =
        screenPositive && positivePhotos.isNotEmpty
        ? positiveClassProbs
        : allClassProbs;

    // ------------------------------------------------------------------
    // Subtype guidance (informational, only meaningful when screen-positive)
    // ------------------------------------------------------------------
    var subtypeGuidance = screenPositive
        ? deriveSubtypeGuidance(effectiveClassProbs)
        : SubtypeGuidance.none;

    // Suppress benignDominant when the aggregated label is non-concerning
    // (Healthy/Benign) -- showing "Lesion Detected" with "Benign" is confusing.
    if (subtypeGuidance == SubtypeGuidance.benignDominant) {
      final dominant = effectiveClassProbs.predictedClass;
      if (dominant == 'Healthy' || dominant == 'Benign') {
        subtypeGuidance = SubtypeGuidance.none;
      }
    }

    // Map to legacy RiskLevel / UrgencyLevel
    final overallRisk = outcomeToRiskLevel(outcome, subtypeGuidance);
    final urgencyLevel = outcomeToUrgency(outcome, subtypeGuidance);

    // Build assessment message
    final double pOpmdPlus = allClassProbs.opmd + allClassProbs.oca;
    final assessment = buildV2AssessmentMessage(
      outcome: outcome,
      guidance: subtypeGuidance,
      photosUsed: photosUsed,
      photosCaptured: capturedCount,
      borderlineOpmdPlus: !screenPositive ? pOpmdPlus : null,
    );

    final recommendations = ScreeningResult.generateRecommendations(
      overallRisk,
      photoResults,
    );

    return ScreeningResult(
      overallRisk: overallRisk,
      overallConfidence: effectiveClassProbs.confidence,
      photoResults: photoResults,
      recommendations: recommendations,
      specialistRequired:
          urgencyLevel == UrgencyLevel.prompt ||
          urgencyLevel == UrgencyLevel.urgent ||
          overallRisk.specialistRequired,
      urgencyLevel: urgencyLevel,
      urgencyText: urgencyLevel.displayText,
      aggregatedProbabilities: effectiveClassProbs,
      analyzedAt: DateTime.now(),
      overallAssessmentTitle: assessment.title,
      overallAssessmentMessage: assessment.message,
      labelConfidence: effectiveClassProbs.confidence,
      screeningOutcome: outcome,
      subtypeGuidance: subtypeGuidance,
      photosCaptured: capturedCount,
      photosUsed: photosUsed,
      skippedDueToUnknown: skippedDueToUnknown,
      skippedDueToQuality: skippedDueToQuality,
    );
  }

  /// Helper for the "no usable photos" edge case.
  ScreeningResult _buildRetakeResult(
    List<PhotoResult> photoResults, {
    required int capturedCount,
    required int photosUsed,
    required int skippedDueToUnknown,
    required int skippedDueToQuality,
  }) {
    const outcome = ScreeningOutcome.retakeSuggested;
    const guidance = SubtypeGuidance.none;
    final assessment = buildV2AssessmentMessage(
      outcome: outcome,
      guidance: guidance,
      photosUsed: photosUsed,
      photosCaptured: capturedCount,
    );
    return ScreeningResult(
      overallRisk: RiskLevel.moderate,
      overallConfidence: 0.0,
      photoResults: photoResults,
      recommendations: ['No valid photos could be analyzed. Please retake.'],
      specialistRequired: false,
      urgencyLevel: UrgencyLevel.retake,
      urgencyText: UrgencyLevel.retake.displayText,
      aggregatedProbabilities: const ClassProbabilities(
        healthy: 0.0,
        benign: 0.0,
        opmd: 0.0,
        oca: 0.0,
      ),
      analyzedAt: DateTime.now(),
      overallAssessmentTitle: assessment.title,
      overallAssessmentMessage: assessment.message,
      labelConfidence: 0.0,
      screeningOutcome: outcome,
      subtypeGuidance: guidance,
      photosCaptured: capturedCount,
      photosUsed: photosUsed,
      skippedDueToUnknown: skippedDueToUnknown,
      skippedDueToQuality: skippedDueToQuality,
    );
  }

  /// Aggregate predictions using weighted average
  List<double> _aggregatePredictions(
    List<List<double>> predictions,
    List<double> weights,
  ) {
    if (predictions.isEmpty) return [0.0, 0.0, 0.0, 0.0, 0.0];

    // Normalize weights
    final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
    final normalizedWeights = weights.map((w) => w / totalWeight).toList();

    // Weighted average
    final numClasses = predictions[0].length;
    final aggregated = List.filled(numClasses, 0.0);

    for (int i = 0; i < predictions.length; i++) {
      for (int c = 0; c < numClasses; c++) {
        aggregated[c] += predictions[i][c] * normalizedWeights[i];
      }
    }

    return aggregated;
  }

  /// Close all models
  void dispose() {
    _ensembleSessions.clear();
    _ensembleLoaded.clear();
    _ensembleErrors.clear();
    _ensembleReady = false;
    _binaryEnsembleSessions.clear();
    _binaryEnsembleLoaded.clear();
    _binaryEnsembleErrors.clear();
    _binaryEnsembleReady = false;
    debugPrint('🧹 [Service] All models disposed');
  }
}
