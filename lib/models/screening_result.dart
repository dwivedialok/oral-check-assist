import 'exposure_data.dart';
import 'photo_capture.dart';

/// Risk level determined from screening analysis.
/// Kept for ERI integration, UI colours, and history card display.
enum RiskLevel {
  low,
  moderate,
  high;

  String get displayName {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.moderate:
        return 'Moderate Risk';
      case RiskLevel.high:
        return 'High Risk';
    }
  }

  int get colorValue {
    switch (this) {
      case RiskLevel.low:
        return 0xFF4CAF50;
      case RiskLevel.moderate:
        return 0xFFFF9800;
      case RiskLevel.high:
        return 0xFFF44336;
    }
  }

  bool get specialistRequired => this != RiskLevel.low;
}

enum UrgencyLevel { routine, prompt, urgent, retake }

/// V2 three-state screening outcome.
enum ScreeningOutcome {
  lowRisk,
  retakeSuggested,
  reviewRecommended;

  String get displayName {
    switch (this) {
      case ScreeningOutcome.lowRisk:
        return 'Low Risk';
      case ScreeningOutcome.retakeSuggested:
        return 'Retake Suggested';
      case ScreeningOutcome.reviewRecommended:
        return 'Review Recommended';
    }
  }
}

/// Multi-class subtype guidance (informational, never overrides screening).
enum SubtypeGuidance {
  none,
  ocaDominant,
  opmdDominant,
  benignDominant;

  String get displayTitle {
    switch (this) {
      case SubtypeGuidance.none:
        return '';
      case SubtypeGuidance.ocaDominant:
        return 'High Risk \u2013 Urgent Clinical Review Suggested';
      case SubtypeGuidance.opmdDominant:
        return 'Moderate to High Risk \u2013 Specialist Review Recommended';
      case SubtypeGuidance.benignDominant:
        return 'Lesion Detected \u2013 Clinical Evaluation Advised';
    }
  }

  String get displayMessage {
    switch (this) {
      case SubtypeGuidance.none:
        return '';
      case SubtypeGuidance.ocaDominant:
        return 'Patterns consistent with potentially serious changes detected. '
            'Please consult a dentist or oral specialist promptly.';
      case SubtypeGuidance.opmdDominant:
        return 'Early changes that may benefit from specialist review have been '
            'detected. Early detection significantly improves outcomes.';
      case SubtypeGuidance.benignDominant:
        return 'A lesion was detected that appears non-threatening but should '
            'be evaluated by a healthcare professional to confirm.';
    }
  }
}

extension UrgencyLevelText on UrgencyLevel {
  String get displayText {
    switch (this) {
      case UrgencyLevel.routine:
        return 'Routine (2\u20134 weeks)';
      case UrgencyLevel.prompt:
        return 'Prompt (1\u20132 weeks)';
      case UrgencyLevel.urgent:
        return 'Urgent (within 1 week)';
      case UrgencyLevel.retake:
        return 'Retake photos';
    }
  }
}

class ClassProbabilities {
  final double healthy;
  final double benign;
  final double opmd;
  final double oca;
  final double unknown;

  const ClassProbabilities({
    required this.healthy,
    required this.benign,
    required this.opmd,
    required this.oca,
    this.unknown = 0.0,
  });

  double get suspiciousProbability => opmd + oca;
  String get predictedClass {
    final maxProb = [
      healthy,
      benign,
      opmd,
      oca,
      unknown,
    ].reduce((a, b) => a > b ? a : b);
    if (maxProb == healthy) return 'Healthy';
    if (maxProb == benign) return 'Benign';
    if (maxProb == opmd) return 'OPMD';
    if (maxProb == oca) return 'OCA';
    return 'Unknown';
  }

