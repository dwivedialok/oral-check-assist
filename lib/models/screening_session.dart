import 'exposure_data.dart';
import 'photo_capture.dart';
import 'screening_result.dart';
import '../services/screening_config.dart';

/// Status of the screening session
enum ScreeningStatus {
  notStarted,
  capturing,
  reviewing,
  analyzing,
  completed,
  failed;

  String get displayName {
    switch (this) {
      case ScreeningStatus.notStarted:
        return 'Not Started';
      case ScreeningStatus.capturing:
        return 'Capturing Photos';
      case ScreeningStatus.reviewing:
        return 'Reviewing Photos';
      case ScreeningStatus.analyzing:
        return 'Analyzing';
      case ScreeningStatus.completed:
        return 'Completed';
      case ScreeningStatus.failed:
        return 'Failed';
    }
  }
}

/// Manages the state of a complete screening session
class ScreeningSession {
  final String id;
  final DateTime startedAt;
  final List<PhotoCapture> photos;
  final ScreeningStatus status;
  final ScreeningResult? result;
  final String? errorMessage;
  final ExposureData? exposureData;

  ScreeningSession({
    required this.id,
    required this.startedAt,
    required this.photos,
    this.status = ScreeningStatus.notStarted,
    this.result,
    this.errorMessage,
    this.exposureData,
  });

  /// Create a new session with empty photos
  factory ScreeningSession.create() {
    return ScreeningSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startedAt: DateTime.now(),
      photos: [
        const PhotoCapture(type: PhotoType.frontView),
        const PhotoCapture(type: PhotoType.rightCheek),
        const PhotoCapture(type: PhotoType.leftCheek),
        const PhotoCapture(type: PhotoType.tongue),
        const PhotoCapture(type: PhotoType.palate),
      ],
      status: ScreeningStatus.notStarted,
    );
  }

  /// Total number of photos required
  int get totalPhotos => 5;

  /// Number of photos captured
  int get capturedCount => photos.where((p) => p.isCaptured).length;

  /// Number of photos with acceptable quality
  int get acceptableCount => photos.where((p) => p.isAcceptable).length;

  /// Progress as a percentage (0.0 to 1.0)
  double get captureProgress => capturedCount / totalPhotos;

  /// Whether all photos have been captured
  bool get allCaptured => capturedCount == totalPhotos;

  /// All five slots filled and every captured photo passes quality (same as 5/5 good).
  bool get allFiveSlotsFilledAndAcceptable =>
      allCaptured && photosNeedingRetake.isEmpty;

  /// Legacy name: true only when all five slots are captured and acceptable.
  bool get allAcceptable => allFiveSlotsFilledAndAcceptable;

  /// Every captured photo has acceptable quality (empty slots ignored).
  bool get allCapturedPhotosAcceptable => photosNeedingRetake.isEmpty;

  /// Front view acceptable and at least [ScreeningConfig.minUsedPhotos] acceptable photos
  /// (aligns with multi-photo aggregation).
  bool get readyToAnalyze {
    final front = getPhoto(PhotoType.frontView);
    if (front == null || !front.isAcceptable) return false;
    return acceptableCount >= ScreeningConfig.minUsedPhotos;
  }

  /// Whether a photo type is required (only Front View)
  static bool isRequiredPhoto(PhotoType type) => type == PhotoType.frontView;

  /// Get the next photo type to capture
  PhotoType? get nextPhotoType {
    for (final photo in photos) {
      if (!photo.isCaptured) {
        return photo.type;
      }
    }
    return null;
  }

  /// Get the current photo index (0-based)
  int get currentPhotoIndex {
    for (int i = 0; i < photos.length; i++) {
      if (!photos[i].isCaptured) {
        return i;
      }
    }
    return photos.length - 1;
  }

  /// Get photos that need to be retaken
  List<PhotoCapture> get photosNeedingRetake => photos.where((p) => p.isCaptured && !p.isAcceptable).toList();

  /// Front is acceptable but fewer than [ScreeningConfig.minUsedPhotos] acceptable shots overall.
  bool get needsMoreAcceptablePhotosForAnalysis {
    final front = getPhoto(PhotoType.frontView);
    if (front == null || !front.isAcceptable) return false;
    return acceptableCount < ScreeningConfig.minUsedPhotos;
  }

  /// Get a photo by type
  PhotoCapture? getPhoto(PhotoType type) {
    try {
      return photos.firstWhere((p) => p.type == type);
    } catch (e) {
      return null;
    }
  }

  /// Update a photo in the session
  ScreeningSession updatePhoto(PhotoCapture updatedPhoto) {
    final updatedPhotos = photos.map((p) {
      if (p.type == updatedPhoto.type) {
        return updatedPhoto;
      }
      return p;
    }).toList();

    return copyWith(photos: updatedPhotos);
  }

  /// Clear a photo (for retake)
  ScreeningSession clearPhoto(PhotoType type) {
    final updatedPhotos = photos.map((p) {
      if (p.type == type) {
        return p.clear();
      }
      return p;
    }).toList();

    return copyWith(photos: updatedPhotos);
  }

  /// Create a copy with updated values
  ScreeningSession copyWith({
    String? id,
    DateTime? startedAt,
    List<PhotoCapture>? photos,
    ScreeningStatus? status,
    ScreeningResult? result,
    String? errorMessage,
    ExposureData? exposureData,
  }) {
    return ScreeningSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      photos: photos ?? this.photos,
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      exposureData: exposureData ?? this.exposureData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'status': status.name,
        'capturedCount': capturedCount,
        'acceptableCount': acceptableCount,
        'result': result?.toJson(),
        'errorMessage': errorMessage,
        if (exposureData != null) 'exposureData': exposureData!.toJson(),
      };

  @override
  String toString() {
    return 'ScreeningSession(id: $id, status: ${status.displayName}, progress: $capturedCount/$totalPhotos, acceptable: $acceptableCount)';
  }
}
