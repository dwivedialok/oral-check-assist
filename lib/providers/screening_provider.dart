import 'dart:io'
    if (dart.library.html) 'package:oral_cavity_classifier_app/io_stub.dart'
    as io;
import 'package:flutter/foundation.dart';
import '../models/exposure_data.dart';
import '../models/photo_capture.dart';
import '../models/screening_result.dart';
import '../models/screening_session.dart';
import '../services/model_inference_service.dart';
import '../services/photo_quality_service.dart';

/// Provider for managing the screening session state
class ScreeningProvider extends ChangeNotifier {
  final ModelInferenceService _inferenceService = ModelInferenceService();
  final PhotoQualityService _qualityService = PhotoQualityService();

  ScreeningSession? _currentSession;
  bool _isAnalyzing = false;
  bool _isLoadingModels = false;
  String? _errorMessage;
  int _currentAnalyzingPhotoIndex = 0;

  // Getters
  ScreeningSession? get currentSession => _currentSession;
  bool get isAnalyzing => _isAnalyzing;

  /// True while 5-class models are loading on first screening (lazy load).
  bool get isLoadingModels => _isLoadingModels;
  String? get errorMessage => _errorMessage;
  int get currentAnalyzingPhotoIndex => _currentAnalyzingPhotoIndex;

  bool get hasActiveSession => _currentSession != null;
  bool get canStartCapture =>
      _currentSession != null &&
      _currentSession!.status == ScreeningStatus.notStarted;
  bool get canAnalyze =>
      _currentSession != null && _currentSession!.readyToAnalyze;
  bool get isCompleted =>
      _currentSession != null &&
      _currentSession!.status == ScreeningStatus.completed;

  /// Start a new screening session
  void startNewSession() {
    _currentSession = ScreeningSession.create();
    _errorMessage = null;
    debugPrint(
      '📋 [ScreeningProvider] New session started: ${_currentSession!.id}',
    );
    notifyListeners();
  }