  double get confidence =>
      [healthy, benign, opmd, oca, unknown].reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
    'healthy': healthy,
    'benign': benign,
    'opmd': opmd,
    'oca': oca,
    'unknown': unknown,
  };

  factory ClassProbabilities.fromJson(Map<String, dynamic> json) {
    return ClassProbabilities(
      healthy: (json['healthy'] as num?)?.toDouble() ?? 0.0,
      benign: (json['benign'] as num?)?.toDouble() ?? 0.0,
      opmd: (json['opmd'] as num?)?.toDouble() ?? 0.0,
      oca: (json['oca'] as num?)?.toDouble() ?? 0.0,
      unknown: (json['unknown'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory ClassProbabilities.fromList(List<double> probs) {
    if (probs.length < 4) {
      return const ClassProbabilities(
        healthy: 0.0,
        benign: 0.0,
        opmd: 0.0,
        oca: 0.0,
        unknown: 0.0,
      );
    }
    return ClassProbabilities(
      benign: probs[0],
      healthy: probs[1],
      oca: probs[2],
      opmd: probs[3],
      unknown: probs.length > 4 ? probs[4] : 0.0,
    );
  }
}

class PhotoResult {
  final PhotoType photoType;
  final ClassProbabilities? classProbabilities;
  final double confidence;
  final double qualityScore;
  final RiskLevel? riskLevel;
  final bool isValidOralPhoto;
  final String? displayLabel;
  final double? cancerProbability;
  /// Resolved per-photo summary label for UI (e.g. "Potential Concern") when binary and 5-class disagree; null otherwise.
  final String? perPhotoSummaryLabel;
  /// Short explanation when screening and visual pattern disagree; null when aligned.
  final String? disagreementNote;

  /// Optional user-selected anatomical label for this photo. Null means
  /// "use slot default". Purely display metadata — never read by inference
  /// or risk calculation.
  final OralPhotoLabel? photoLabel;

  /// Free-text label paired with [OralPhotoLabel.custom]. Display-only.
  final String? customLabelText;

  const PhotoResult({
    required this.photoType,
    this.classProbabilities,
    required this.confidence,
    required this.qualityScore,
    this.riskLevel,
    this.isValidOralPhoto = true,
    this.displayLabel,
    this.cancerProbability,
    this.perPhotoSummaryLabel,
    this.disagreementNote,
    this.photoLabel,
    this.customLabelText,
  });

  bool get isAnalyzed => classProbabilities != null;

  String get statusMessage {
    if (!isValidOralPhoto) return 'Not an oral photo';
    if (!isAnalyzed) return 'Quality issue - could not analyze';
    return riskLevel?.displayName ?? 'Analyzed';
  }

  /// Create a copy with updated values.
  ///
  /// Use [clearPhotoLabel] / [clearCustomLabelText] sentinels to explicitly
  /// reset either label field to null.
  PhotoResult copyWith({
    PhotoType? photoType,
    ClassProbabilities? classProbabilities,
    double? confidence,
    double? qualityScore,
    RiskLevel? riskLevel,
    bool? isValidOralPhoto,
    String? displayLabel,
    double? cancerProbability,
    String? perPhotoSummaryLabel,
    String? disagreementNote,
    OralPhotoLabel? photoLabel,
    String? customLabelText,
    bool clearPhotoLabel = false,
    bool clearCustomLabelText = false,
  }) {
    return PhotoResult(
      photoType: photoType ?? this.photoType,
      classProbabilities: classProbabilities ?? this.classProbabilities,
      confidence: confidence ?? this.confidence,
      qualityScore: qualityScore ?? this.qualityScore,
      riskLevel: riskLevel ?? this.riskLevel,
      isValidOralPhoto: isValidOralPhoto ?? this.isValidOralPhoto,
      displayLabel: displayLabel ?? this.displayLabel,
      cancerProbability: cancerProbability ?? this.cancerProbability,
      perPhotoSummaryLabel: perPhotoSummaryLabel ?? this.perPhotoSummaryLabel,
      disagreementNote: disagreementNote ?? this.disagreementNote,
      photoLabel: clearPhotoLabel ? null : (photoLabel ?? this.photoLabel),
      customLabelText: clearCustomLabelText
          ? null
          : (customLabelText ?? this.customLabelText),
    );
  }

  Map<String, dynamic> toJson() => {
    'photoType': photoType.name,
    'classProbabilities': classProbabilities?.toJson(),
    'confidence': confidence,
    'qualityScore': qualityScore,
    'riskLevel': riskLevel?.name,
    'isValidOralPhoto': isValidOralPhoto,
    'displayLabel': displayLabel,
    'cancerProbability': cancerProbability,
    'perPhotoSummaryLabel': perPhotoSummaryLabel,
    'disagreementNote': disagreementNote,
    if (photoLabel != null) 'photoLabel': photoLabel!.name,
    if (customLabelText != null) 'customLabelText': customLabelText,
  };

  factory PhotoResult.fromJson(Map<String, dynamic> json) {
    return PhotoResult(
      photoType: PhotoType.values.firstWhere(
        (p) => p.name == json['photoType'],
        orElse: () => PhotoType.frontView,
      ),
      classProbabilities: json['classProbabilities'] != null
          ? ClassProbabilities.fromJson(
              json['classProbabilities'] as Map<String, dynamic>,
            )
          : null,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['riskLevel'] != null
          ? RiskLevel.values.firstWhere(
              (r) => r.name == json['riskLevel'],
              orElse: () => RiskLevel.low,
            )
          : null,
      isValidOralPhoto: json['isValidOralPhoto'] as bool? ?? true,
      displayLabel: json['displayLabel'] as String?,
      cancerProbability: (json['cancerProbability'] as num?)?.toDouble(),
      perPhotoSummaryLabel: json['perPhotoSummaryLabel'] as String?,
      disagreementNote: json['disagreementNote'] as String?,
      // Legacy sessions omit these keys; null falls back to slot default in UI/PDF.
      photoLabel: OralPhotoLabel.fromName(json['photoLabel'] as String?),
      customLabelText: json['customLabelText'] as String?,
    );
  }
}

class ScreeningResult {
  final RiskLevel overallRisk;
  final double overallConfidence;
  final List<PhotoResult> photoResults;
  final List<String> recommendations;
  final bool specialistRequired;
  final UrgencyLevel urgencyLevel;
  final String urgencyText;
  final ClassProbabilities aggregatedProbabilities;
  final DateTime analyzedAt;

  final String overallAssessmentTitle;
  final String overallAssessmentMessage;
  final double labelConfidence;
  final ScreeningOutcome screeningOutcome;
  final SubtypeGuidance subtypeGuidance;
  final int photosCaptured;
  final int photosUsed;
  final int skippedDueToUnknown;
  final int skippedDueToQuality;

  /// ERI: tobacco exposure data (null when not collected).
  final ExposureData? exposureData;

  /// ERI: the combined risk after applying the ERI decision matrix.
  /// Equals [overallRisk] when ERI is absent or does not elevate.
  final RiskLevel? finalCombinedRisk;

  /// ERI: contextual message added by the combined decision matrix.
  final String? eriMessage;

  /// ERI: adjusted rescreen interval (e.g. "1 month", "2 months").
  final String? eriRescreenInterval;

  const ScreeningResult({
    required this.overallRisk,
    required this.overallConfidence,
    required this.photoResults,
    required this.recommendations,
    required this.specialistRequired,
    required this.urgencyLevel,
    required this.urgencyText,
    required this.aggregatedProbabilities,
    required this.analyzedAt,
    required this.overallAssessmentTitle,
    required this.overallAssessmentMessage,
    required this.labelConfidence,
    required this.screeningOutcome,
    required this.subtypeGuidance,
    required this.photosCaptured,
    required this.photosUsed,
    this.skippedDueToUnknown = 0,
    this.skippedDueToQuality = 0,
    this.exposureData,
    this.finalCombinedRisk,
    this.eriMessage,
    this.eriRescreenInterval,
  });

  int get analyzedPhotoCount => photoResults.where((r) => r.isAnalyzed).length;

  bool get isRetakeSuggested =>
      screeningOutcome == ScreeningOutcome.retakeSuggested;

  bool get isUnassessableSession =>
      screeningOutcome == ScreeningOutcome.retakeSuggested ||
      urgencyLevel == UrgencyLevel.retake ||
      (photoResults.isNotEmpty &&
          (photoResults.every((p) => p.riskLevel == null) ||
              photoResults.every((p) => !p.isValidOralPhoto)));

  int get concerningPhotoCount => photoResults
      .where(
        (r) =>
            r.riskLevel == RiskLevel.moderate || r.riskLevel == RiskLevel.high,
      )
      .length;

  List<PhotoResult> get photosNeedingAttention => photoResults
      .where(
        (r) =>
            r.riskLevel == RiskLevel.moderate || r.riskLevel == RiskLevel.high,
      )
      .toList();

  /// The effective risk level accounting for ERI elevation.
  RiskLevel get effectiveRisk => finalCombinedRisk ?? overallRisk;

  /// True when tobacco/exposure (ERI) raises the combined recommendation above AI-only image risk.
  bool get isFinalRiskElevatedAboveImageRisk =>
      finalCombinedRisk != null &&
      finalCombinedRisk!.index > overallRisk.index;

  ScreeningResult copyWith({
    RiskLevel? overallRisk,
    double? overallConfidence,
    List<PhotoResult>? photoResults,
    List<String>? recommendations,
    bool? specialistRequired,
    UrgencyLevel? urgencyLevel,
    String? urgencyText,
    ClassProbabilities? aggregatedProbabilities,
    DateTime? analyzedAt,
    String? overallAssessmentTitle,
    String? overallAssessmentMessage,
    double? labelConfidence,
    ScreeningOutcome? screeningOutcome,
    SubtypeGuidance? subtypeGuidance,
    int? photosCaptured,
    int? photosUsed,
    int? skippedDueToUnknown,
    int? skippedDueToQuality,
    ExposureData? exposureData,
    RiskLevel? finalCombinedRisk,
    String? eriMessage,
    String? eriRescreenInterval,
  }) {
    return ScreeningResult(
      overallRisk: overallRisk ?? this.overallRisk,
      overallConfidence: overallConfidence ?? this.overallConfidence,
      photoResults: photoResults ?? this.photoResults,
      recommendations: recommendations ?? this.recommendations,
      specialistRequired: specialistRequired ?? this.specialistRequired,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      urgencyText: urgencyText ?? this.urgencyText,
      aggregatedProbabilities:
          aggregatedProbabilities ?? this.aggregatedProbabilities,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      overallAssessmentTitle:
          overallAssessmentTitle ?? this.overallAssessmentTitle,
      overallAssessmentMessage:
          overallAssessmentMessage ?? this.overallAssessmentMessage,
      labelConfidence: labelConfidence ?? this.labelConfidence,
      screeningOutcome: screeningOutcome ?? this.screeningOutcome,
      subtypeGuidance: subtypeGuidance ?? this.subtypeGuidance,
      photosCaptured: photosCaptured ?? this.photosCaptured,
      photosUsed: photosUsed ?? this.photosUsed,
      skippedDueToUnknown: skippedDueToUnknown ?? this.skippedDueToUnknown,
      skippedDueToQuality: skippedDueToQuality ?? this.skippedDueToQuality,
      exposureData: exposureData ?? this.exposureData,
      finalCombinedRisk: finalCombinedRisk ?? this.finalCombinedRisk,
      eriMessage: eriMessage ?? this.eriMessage,
      eriRescreenInterval: eriRescreenInterval ?? this.eriRescreenInterval,
    );
  }

  Map<String, dynamic> toJson() => {
    'v': 2,
    'overallRisk': overallRisk.name,
    'overallConfidence': overallConfidence,
    'photoResults': photoResults.map((r) => r.toJson()).toList(),
    'recommendations': recommendations,
    'specialistRequired': specialistRequired,
    'urgencyLevel': urgencyLevel.name,
    'urgencyText': urgencyText,
    'aggregatedProbabilities': aggregatedProbabilities.toJson(),
    'analyzedAt': analyzedAt.toIso8601String(),
    'overallAssessmentTitle': overallAssessmentTitle,
    'overallAssessmentMessage': overallAssessmentMessage,
    'labelConfidence': labelConfidence,
    'screeningOutcome': screeningOutcome.name,
    'subtypeGuidance': subtypeGuidance.name,
    'photosCaptured': photosCaptured,
    'photosUsed': photosUsed,
    'skippedDueToUnknown': skippedDueToUnknown,
    'skippedDueToQuality': skippedDueToQuality,
    if (exposureData != null) 'exposureData': exposureData!.toJson(),
    if (finalCombinedRisk != null) 'finalCombinedRisk': finalCombinedRisk!.name,
    if (eriMessage != null) 'eriMessage': eriMessage,
    if (eriRescreenInterval != null) 'eriRescreenInterval': eriRescreenInterval,
  };

  factory ScreeningResult.fromJson(Map<String, dynamic> json) {
    if (json['v'] != 2) {
      throw FormatException('Unsupported screening result format (expected v2)');
    }

    final urgencyRaw = (json['urgencyLevel'] as String?) ?? 'routine';
    final urgency = UrgencyLevel.values.firstWhere(
      (u) => u.name == urgencyRaw,
      orElse: () => UrgencyLevel.routine,
    );
    final overallRisk = RiskLevel.values.firstWhere(
      (r) => r.name == json['overallRisk'],
      orElse: () => RiskLevel.low,
    );

    return ScreeningResult(
      overallRisk: overallRisk,
      overallConfidence: (json['overallConfidence'] as num?)?.toDouble() ?? 0.0,
      photoResults:
          (json['photoResults'] as List<dynamic>?)
              ?.map((r) => PhotoResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations:
          (json['recommendations'] as List<dynamic>?)
              ?.map((r) => r.toString())
              .toList() ??
          [],
      specialistRequired: json['specialistRequired'] as bool? ?? false,
      urgencyLevel: urgency,
      urgencyText: json['urgencyText'] as String? ?? urgency.displayText,
      aggregatedProbabilities: json['aggregatedProbabilities'] != null
          ? ClassProbabilities.fromJson(json['aggregatedProbabilities'])
          : const ClassProbabilities(
              healthy: 0.0,
              benign: 0.0,
              opmd: 0.0,
              oca: 0.0,
            ),
      analyzedAt:
          DateTime.tryParse(json['analyzedAt'] as String? ?? '') ??
          DateTime.now(),
      overallAssessmentTitle:
          json['overallAssessmentTitle'] as String? ?? 'Low Risk',
      overallAssessmentMessage:
          json['overallAssessmentMessage'] as String? ??
          'No concerning signs detected in these photos.',
      labelConfidence: (json['labelConfidence'] as num?)?.toDouble() ?? 0.0,
      screeningOutcome: ScreeningOutcome.values.firstWhere(
        (s) => s.name == json['screeningOutcome'],
      ),
      subtypeGuidance: SubtypeGuidance.values.firstWhere(
        (s) => s.name == json['subtypeGuidance'],
      ),
      photosCaptured: json['photosCaptured'] as int? ?? 0,
      photosUsed: json['photosUsed'] as int? ?? 0,
      skippedDueToUnknown: json['skippedDueToUnknown'] as int? ?? 0,
      skippedDueToQuality: json['skippedDueToQuality'] as int? ?? 0,
      exposureData: json['exposureData'] != null
          ? ExposureData.fromJson(json['exposureData'] as Map<String, dynamic>)
          : null,
      finalCombinedRisk: json['finalCombinedRisk'] != null
          ? RiskLevel.values.firstWhere(
              (r) => r.name == json['finalCombinedRisk'],
              orElse: () => overallRisk,
            )
          : overallRisk,
      eriMessage: json['eriMessage'] as String?,
      eriRescreenInterval: json['eriRescreenInterval'] as String?,
    );
  }

  static List<String> generateRecommendations(
    RiskLevel riskLevel,
    List<PhotoResult> photoResults,
  ) {
    final recommendations = <String>[];
    final retakePhotos = photoResults
        .where((r) => r.riskLevel == null && !r.isValidOralPhoto)
        .map((r) => r.photoType.displayName)
        .toList();
    if (retakePhotos.isNotEmpty) {
      recommendations.add(
        'Need clearer photos for: ${retakePhotos.join(", ")}',
      );
    }

    switch (riskLevel) {
      case RiskLevel.low:
        recommendations.addAll([
          'No concerning signs detected',
          'Continue regular oral hygiene',
          'Schedule routine dental checkup',
          'Rescreen in 3 months',
        ]);
        break;
      case RiskLevel.moderate:
        recommendations.addAll([
          'Some changes detected that need attention',
          'Schedule appointment with dentist within 2-4 weeks',
          'Avoid tobacco and alcohol',
          'Monitor any changes closely',
        ]);
        final problemPhotos = photoResults
            .where(
              (r) =>
                  r.riskLevel == RiskLevel.moderate ||
                  r.riskLevel == RiskLevel.high,
            )
            .map((r) => r.photoType.displayName)
            .toList();
        if (problemPhotos.isNotEmpty) {
          recommendations.add(
            'Pay special attention to: ${problemPhotos.join(", ")}',
          );
        }
        break;
      case RiskLevel.high:
        recommendations.addAll([
          'Concerning changes detected',
          'URGENT: See oral surgeon or oncologist within 1 week',
          'Bring this report to your appointment',
          'Early detection significantly improves outcomes',
        ]);
        break;
    }

    return recommendations;
  }
}
