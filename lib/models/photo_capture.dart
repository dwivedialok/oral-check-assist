import 'dart:io'
    if (dart.library.html) 'package:oral_cavity_classifier_app/io_stub.dart'
    as io;
import 'dart:typed_data';

/// Types of photos captured during oral screening
enum PhotoType {
  frontView,
  rightCheek,
  leftCheek,
  tongue,
  palate;

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case PhotoType.frontView:
        return 'Front View';
      case PhotoType.rightCheek:
        return 'Right Cheek';
      case PhotoType.leftCheek:
        return 'Left Cheek';
      case PhotoType.tongue:
        return 'Tongue';
      case PhotoType.palate:
        return 'Palate';
    }
  }

  /// Instructions for capturing this photo type
  String get instructions {
    switch (this) {
      case PhotoType.frontView:
        return 'Open mouth wide and show upper & lower teeth. Center your face in the frame.';
      case PhotoType.rightCheek:
        return 'Pull right cheek outward gently. Get close to capture the inner tissue.';
      case PhotoType.leftCheek:
        return 'Pull left cheek outward gently. Get close to capture the inner tissue.';
      case PhotoType.tongue:
        return 'Stick tongue out and up. Show the top surface and move side to side to show edges.';
      case PhotoType.palate:
        return 'Tilt head back slightly. Open mouth wide and say "Ahhh" to lower tongue.';
    }
  }

  /// Weight factor for this photo type in risk aggregation
  /// Tongue and cheeks are more critical for detecting lesions
  double get weight {
    switch (this) {
      case PhotoType.frontView:
        return 1.0;
      case PhotoType.rightCheek:
        return 1.2;
      case PhotoType.leftCheek:
        return 1.2;
      case PhotoType.tongue:
        return 1.3; // Tongue most critical
      case PhotoType.palate:
        return 1.1;
    }
  }

  /// Index for ordering photos in the capture sequence
  int get captureOrder {
    switch (this) {
      case PhotoType.frontView:
        return 0;
      case PhotoType.rightCheek:
        return 1;
      case PhotoType.leftCheek:
        return 2;
      case PhotoType.tongue:
        return 3;
      case PhotoType.palate:
        return 4;
    }
  }

  /// Default display label for this slot.
  ///
  /// Pure 1:1 mapping to the matching [OralPhotoLabel] preset. Purely
  /// presentational; never consumed by inference or risk aggregation.
  OralPhotoLabel get defaultLabel {
    switch (this) {
      case PhotoType.frontView:
        return OralPhotoLabel.frontView;
      case PhotoType.rightCheek:
        return OralPhotoLabel.rightCheek;
      case PhotoType.leftCheek:
        return OralPhotoLabel.leftCheek;
      case PhotoType.tongue:
        return OralPhotoLabel.tongue;
      case PhotoType.palate:
        return OralPhotoLabel.palate;
    }
  }
}

/// User-selectable anatomical label shown in the review screen and PDF report.
///
/// This is purely display metadata. Inference, quality scoring, and risk
/// aggregation never read this field — they continue to key off
/// [PhotoType]. [OralPhotoLabel.custom] pairs with a free-text string on
/// [PhotoCapture.customLabelText].
enum OralPhotoLabel {
  frontView,
  rightCheek,
  leftCheek,
  tongue,
  palate,
  custom;

  /// English display name. UI should prefer the localized helper in
  /// `l10n_extensions.dart`; this fallback is used in contexts without a
  /// [BuildContext] (e.g. logging, debug toString).
  String get displayName {
    switch (this) {
      case OralPhotoLabel.frontView:
        return 'Front View';
      case OralPhotoLabel.rightCheek:
        return 'Right Cheek';
      case OralPhotoLabel.leftCheek:
        return 'Left Cheek';
      case OralPhotoLabel.tongue:
        return 'Tongue';
      case OralPhotoLabel.palate:
        return 'Palate';
      case OralPhotoLabel.custom:
        return 'Custom';
    }
  }