  /// Update session status
  void updateStatus(ScreeningStatus status) {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(status: status);
      notifyListeners();
    }
  }

  /// Capture a photo with quality assessment.
  /// On web pass [knownQuality] and [imageBytes] so we don't re-assess from stub File and inference can use bytes.
  ///
  /// [label] and [customLabelText] are optional display-only metadata. When
  /// omitted, any previously-set label on this slot is preserved; this keeps
  /// a relabeled-then-retaken photo's label intact (AC5).
  Future<PhotoCapture> capturePhoto(
    PhotoType type,
    io.File imageFile, {
    PhotoQualityMetrics? knownQuality,
    Uint8List? imageBytes,
    OralPhotoLabel? label,
    String? customLabelText,
  }) async {
    if (_currentSession == null) {
      throw StateError('No active screening session');
    }

    final qualityMetrics =
        knownQuality ?? await _qualityService.assessQuality(imageFile);

    // Preserve any pre-existing label selection on this slot unless the
    // caller supplies a new one.
    final existing = _currentSession!.getPhoto(type);
    final resolvedLabel = label ?? existing?.photoLabel;
    final resolvedCustomText = label != null
        ? customLabelText
        : existing?.customLabelText;

    final capture = PhotoCapture(
      type: type,
      image: imageFile,
      qualityMetrics: qualityMetrics,
      capturedAt: DateTime.now(),
      imageBytes: imageBytes,
      photoLabel: resolvedLabel,
      customLabelText: resolvedCustomText,
    );

    _currentSession = _currentSession!.updatePhoto(capture);

    debugPrint(
      '📸 [ScreeningProvider] Captured ${type.displayName}: quality=${(qualityMetrics.overall * 100).toStringAsFixed(1)}%, acceptable=${qualityMetrics.isAcceptable}',
    );

    notifyListeners();
    return capture;
  }

  /// Update the display-only label on an existing slot.
  ///
  /// Does not affect inference or risk state; only the label metadata on
  /// the matching [PhotoCapture] changes. Pass [label] = null to revert to
  /// the slot default.
  void setPhotoLabel(
    PhotoType type, {
    required OralPhotoLabel? label,
    String? customLabelText,
  }) {
    if (_currentSession == null) return;
    final existing = _currentSession!.getPhoto(type);
    if (existing == null) return;

    final trimmedCustom = customLabelText?.trim();
    final updated = existing.copyWith(
      photoLabel: label,
      customLabelText: (label == OralPhotoLabel.custom)
          ? (trimmedCustom != null && trimmedCustom.isNotEmpty
                ? trimmedCustom
                : existing.customLabelText)
          : null,
      clearPhotoLabel: label == null,
      clearCustomLabelText: label != OralPhotoLabel.custom,
    );
    _currentSession = _currentSession!.updatePhoto(updated);
    debugPrint(
      '🏷️ [ScreeningProvider] Label for ${type.name} set to '
      '${label?.name ?? 'default'}'
      '${label == OralPhotoLabel.custom ? ' ("${updated.customLabelText}")' : ''}',
    );
    notifyListeners();
  }

  /// Retake a specific photo
  void retakePhoto(PhotoType type) {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.clearPhoto(type);
    debugPrint('🔄 [ScreeningProvider] Cleared ${type.displayName} for retake');
    notifyListeners();
  }

  /// Assess quality of a potential capture (for real-time feedback)
  Future<PhotoQualityMetrics> assessQuality(io.File imageFile) async {
    return await _qualityService.assessQuality(imageFile);
  }

  /// Assess quality from image bytes (use on web where File.readAsBytes is not available)
  Future<PhotoQualityMetrics> assessQualityFromBytes(List<int> bytes) async {
    return await _qualityService.assessQualityFromBytes(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    );
  }

  /// Get quality feedback for display
  Map<String, String> getQualityFeedback(PhotoQualityMetrics metrics) {
    return _qualityService.getFeedback(metrics);
  }

  /// Check if ready to capture
  bool isReadyToCapture(PhotoQualityMetrics metrics) {
    return _qualityService.isReadyToCapture(metrics);
  }

  /// Analyze all photos and get results
  Future<ScreeningResult?> analyzePhotos() async {
    if (_currentSession == null) {
      _errorMessage = 'No active screening session';
      return null;
    }

    if (!_currentSession!.readyToAnalyze) {
      _errorMessage = 'Not enough acceptable photos to analyze';
      return null;
    }

    _errorMessage = null;

    // Lazy load 5-class models on first screening so UI can show "Loading detailed models…"
    if (!_inferenceService.isFiveClassModelsLoaded) {
      _isLoadingModels = true;
      _currentSession = _currentSession!.copyWith(
        status: ScreeningStatus.analyzing,
      );
      notifyListeners();
      await _inferenceService.ensureFiveClassModelsLoaded();
      _isLoadingModels = false;
      notifyListeners();
    }

    _isAnalyzing = true;
    _currentAnalyzingPhotoIndex = 0;
    _currentSession = _currentSession!.copyWith(
      status: ScreeningStatus.analyzing,
    );
    notifyListeners();

    // Ensure UI has time to show initial progress state (especially on web where analysis might be fast)
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Get only captured photos
      final capturedPhotos = _currentSession!.photos
          .where((p) => p.isCaptured)
          .toList();

      // Run multi-photo inference with progress so UI can show P1..P5.
      // Inference is called with only the captured photos and their raw
      // image/pixels — the new display-only label fields are NOT passed in
      // and do not influence any model output.
      final rawResult = await _inferenceService.inferMultiPhoto(
        capturedPhotos,
        onPhotoProgress: updateAnalyzingProgress,
      );

      // After inference, attach each PhotoCapture's label metadata to the
      // matching PhotoResult. This is purely presentational — the risk
      // fields (probabilities, confidence, riskLevel, etc.) are left
      // untouched and aggregation has already been completed above.
      final captureByType = <PhotoType, PhotoCapture>{
        for (final p in capturedPhotos) p.type: p,
      };
      final labeledPhotoResults = rawResult.photoResults.map((pr) {
        final source = captureByType[pr.photoType];
        if (source == null || !source.hasCustomLabelSelection) return pr;
        return pr.copyWith(
          photoLabel: source.photoLabel,
          customLabelText: source.customLabelText,
        );
      }).toList();
      final result = rawResult.copyWith(photoResults: labeledPhotoResults);

      // Update session with result
      _currentSession = _currentSession!.copyWith(
        status: ScreeningStatus.completed,
        result: result,
      );

      _isAnalyzing = false;
      final statusLabel = result.urgencyLevel == UrgencyLevel.retake
          ? result.overallAssessmentTitle
          : result.overallRisk.displayName;
      debugPrint('✅ [ScreeningProvider] Analysis complete: $statusLabel');
      notifyListeners();

      return result;
    } catch (e) {
      _errorMessage = 'Analysis failed: $e';
      _isAnalyzing = false;
      _currentSession = _currentSession!.copyWith(
        status: ScreeningStatus.failed,
        errorMessage: e.toString(),
      );
      debugPrint('❌ [ScreeningProvider] Analysis failed: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update analyzing progress (for UI feedback)
  void updateAnalyzingProgress(int photoIndex) {
    _currentAnalyzingPhotoIndex = photoIndex;
    notifyListeners();
  }

  /// Store exposure data on the current session.
  void setExposureData(ExposureData data) {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(exposureData: data);
    debugPrint('📋 [ScreeningProvider] Exposure data set: $data');
    notifyListeners();
  }

  /// Fire-and-forget wrapper: kicks off [analyzePhotos] without awaiting.
  /// The caller can check [isAnalyzing] / [isCompleted] to monitor progress.
  void startAnalysisInBackground() {
    analyzePhotos();
  }

  /// Update the stored [ScreeningResult] (e.g. after applying ERI matrix).
  void updateResult(ScreeningResult result) {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(result: result);
    notifyListeners();
  }

  /// Clear the current session
  void clearSession() {
    _currentSession = null;
    _isAnalyzing = false;
    _isLoadingModels = false;
    _errorMessage = null;
    _currentAnalyzingPhotoIndex = 0;
    debugPrint('🧹 [ScreeningProvider] Session cleared');
    notifyListeners();
  }

  /// Get the next photo to capture
  PhotoType? getNextPhotoType() {
    return _currentSession?.nextPhotoType;
  }

  /// Get photos that need retaking
  List<PhotoCapture> getPhotosNeedingRetake() {
    return _currentSession?.photosNeedingRetake ?? [];
  }

  /// Check if a specific photo is captured
  bool isPhotoCaptured(PhotoType type) {
    final photo = _currentSession?.getPhoto(type);
    return photo?.isCaptured ?? false;
  }

  /// Check if a specific photo is acceptable
  bool isPhotoAcceptable(PhotoType type) {
    final photo = _currentSession?.getPhoto(type);
    return photo?.isAcceptable ?? false;
  }

  /// Get capture progress (0.0 to 1.0)
  double getCaptureProgress() {
    return _currentSession?.captureProgress ?? 0.0;
  }
}
