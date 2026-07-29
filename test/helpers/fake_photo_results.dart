import 'package:oral_cavity_classifier_app/models/photo_capture.dart';
import 'package:oral_cavity_classifier_app/models/screening_result.dart';

/// Flexible factory for synthetic [PhotoResult] objects used in tests.
///
/// All values default to a healthy/benign Low-risk photo. Override specific
/// fields to simulate OPMD, OCA, poor quality, etc.
PhotoResult fakePhoto({
  PhotoType type = PhotoType.frontView,
  RiskLevel? riskLevel = RiskLevel.low,
  double cancerProbability = 0.10,
  double opmd = 0.01,
  double oca = 0.00,
  double benign = 0.85,
  double healthy = 0.10,
  double unknown = 0.00,
  double quality = 0.90,
  double confidence = 0.95,
  bool isValidOral = true,
}) {
  final remaining = 1.0 - (opmd + oca + benign + healthy + unknown);
  final adjustedUnknown = unknown + (remaining > 0 ? remaining : 0);

  return PhotoResult(
    photoType: type,
    classProbabilities: ClassProbabilities(
      healthy: healthy,
      benign: benign,
      opmd: opmd,
      oca: oca,
      unknown: adjustedUnknown.clamp(0.0, 1.0),
    ),
    confidence: confidence,
    qualityScore: quality,
    riskLevel: riskLevel,
    isValidOralPhoto: isValidOral,
    cancerProbability: cancerProbability,
  );
}

/// A clearly benign/healthy Low-risk photo.
PhotoResult normalPhoto(PhotoType type) => fakePhoto(
      type: type,
      riskLevel: RiskLevel.low,
      cancerProbability: 0.08,
      benign: 0.90,
      healthy: 0.06,
      opmd: 0.02,
      oca: 0.01,
      unknown: 0.01,
      confidence: 0.95,
      quality: 0.92,
    );

/// A photo where the 5-class model predicts OPMD with moderate-to-high
/// probability and binary score is above screening threshold.
PhotoResult opmdPhoto(PhotoType type) => fakePhoto(
      type: type,
      riskLevel: RiskLevel.moderate,
      cancerProbability: 0.55,
      benign: 0.15,
      healthy: 0.05,
      opmd: 0.60,
      oca: 0.10,
      unknown: 0.01,
      confidence: 0.60,
      quality: 0.88,
    );

/// A photo with strong OCA signal — unambiguously High risk.
PhotoResult ocaPhoto(PhotoType type) => fakePhoto(
      type: type,
      riskLevel: RiskLevel.high,
      cancerProbability: 0.75,
      benign: 0.05,
      healthy: 0.02,
      opmd: 0.10,
      oca: 0.70,
      unknown: 0.01,
      confidence: 0.70,
      quality: 0.90,
    );

/// A Moderate-risk photo: binary score near the screening threshold.
PhotoResult moderatePhoto(PhotoType type) => fakePhoto(
      type: type,
      riskLevel: RiskLevel.moderate,
      cancerProbability: 0.50,
      benign: 0.40,
      healthy: 0.10,
      opmd: 0.30,
      oca: 0.10,
      unknown: 0.01,
      confidence: 0.72,
      quality: 0.88,
    );

/// A photo that could not be assessed (Unknown/OOD or failed quality).
/// riskLevel is null, which means it should not influence aggregation.
PhotoResult unassessablePhoto(PhotoType type) => fakePhoto(
      type: type,
      riskLevel: null,
      cancerProbability: 0.0,
      benign: 0.0,
      healthy: 0.0,
      opmd: 0.0,
      oca: 0.0,
      unknown: 1.0,
      confidence: 0.0,
      quality: 0.3,
      isValidOral: false,
    );

/// All five [PhotoType] values in capture order.
const allPhotoTypes = [
  PhotoType.frontView,
  PhotoType.rightCheek,
  PhotoType.leftCheek,
  PhotoType.tongue,
  PhotoType.palate,
];

/// Build a standard 5-photo set: [opmdCount] OPMD photos placed on the
/// first N types, the rest normal.
List<PhotoResult> mixedPhotoSet({int opmdCount = 0, int moderateCount = 0}) {
  final results = <PhotoResult>[];
  int opmdLeft = opmdCount;
  int modLeft = moderateCount;
  for (final type in allPhotoTypes) {
    if (opmdLeft > 0) {
      results.add(opmdPhoto(type));
      opmdLeft--;
    } else if (modLeft > 0) {
      results.add(moderatePhoto(type));
      modLeft--;
    } else {
      results.add(normalPhoto(type));
    }
  }
  return results;
}