  static OralPhotoLabel? fromName(String? name) {
    if (name == null) return null;
    for (final v in OralPhotoLabel.values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// Maximum allowed length (post-trim) for a custom label.
const int kMaxCustomLabelLength = 40;

/// Quality metrics for a captured photo
class PhotoQualityMetrics {
  final double brightness;
  final double sharpness;
  final double contrast;
  final double overall;

  const PhotoQualityMetrics({
    required this.brightness,
    required this.sharpness,
    required this.contrast,
    required this.overall,
  });

  /// Check if the photo meets minimum quality threshold (60%)
  bool get isAcceptable => overall >= 0.6;

  /// Get feedback message based on quality metrics
  String? get feedbackMessage {
    if (isAcceptable) return null;

    final issues = <String>[];
    if (brightness < 0.6) {
      issues.add('Move closer to light source');
    }
    if (sharpness < 0.6) {
      issues.add('Hold phone steady');
    }
    if (contrast < 0.6) {
      issues.add('Ensure good lighting');
    }

    return issues.isNotEmpty ? issues.join('. ') : 'Please retake photo';
  }

  Map<String, dynamic> toJson() => {
    'brightness': brightness,
    'sharpness': sharpness,
    'contrast': contrast,
    'overall': overall,
  };

  factory PhotoQualityMetrics.fromJson(Map<String, dynamic> json) {
    return PhotoQualityMetrics(
      brightness: (json['brightness'] as num).toDouble(),
      sharpness: (json['sharpness'] as num).toDouble(),
      contrast: (json['contrast'] as num).toDouble(),
      overall: (json['overall'] as num).toDouble(),
    );
  }

  /// Default metrics for when quality assessment hasn't been performed
  static const PhotoQualityMetrics empty = PhotoQualityMetrics(
    brightness: 0.0,
    sharpness: 0.0,
    contrast: 0.0,
    overall: 0.0,
  );
}

/// Represents a captured photo during the screening session
class PhotoCapture {
  final PhotoType type;
  final io.File? image;
  final PhotoQualityMetrics qualityMetrics;
  final DateTime? capturedAt;

  /// On web, image bytes for inference (File is stub and cannot be read).
  final Uint8List? imageBytes;

  /// Optional user-selected display label. Null means "use slot default".
  /// Purely presentational; not read by inference or risk aggregation.
  final OralPhotoLabel? photoLabel;

  /// Free-text label paired with [OralPhotoLabel.custom]. Trimmed and
  /// bounded to [kMaxCustomLabelLength]. Ignored when [photoLabel] is not
  /// [OralPhotoLabel.custom].
  final String? customLabelText;

  const PhotoCapture({
    required this.type,
    this.image,
    this.qualityMetrics = PhotoQualityMetrics.empty,
    this.capturedAt,
    this.imageBytes,
    this.photoLabel,
    this.customLabelText,
  });

  /// Whether this photo has been captured
  bool get isCaptured => image != null || imageBytes != null;

  /// Whether this photo is acceptable quality
  bool get isAcceptable => isCaptured && qualityMetrics.isAcceptable;

  /// The label to display for this photo, resolving null → slot default.
  OralPhotoLabel get effectiveLabel => photoLabel ?? type.defaultLabel;

  /// Whether this photo carries a non-default user-selected label.
  bool get hasCustomLabelSelection => photoLabel != null;

  /// English-only display string. UI should prefer the localized helper
  /// in `l10n_extensions.dart`. Returns the trimmed custom text when the
  /// label is [OralPhotoLabel.custom] and the text is non-empty.
  String get effectiveLabelDisplay {
    final label = effectiveLabel;
    if (label == OralPhotoLabel.custom) {
      final text = customLabelText?.trim();
      if (text != null && text.isNotEmpty) return text;
      return type.displayName;
    }
    return label.displayName;
  }

  /// Create a copy with updated values.
  ///
  /// [photoLabel] and [customLabelText] use sentinel-style clears: pass
  /// `clearPhotoLabel: true` or `clearCustomLabelText: true` to explicitly
  /// reset those fields to null (since null values in optional params are
  /// indistinguishable from "not provided").
  PhotoCapture copyWith({
    PhotoType? type,
    io.File? image,
    PhotoQualityMetrics? qualityMetrics,
    DateTime? capturedAt,
    Uint8List? imageBytes,
    OralPhotoLabel? photoLabel,
    String? customLabelText,
    bool clearPhotoLabel = false,
    bool clearCustomLabelText = false,
  }) {
    return PhotoCapture(
      type: type ?? this.type,
      image: image ?? this.image,
      qualityMetrics: qualityMetrics ?? this.qualityMetrics,
      capturedAt: capturedAt ?? this.capturedAt,
      imageBytes: imageBytes ?? this.imageBytes,
      photoLabel: clearPhotoLabel ? null : (photoLabel ?? this.photoLabel),
      customLabelText: clearCustomLabelText
          ? null
          : (customLabelText ?? this.customLabelText),
    );
  }

  /// Clear the captured image (for retake).
  ///
  /// Preserves [photoLabel] and [customLabelText] so that if the user
  /// previously relabeled this slot, the selection survives a retake (AC5).
  PhotoCapture clear() {
    return PhotoCapture(
      type: type,
      image: null,
      qualityMetrics: PhotoQualityMetrics.empty,
      capturedAt: null,
      imageBytes: null,
      photoLabel: photoLabel,
      customLabelText: customLabelText,
    );
  }

  @override
  String toString() {
    return 'PhotoCapture(type: ${type.displayName}, label: $effectiveLabelDisplay, captured: $isCaptured, quality: ${(qualityMetrics.overall * 100).toStringAsFixed(1)}%)';
  }
}
